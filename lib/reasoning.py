"""Adaptive reasoning model for tutoring feedback.

Watches student handwritten math work via page transcriptions,
decides whether to intervene, and produces coaching feedback for TTS.

Uses GPT-OSS 120B on Groq for fast structured inference.
"""

import asyncio
import json
import os

from lib.database import get_pool
from lib.llm_client import LLMClient

GROQ_BASE_URL = "https://api.groq.com/openai/v1"
GROQ_MODEL = "openai/gpt-oss-120b"

# Cost per token (Groq pricing for GPT-OSS 120B)
PROMPT_COST_PER_TOKEN = 0.15 / 1_000_000
COMPLETION_COST_PER_TOKEN = 0.60 / 1_000_000

SYSTEM_PROMPT = """\
You are an adaptive math tutor observing a student's handwritten work in real time.
You have access to the original problem AND the answer key — use them to check the student's work.

Your role:
- Watch the student's evolving work and compare it against the answer key.
- When you speak, provide a brief coaching hint or encouragement — never give away the full answer.
- Identify errors early and guide the student toward the correct approach.
- Encourage effort and good problem-solving strategies.
- Stay silent when the student is on track and making progress.

CRITICAL — your output will be read aloud via text-to-speech:
- Write everything as spoken words. NO mathematical notation whatsoever.
- Say "x squared" not "x^2". Say "one half" not "1/2". Say "the integral of" not "∫".
- Say "x to the fourth" not "x^4". Say "negative three" not "-3".
- Say "the square root of x" not "√x" or "sqrt(x)".
- Say "two thirds x cubed" not "(2/3)x^3".
- No LaTeX, no symbols, no fractions written as a/b — everything in plain spoken English.

Guidelines:
- Keep messages concise (1-2 sentences).
- Use natural, conversational language — like a real tutor sitting next to the student.
- Reference what the student actually wrote to show you're paying attention.
- If the student just started writing or there's very little work, stay silent.
- If the student's work is correct so far, stay silent or give brief encouragement.
- If you see a clear error or misconception, speak up with a hint (not the answer).
- Don't repeat yourself — check the conversation history to avoid redundant feedback.

Output format:
- action: "speak" if you have something useful to say, "silent" if the student is fine.
- message: Your coaching message (required even when silent — use a brief internal note).\
"""

RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "action": {
            "type": "string",
            "enum": ["speak", "silent"],
        },
        "message": {
            "type": "string",
        },
    },
}


def _get_client() -> LLMClient:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise RuntimeError("GROQ_API_KEY not set")
    return LLMClient(
        api_key=api_key,
        model=GROQ_MODEL,
        base_url=GROQ_BASE_URL,
    )


async def build_context(session_id: str, page: int) -> str:
    """Assemble reasoning context from transcription, problem/answer key, and history."""
    pool = get_pool()
    if not pool:
        return ""

    parts: list[str] = []

    async with pool.acquire() as conn:
        # 1. Page transcription
        tx_row = await conn.fetchrow(
            """
            SELECT latex, text FROM page_transcriptions
            WHERE session_id = $1 AND page = $2
            """,
            session_id, page,
        )
        if tx_row and tx_row["text"]:
            parts.append(f"## Student's Current Work\n{tx_row['text']}")

        # 2. Original problem + answer key
        # Primary: _active_sessions (live truth from iOS connect request)
        # Fallback: session_question_cache (persisted, may be stale)
        q_id = None

        from api.strokes import _active_sessions
        info = _active_sessions.get(session_id, {})
        doc_name = info.get("document_name", "")
        q_num = info.get("question_number")
        if doc_name and q_num is not None:
            doc_stem = doc_name.rsplit(".", 1)[0] if "." in doc_name else doc_name
            q_row = await conn.fetchrow(
                """
                SELECT q.id, q.number, q.label, q.text, q.parts
                FROM questions q JOIN documents d ON q.document_id = d.id
                WHERE d.filename = $1 AND q.number = $2
                """,
                doc_stem, q_num,
            )
            if q_row:
                q_id = q_row["id"]

        # Fallback to session_question_cache if active session didn't resolve
        if q_id is None:
            cache_row = await conn.fetchrow(
                "SELECT question_id FROM session_question_cache WHERE session_id = $1",
                session_id,
            )
            if cache_row:
                q_id = cache_row["question_id"]
                q_row = await conn.fetchrow(
                    "SELECT id, number, label, text, parts FROM questions WHERE id = $1",
                    q_id,
                )

        if q_id and q_row:
            parts.append(f"## Original Problem ({q_row['label']})\n{q_row['text']}")
            q_parts = q_row["parts"]
            if isinstance(q_parts, str):
                q_parts = json.loads(q_parts)
            if q_parts:
                for p in q_parts:
                    parts.append(f"  ({p.get('label', '?')}) {p.get('text', '')}")

            ak_rows = await conn.fetch(
                "SELECT part_label, answer FROM answer_keys WHERE question_id = $1",
                q_id,
            )
            if ak_rows:
                ak_text = "\n".join(
                    f"  {r['part_label'] or 'Main'}: {r['answer']}" for r in ak_rows
                )
                parts.append(f"## Answer Key\n{ak_text}")

        # 3. Last 5 reasoning interactions (session history)
        history_rows = await conn.fetch(
            """
            SELECT action, message, created_at FROM reasoning_logs
            WHERE session_id = $1 AND page = $2
            ORDER BY created_at DESC LIMIT 5
            """,
            session_id, page,
        )
        if history_rows:
            history_lines = []
            for r in reversed(history_rows):
                history_lines.append(f"  [{r['action']}] {r['message'] or ''}")
            parts.append(f"## Recent Tutor History\n" + "\n".join(history_lines))

    return "\n\n".join(parts)


async def run_reasoning(session_id: str, page: int) -> dict:
    """Run the reasoning model and log the result.

    Returns {"action": "speak"|"silent", "message": "..."}.
    """
    context = await build_context(session_id, page)
    if not context:
        return {"action": "silent", "message": "No context available"}

    client = _get_client()

    # Call LLM in a thread (blocking OpenAI SDK)
    raw = await asyncio.to_thread(
        client.generate,
        prompt=context,
        response_schema=RESPONSE_SCHEMA,
        system_message=SYSTEM_PROMPT,
        temperature=0.3,
    )

    result = json.loads(raw)
    action = result.get("action", "silent")
    message = result.get("message", "")

    # Extract token usage from the raw response if available
    # LLMClient.generate() returns just the text, so we estimate from lengths
    prompt_tokens = len(context.split()) + len(SYSTEM_PROMPT.split())
    completion_tokens = len(message.split())
    estimated_cost = (
        prompt_tokens * PROMPT_COST_PER_TOKEN
        + completion_tokens * COMPLETION_COST_PER_TOKEN
    )

    # Log to DB
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO reasoning_logs
                    (session_id, page, context, action, message,
                     prompt_tokens, completion_tokens, estimated_cost)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                """,
                session_id, page, context, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
            )

    print(
        f"[reasoning] ({session_id}, page={page}): "
        f"action={action}, message={message[:80]}, "
        f"tokens={prompt_tokens}+{completion_tokens}, cost=${estimated_cost:.4f}"
    )

    return {"action": action, "message": message}
