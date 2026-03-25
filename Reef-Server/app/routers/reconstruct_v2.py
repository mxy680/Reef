"""POST /ai/v2/reconstruct-document — Mathpix-based document processing pipeline.

Replaces the Surya + LLM extraction approach with Mathpix OCR for more
accurate math recognition and structured output.
"""

import asyncio
import base64
import json
import logging
import math
import re
import time
from dataclasses import dataclass, field

import fitz  # PyMuPDF
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models import Question, QuestionBatch
from app.services.answer_keys import generate_answer_keys
from app.services.cancellation import (
    cancel as cancel_document,
    cleanup as cancel_cleanup,
    is_cancelled,
    register as cancel_register,
)
from app.services.latex_compiler import LaTeXCompiler
from app.services.llm_client import LLMClient, LLMResult
from app.services.inference_client import call_inference_api, extract_json
from app.services.mathpix import MathpixClient, replace_urls_with_filenames
from app.services.progress import update_document_status, update_progress
from app.services.prompts import LATEX_FIX_PROMPT, PARSE_MMD_PROMPT
from app.services.question_to_latex import question_to_latex, _sanitize_text
from app.services.region_extractor import extract_question_regions
from app.services.storage import download_document_pdf, upload_document_pdf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai/v2", tags=["reconstruct-v2"])

PIPELINE_TIMEOUT_SECONDS = 540  # 9 min — leaves 60s buffer before gunicorn's 600s kill
MAX_FIX_ATTEMPTS = 3

# Regex to detect \includegraphics references
_INCLUDEGRAPHICS_RE = re.compile(r'\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}')

# Strong references for fire-and-forget tasks to prevent GC mid-execution
_background_tasks: set[asyncio.Task] = set()


# ---------------------------------------------------------------------------
# Cost tracking
# ---------------------------------------------------------------------------


@dataclass
class PipelineCosts:
    """Accumulated cost metrics for a v2 pipeline run."""
    input_tokens: int = 0
    output_tokens: int = 0
    llm_calls: int = 0
    mathpix_pages: int = 0
    pipeline_seconds: float = 0.0
    _llm_cost_dollars: float = 0.0

    MODEL_RATES: dict = field(default_factory=lambda: {
        "deepseek/deepseek-v3.2": (0.25 / 1_000_000, 0.40 / 1_000_000),
        "google/gemini-3-flash-preview": (0.50 / 1_000_000, 3.00 / 1_000_000),
        "google/gemini-3.1-pro-preview": (1.25 / 1_000_000, 10.00 / 1_000_000),
    })
    _DEFAULT_RATE: tuple = (0.25 / 1_000_000, 0.40 / 1_000_000)

    def add(self, result: LLMResult, model: str = "") -> None:
        self.input_tokens += result.input_tokens
        self.output_tokens += result.output_tokens
        self.llm_calls += 1
        in_rate, out_rate = self.MODEL_RATES.get(model, self._DEFAULT_RATE)
        self._llm_cost_dollars += (
            result.input_tokens * in_rate + result.output_tokens * out_rate
        )

    @property
    def cost_cents(self) -> int:
        return math.ceil(self._llm_cost_dollars * 100)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _strip_invalid_figures(latex: str, valid_figures: set[str]) -> str:
    """Remove \\includegraphics lines referencing files not in valid_figures."""
    lines = latex.split('\n')
    filtered = []
    for line in lines:
        m = _INCLUDEGRAPHICS_RE.search(line)
        if m and m.group(1) not in valid_figures:
            continue
        filtered.append(line)
    return '\n'.join(filtered)


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------


async def _run_pipeline(*, document_id: str, user_id: str) -> None:
    """Mathpix-based reconstruction pipeline.

    Stages:
    1. Download PDF from Supabase storage
    2. Send to Mathpix for OCR + math recognition
    3. Parse Mathpix structured output into Questions
    4. Compile LaTeX for each question
    5. Merge PDFs and upload result
    6. Generate answer keys
    """
    costs = PipelineCosts()
    pipeline_start = time.monotonic()

    try:
        await update_document_status(document_id, status="processing")
        await update_progress(document_id, "Starting Mathpix pipeline...")

        # ---------------------------------------------------------------
        # Stage 1: Download source PDF
        # ---------------------------------------------------------------
        pdf_bytes = await download_document_pdf(user_id, document_id)
        if not pdf_bytes:
            raise RuntimeError("Could not download source PDF")

        # Count pages for metadata
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        num_pages = len(doc)
        doc.close()
        costs.mathpix_pages = num_pages

        await update_progress(document_id, "PDF downloaded, sending to Mathpix...")

        # ---------------------------------------------------------------
        # Stage 2: Mathpix OCR
        # ---------------------------------------------------------------
        mathpix = MathpixClient(
            app_id=settings.mathpix_app_id,
            app_key=settings.mathpix_app_key,
        )
        mmd_text, mathpix_images, url_map = await mathpix.process_pdf(pdf_bytes)

        if is_cancelled(document_id):
            return

        # Upload Mathpix figure images to Supabase storage for later use in eval
        figure_url_map: dict[str, str] = {}
        if mathpix_images:
            from app.services.storage import upload_question_figure
            upload_tasks = [
                upload_question_figure(document_id, fname, img_bytes)
                for fname, img_bytes in mathpix_images.items()
            ]
            results = await asyncio.gather(*upload_tasks, return_exceptions=True)
            for fname, result in zip(mathpix_images.keys(), results):
                if isinstance(result, str):
                    figure_url_map[fname] = result
                else:
                    logger.warning(f"  [v2] Failed to upload figure {fname}: {result}")

        await update_progress(
            document_id,
            f"Mathpix OCR complete ({len(mmd_text)} chars, "
            f"{len(mathpix_images)} images). Parsing questions...",
        )

        # ---------------------------------------------------------------
        # Stage 3: LLM parse MMD -> Questions (Opus via inference API, fallback to OpenRouter)
        # ---------------------------------------------------------------

        # Replace CDN URLs with local filenames so the LLM sees them inline
        cleaned_mmd = replace_urls_with_filenames(mmd_text, url_map)

        schema_json = json.dumps(QuestionBatch.model_json_schema(), indent=2)
        parse_prompt = PARSE_MMD_PROMPT
        parse_prompt += (
            f"\n\n## Output JSON Schema\n"
            f"Return ONLY a valid JSON object matching this schema. No markdown, no explanation, no code fences.\n"
            f"```json\n{schema_json}\n```\n"
            f"\n\n## MMD Content\n```\n{cleaned_mmd}\n```"
        )

        parse_result = None
        if settings.reef_inference_token:
            try:
                raw_content, _ = await call_inference_api(parse_prompt)
                content = extract_json(raw_content)
                # Validate it parses before accepting
                QuestionBatch.model_validate_json(content)
                parse_result = LLMResult(content=content)
                logger.info(f"  [v2] {document_id}: question extraction via Reef inference (Opus 4.6)")
            except Exception as e:
                logger.warning(f"  [v2] {document_id}: inference API failed for question extraction ({e}), falling back to OpenRouter")

        # Fallback: OpenRouter
        if parse_result is None:
            llm_fallback = LLMClient(
                api_key=settings.openrouter_api_key,
                model="deepseek/deepseek-v3.2",
                base_url="https://openrouter.ai/api/v1",
            )
            llm_fallback._strict_json_supported = False
            parse_result = await asyncio.to_thread(
                llm_fallback.generate,
                prompt=parse_prompt,
                response_schema=QuestionBatch.model_json_schema(),
            )
            costs.add(parse_result, model=llm_fallback.model)

        # LLM client for LaTeX fix loop (use inference API if available)
        llm_client = LLMClient(
            api_key=settings.openrouter_api_key,
            model="google/gemini-3-flash-preview",
            base_url="https://openrouter.ai/api/v1",
        )

        batch = QuestionBatch.model_validate_json(parse_result.content)
        questions = batch.questions

        if not questions:
            raise RuntimeError("LLM extracted zero questions from MMD output")

        # Strip hallucinated figure filenames
        valid_figures = set(mathpix_images.keys())
        for q in questions:
            q.figures = [f for f in q.figures if f in valid_figures]
            for part in q.parts:
                part.figures = [f for f in part.figures if f in valid_figures]
                for sub in part.parts:
                    sub.figures = [f for f in sub.figures if f in valid_figures]

        logger.info(
            f"  [v2] {document_id}: parsed {len(questions)} questions "
            f"from {len(mmd_text)} chars MMD"
        )

        if is_cancelled(document_id):
            return

        await update_progress(
            document_id,
            f"Compiling {len(questions)} questions to LaTeX...",
        )

        # ---------------------------------------------------------------
        # Stage 4: Compile LaTeX for each question (parallelized)
        # ---------------------------------------------------------------
        compiler = LaTeXCompiler()

        # Encode images as base64 for the LaTeX compiler
        image_data: dict[str, str] = {}
        for fname, img_bytes in mathpix_images.items():
            image_data[fname] = base64.b64encode(img_bytes).decode()

        async def _compile_question(
            idx: int, question: Question
        ) -> tuple[str, bytes, dict | None]:
            """Compile a single question with fix-loop. Returns (label, pdf, dict)."""
            label = f"Problem {question.number}"
            latex = question_to_latex(question)
            question_dict = question.model_dump()

            # Inject figure storage URLs into question_dict for eval endpoint
            q_fig_storage = {}
            all_q_figs = set(question.figures)
            for part in question.parts:
                all_q_figs.update(part.figures)
                for sub in part.parts:
                    all_q_figs.update(sub.figures)
            for fig in all_q_figs:
                if fig in figure_url_map:
                    q_fig_storage[fig] = figure_url_map[fig]
            if q_fig_storage:
                question_dict["figure_storage_urls"] = q_fig_storage

            # Only include images actually referenced by this question
            q_figures = set(question.figures)
            for part in question.parts:
                q_figures.update(part.figures)
                for sub in part.parts:
                    q_figures.update(sub.figures)
            q_image_data = {k: v for k, v in image_data.items() if k in q_figures} or None

            logger.info(
                f"  [v2-compile] {label}: {len(latex)} chars, "
                f"images={list(q_figures) or 'none'}"
            )

            pdf_result = None
            for attempt in range(1, MAX_FIX_ATTEMPTS + 1):
                try:
                    content = f"\\textbf{{\\large {label}}}\n\n{latex}"
                    pdf_result = await asyncio.to_thread(
                        compiler.compile_latex, content, image_data=q_image_data
                    )
                    if attempt > 1:
                        logger.info(f"  [v2-compile] {label}: FIXED on attempt {attempt}")
                    break
                except Exception as e:
                    if attempt < MAX_FIX_ATTEMPTS:
                        logger.warning(
                            f"  [v2-compile] {label}: attempt {attempt} failed - {e}"
                        )
                        try:
                            fix_prompt = LATEX_FIX_PROMPT.format(
                                latex_body=latex, error_message=str(e)[:2000]
                            )
                            # Try inference API for LaTeX fix
                            fix_content = None
                            if settings.reef_inference_token:
                                try:
                                    raw, _ = await call_inference_api(fix_prompt)
                                    fix_content = raw.strip()
                                except Exception:
                                    pass
                            if fix_content is None:
                                fix_llm = await asyncio.to_thread(
                                    llm_client.generate, prompt=fix_prompt
                                )
                                costs.add(fix_llm, model=llm_client.model)
                                fix_content = fix_llm.content
                            # Strip code fences if present
                            fix_content = re.sub(r"^```(?:latex|tex)?\s*\n?", "", fix_content.strip())
                            fix_content = re.sub(r"\n?```\s*$", "", fix_content)
                            latex = _sanitize_text(fix_content)
                            # Strip hallucinated figures from fix
                            latex = _strip_invalid_figures(latex, valid_figures)
                        except Exception as e2:
                            logger.warning(
                                f"  [v2-compile] {label}: LLM fix failed - {e2}"
                            )
                            break
                    else:
                        logger.error(
                            f"  [v2-compile] {label}: FAILED after "
                            f"{MAX_FIX_ATTEMPTS} attempts - {e}"
                        )

            if pdf_result is None:
                fallback = (
                    f"\\textbf{{\\large {label}}}\n\n"
                    f"\\textit{{LaTeX compilation failed for this problem.}}"
                )
                pdf_result = await asyncio.to_thread(compiler.compile_latex, fallback)
                return label, pdf_result, None

            return label, pdf_result, question_dict

        compile_tasks = [
            _compile_question(i, q) for i, q in enumerate(questions)
        ]
        compiled = await asyncio.gather(*compile_tasks)

        if is_cancelled(document_id):
            return

        # ---------------------------------------------------------------
        # Stage 5: Merge PDFs, extract regions, and upload
        # ---------------------------------------------------------------
        await update_progress(document_id, "Merging and uploading PDF...")

        merged = fitz.open()
        question_pages: list[list[int]] = []
        question_regions: list[dict | None] = []
        running_page = 0
        for label, problem_pdf_bytes, q_dict in compiled:
            sub_doc = fitz.open(stream=problem_pdf_bytes, filetype="pdf")
            question_pages.append([running_page, running_page + sub_doc.page_count - 1])
            running_page += sub_doc.page_count
            merged.insert_pdf(sub_doc)
            sub_doc.close()

            # Extract part regions from the compiled question PDF
            if q_dict is not None:
                try:
                    regions = extract_question_regions(problem_pdf_bytes, q_dict)
                    question_regions.append(regions)
                except Exception as e:
                    logger.warning(f"  [v2] Region extraction failed for {label}: {e}")
                    question_regions.append(None)
            else:
                question_regions.append(None)

        merged_bytes = merged.tobytes()
        merged.close()

        await upload_document_pdf(user_id, document_id, merged_bytes)

        costs.pipeline_seconds = time.monotonic() - pipeline_start

        # ---------------------------------------------------------------
        # Stage 6: Answer keys (fire-and-forget)
        # ---------------------------------------------------------------
        answer_questions = [
            (i + 1, q_dict)
            for i, (label, pdf_bytes, q_dict) in enumerate(compiled)
            if q_dict is not None
        ]
        if answer_questions:
            task = asyncio.create_task(
                _generate_answer_keys_safe(document_id, answer_questions, mathpix_images)
            )
            _background_tasks.add(task)
            task.add_done_callback(_background_tasks.discard)

        # Mark complete
        await update_document_status(
            document_id,
            status="completed",
            page_count=num_pages,
            problem_count=len(compiled),
            question_pages=question_pages,
            question_regions=question_regions,
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            pipeline_seconds=round(costs.pipeline_seconds, 2),
            cost_cents=costs.cost_cents,
        )

        logger.info(
            f"  [v2] {document_id} completed: {len(compiled)} problems, "
            f"{costs.llm_calls} LLM calls, "
            f"{costs.input_tokens}in/{costs.output_tokens}out tokens, "
            f"{costs.pipeline_seconds:.1f}s total, ~{costs.cost_cents}c"
        )

    except asyncio.TimeoutError:
        costs.pipeline_seconds = time.monotonic() - pipeline_start
        logger.error(f"  [v2] {document_id} timed out after {PIPELINE_TIMEOUT_SECONDS}s")
        await update_document_status(
            document_id,
            status="failed",
            error_message=f"Pipeline timed out after {PIPELINE_TIMEOUT_SECONDS}s",
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            pipeline_seconds=round(costs.pipeline_seconds, 2),
            cost_cents=costs.cost_cents,
        )
    except asyncio.CancelledError:
        logger.info(f"  [v2] {document_id} cancelled")
        await update_document_status(
            document_id,
            status="failed",
            error_message="Processing was cancelled",
        )
    except Exception as e:
        costs.pipeline_seconds = time.monotonic() - pipeline_start
        if is_cancelled(document_id):
            logger.info(f"  [v2] {document_id} cancelled (during error)")
            return
        logger.exception(f"  [v2] {document_id} failed: {e}")
        await update_document_status(
            document_id,
            status="failed",
            error_message=str(e)[:500],
            status_message=None,
            input_tokens=costs.input_tokens,
            output_tokens=costs.output_tokens,
            llm_calls=costs.llm_calls,
            pipeline_seconds=round(costs.pipeline_seconds, 2),
            cost_cents=costs.cost_cents,
        )


async def _generate_answer_keys_safe(
    document_id: str,
    questions: list[tuple[int, dict]],
    mathpix_images: dict[str, bytes] | None = None,
) -> None:
    """Wrapper that catches all exceptions so fire-and-forget never leaks."""
    try:
        await generate_answer_keys(document_id, questions, image_data=mathpix_images)
    except Exception as e:
        logger.error(f"  [v2-answer-key] Top-level failure for {document_id}: {e}")


# ---------------------------------------------------------------------------
# Background task wrapper (timeout + cancellation)
# ---------------------------------------------------------------------------


async def _process_document_background(user_id: str, document_id: str) -> None:
    """Run pipeline with timeout and cancellation support."""
    cancel_event = cancel_register(document_id)

    pipeline_task = asyncio.create_task(
        asyncio.wait_for(
            _run_pipeline(document_id=document_id, user_id=user_id),
            timeout=PIPELINE_TIMEOUT_SECONDS,
        )
    )

    async def _watchdog():
        await cancel_event.wait()
        pipeline_task.cancel()

    watchdog_task = asyncio.create_task(_watchdog())

    try:
        await pipeline_task
    finally:
        watchdog_task.cancel()
        cancel_cleanup(document_id)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


class ReconstructRequest(BaseModel):
    document_id: str


@router.post("/reconstruct-document", status_code=202)
async def reconstruct_document(
    body: ReconstructRequest,
    background_tasks: BackgroundTasks,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Kick off the Mathpix-based reconstruction pipeline as a background task."""
    document_id = body.document_id

    background_tasks.add_task(
        _process_document_background,
        user_id=user.id,
        document_id=document_id,
    )

    return JSONResponse(
        {"status": "processing", "document_id": document_id},
        status_code=202,
    )


@router.delete("/reconstruct-document/{document_id}")
async def cancel_reconstruction(
    document_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Cancel a running v2 pipeline."""
    cancel_document(document_id)
    return {"status": "cancelled", "document_id": document_id}
