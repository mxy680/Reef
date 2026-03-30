"""POST /ai/generate-question — generate a practice problem PDF for any subject."""

import asyncio
import logging
import uuid

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models.answer_key import QuestionAnswer, PartAnswer
from app.models.demo import DemoProblem
from app.models.generate_question import GenerateQuestionRequest, GenerateQuestionResponse
from app.models.question import Question
from app.routers.demo_problem import TUTOR_MODEL
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient
from app.services.question_to_latex import question_to_latex

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])

GENERATE_SYSTEM = """\
You are a {subject} problem generator for college students. Generate a single practice problem \
on the given topic at the specified difficulty level. The problem should have exactly {num_steps} \
clear solution steps."""

DIFFICULTY_LABELS = {
    1: ("Easy", "Simple and straightforward. First homework assignment level. Use basic numbers and clean expressions. One concept only."),
    2: ("Medium-Easy", "Slightly challenging. Standard homework level. Clean numbers but requires careful application of one technique."),
    3: ("Medium", "Moderately challenging. Midterm exam level. May combine two concepts or require multi-step reasoning."),
    4: ("Hard", "Difficult. Final exam level. Requires combining multiple concepts, messier numbers, or non-obvious approaches."),
    5: ("Very Hard", "Extremely difficult. Competition or qualifying exam level. Requires insight, clever manipulation, or deep conceptual understanding."),
}

GENERATE_PROMPT = """\
Generate a {difficulty_label} {subject} problem about: {topic}

Difficulty: {difficulty}/5 — {difficulty_description}

Requirements:
- Exactly {num_steps} solution steps. Each step is ONE clear operation.
- Use $...$ for inline math and \\[...\\] for display math in the question text
- The tutor_intro should be casual and friendly
- DO NOT generate word problems unless the topic specifically requires them
- For difficulty 1-2: use basic, clean numbers
- For difficulty 3: moderate complexity, standard techniques
- For difficulty 4-5: complex setups, may require combining multiple concepts
"""


@router.post("/generate-question", response_model=GenerateQuestionResponse)
async def generate_question(
    body: GenerateQuestionRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Generate a practice problem, compile to PDF, and store in Supabase."""
    log.info(
        f"[generate-question] Starting: subject='{body.subject}' "
        f"topic='{body.topic}' difficulty={body.difficulty} "
        f"num_steps={body.num_steps} user={user.id}"
    )
    try:
        return await _generate_question_impl(body, user)
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        log.error(
            f"[generate-question] Unhandled error: {type(e).__name__}: {e}\n"
            f"{traceback.format_exc()}"
        )
        raise HTTPException(status_code=500, detail=f"Question generation failed: {e}")


async def _generate_question_impl(
    body: GenerateQuestionRequest, user: AuthenticatedUser
) -> GenerateQuestionResponse:
    if not settings.openrouter_api_key:
        raise HTTPException(status_code=503, detail="OpenRouter not configured")
    if not settings.supabase_url or not settings.supabase_service_role_key:
        raise HTTPException(status_code=503, detail="Supabase not configured")

    # 1. Build prompt with difficulty label
    def _esc(s: str) -> str:
        return s.replace("{", "{{").replace("}", "}}")

    difficulty_label, difficulty_description = DIFFICULTY_LABELS[body.difficulty]

    system_prompt = GENERATE_SYSTEM.format(
        subject=body.subject,
        num_steps=body.num_steps,
    )

    prompt = GENERATE_PROMPT.format(
        difficulty_label=difficulty_label,
        subject=body.subject,
        topic=_esc(body.topic[:200]),
        difficulty=body.difficulty,
        difficulty_description=difficulty_description,
        num_steps=body.num_steps,
    )

    # 2. Call LLM → get DemoProblem (question_text, steps, final_answer, tutor_intro)
    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=system_prompt,
        response_schema=DemoProblem.model_json_schema(),
        timeout=30.0,
    )

    problem = DemoProblem.model_validate_json(result.content)

    log.info(
        f"[generate-question] subject='{body.subject}' topic='{body.topic}' "
        f"steps={len(problem.steps)} "
        f"({result.input_tokens}in/{result.output_tokens}out)"
    )

    # 3. Convert to Question model
    question = Question(number=1, text=problem.question_text, answer_space_cm=5.0)

    # 4. Convert to LaTeX and compile to PDF
    latex_body = question_to_latex(question)

    try:
        compiler = LaTeXCompiler()
        pdf_bytes = await asyncio.to_thread(compiler.compile_latex, latex_body)
    except RuntimeError as e:
        log.error(f"[generate-question] LaTeX compilation failed: {e}")
        raise HTTPException(status_code=500, detail="PDF compilation failed")

    # 5. Upload PDF to Supabase and insert document row
    doc_id = str(uuid.uuid4())
    safe_topic = body.topic[:30].replace("/", "-").replace("\\", "-")
    filename = f"{body.subject}-{safe_topic}.pdf"
    doc_row = {
        "id": doc_id,
        "user_id": user.id,
        "filename": filename,
        "status": "completed",
        "page_count": 1,
        "problem_count": 1,
        "question_pages": [[0, 0]],
    }

    headers = {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=15) as client:
        # Insert document row
        resp = await client.post(
            f"{settings.supabase_url}/rest/v1/documents",
            headers=headers,
            json=doc_row,
        )
        if resp.status_code not in (200, 201):
            log.error(
                f"[generate-question] Failed to insert document: "
                f"{resp.status_code} {resp.text[:200]}"
            )
            if "foreign key" in resp.text.lower() or "23503" in resp.text:
                raise HTTPException(
                    status_code=401,
                    detail="User account not found. Please sign out and sign back in.",
                )
            raise HTTPException(status_code=500, detail="Failed to create document record")

        # Upload PDF to storage
        storage_headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
            "Content-Type": "application/pdf",
        }
        storage_path = f"{user.id}/{doc_id}/original.pdf"
        resp = await client.post(
            f"{settings.supabase_url}/storage/v1/object/documents/{storage_path}",
            headers=storage_headers,
            content=pdf_bytes,
        )
        if resp.status_code not in (200, 201):
            log.error(
                f"[generate-question] Failed to upload PDF: "
                f"{resp.status_code} {resp.text[:200]}"
            )
            raise HTTPException(status_code=500, detail="Failed to upload PDF")

        # 6. Insert answer key row
        answer_key = QuestionAnswer(
            question_number=1,
            parts=[PartAnswer(
                label="a",
                steps=problem.steps,
                final_answer=problem.final_answer,
            )],
        )
        answer_key_row = {
            "document_id": doc_id,
            "question_number": 1,
            "answer_text": answer_key.model_dump_json(),
            "question_json": question.model_dump(),
            "model": TUTOR_MODEL,
            "input_tokens": result.input_tokens,
            "output_tokens": result.output_tokens,
        }
        resp = await client.post(
            f"{settings.supabase_url}/rest/v1/answer_keys",
            headers=headers,
            json=answer_key_row,
        )
        if resp.status_code not in (200, 201):
            log.error(
                f"[generate-question] Failed to insert answer key: "
                f"{resp.status_code} {resp.text[:200]}"
            )
            raise HTTPException(status_code=500, detail="Failed to create answer key record")

    log.info(
        f"[generate-question] Success: doc_id={doc_id} "
        f"subject='{body.subject}' topic='{body.topic}'"
    )
    return GenerateQuestionResponse(
        document_id=doc_id,
        filename=filename,
        page_count=1,
        problem_count=1,
    )
