"""Adaptive reasoning model for tutoring feedback.

Watches student handwritten math work via page transcriptions,
decides whether to intervene, and produces coaching feedback for TTS.

Uses Gemini 3 Flash Preview on OpenRouter for vision + structured inference.
"""

import asyncio
import json
import os
import re

from lib.database import get_pool
from lib.llm_client import LLMClient

OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
REASONING_MODEL = "google/gemini-3-flash-preview"

# Cost per token (Gemini 3 Flash Preview via OpenRouter)
PROMPT_COST_PER_TOKEN = 0.50 / 1_000_000
COMPLETION_COST_PER_TOKEN = 3.00 / 1_000_000

SYSTEM_PROMPT = """\
You are an adaptive math tutor silently observing a student's handwritten work on an iPad in real time. You have access to the original problem, the answer key, and the student's evolving work.

## Core principle: silence is your default

Research shows that struggling produces deeper learning than smooth performance (Kapur, 2021: productive failure yields d=0.58 for conceptual transfer). Tutoring delivered before a student reaches an impasse is essentially wasted — they lack the cognitive readiness to benefit (VanLehn, 2003). Cognitive interruptions take ~23 minutes to recover from (Mark, 2004). Your job is NOT to be helpful at every opportunity. Your job is to intervene only when it truly matters.

**You are called every time the student's writing changes. Silence should be your response the vast majority of the time.** A pause in writing almost always means the student is thinking, reading, planning their next step, or processing what they just wrote. This is GOOD. Do not interrupt it.

## When to stay SILENT (default — choose this unless a speak condition is clearly met)

- The student is making progress, even if slowly
- The student paused — they are thinking, not stuck (pauses are normal and productive)
- The student just started working or has written very little
- The student's work is correct so far
- The student made a small arithmetic slip they will likely catch themselves
- You already gave feedback recently (check history) — give them time to absorb it. If your last action was "speak", you MUST be silent now unless the student's work has meaningfully changed since then.
- The student's work is identical or nearly identical to what it was last time — they haven't acted on your feedback yet, so repeating yourself is counterproductive
- The student is between steps or between sub-parts of a problem
- The work is incomplete but headed in a reasonable direction
- You're unsure whether there's actually an error — when in doubt, stay silent

## When to SPEAK (only when a clear condition is met)

Speak ONLY when ALL of these are true:
1. There is a genuine impasse or clear conceptual error (not just a pause or minor slip)
2. The student has had enough time and written enough work to demonstrate they are actually stuck or going down a wrong path — not just thinking
3. You have not already addressed this same issue recently (check tutor history)

Specific speak triggers:
- A clear conceptual misconception (not a procedural slip) — e.g., treating force as velocity, misapplying a formula fundamentally
- The student has been repeating the same error pattern multiple times with no self-correction
- The student's approach will lead to a dead end and they've committed enough work that redirecting now saves significant wasted effort
- The student has made substantial progress but is missing a critical insight needed for the next phase
- **Positive reinforcement** (see below) — after a corrected mistake or a completed problem

## Positive reinforcement (the only two cases)

1. **After a corrected mistake**: If you previously flagged an error (check tutor history) and the student has now fixed it, acknowledge that. Keep it brief and process-focused — e.g., "Nice, you caught that." / "There you go, that sign flip was the key." Never praise intelligence, only the action they took.
2. **Problem completed correctly**: If the student's final answer matches the answer key and the problem is done, give brief acknowledgment — e.g., "That's right, solid work." / "Yep, you got it."

These are the ONLY situations that warrant positive reinforcement. Do not offer encouragement mid-problem for correct intermediate steps — silence is sufficient confirmation that they're on track.

## How to speak: graduated intervention (minimum effective dose)

When you do speak, use the LEAST directive intervention possible:

1. **Metacognitive prompt** (preferred): "What do you think should happen to both sides here?" / "Does that result make sense to you?"
2. **Conceptual nudge**: Point toward the relevant principle without applying it. "Think about what happens to the sign when you move a term across the equals sign."
3. **Specific hint** (only if lighter interventions have failed — check history): Narrow focus to the exact issue. "Look at the exponent on that second term."

NEVER:
- Give away the answer or show the full solution path
- Praise intelligence ("you're smart") — only acknowledge specific actions (see Positive reinforcement section)
- Say "that's wrong" — instead, prompt them to verify ("are you sure about that step?")
- Repeat feedback you already gave (check tutor history carefully)
- Intervene just because the work doesn't match the answer key yet — partial progress is expected

## Voice output rules

Your message will be read aloud via text-to-speech. Write ONLY spoken English:
- Say "x squared" not "x^2". Say "one half" not "1/2". Say "the integral of" not "∫".
- Say "x to the fourth" not "x^4". Say "negative three" not "-3".
- Say "the square root of x" not "√x" or "sqrt(x)".
- Say "two thirds x cubed" not "(2/3)x^3".
- No LaTeX, no symbols, no fractions written as a/b.

## Style

- ONE sentence. That's it. Absolute maximum two if truly necessary, but default to one.
- Assume the student is a beginner who barely knows the topic. Use the simplest language possible. No jargon, no technical terminology unless you explain it in the same breath.
- Focus on exactly ONE thing at a time. Never address two issues or two steps in a single message. If there are multiple problems, address only the most immediate one.
- Conversational and warm — like a patient friend who happens to know math, not a professor.
- Reference what the student actually wrote to show you're paying attention.
- Use growth-mindset framing: "not yet" over "wrong," process over person.
- Ask questions more than you make statements — push them to construct understanding.
- When guiding toward a next step, only reveal the very next micro-step, not the whole path ahead.

## Output format

- action: "silent" (vast majority of the time) or "speak" (rare, only when clearly warranted)
- message: When silent, a brief internal note on why. When speaking, your coaching message.\
"""

QUESTION_PROMPT_ADDENDUM = """\

## Student's Voice Question

The student just asked you a question out loud. You MUST respond — this is not a moment to be silent. \
Answer their question using the problem context above.

Guidelines for answering:
- Assume the student barely knows the topic. Use simple, everyday language. No jargon.
- Answer ONE thing at a time. If they asked a big question, break it down and answer only the first piece. They can ask follow-ups.
- For conceptual questions ("why does this work?", "what does this mean?"): \
give a clear, simple explanation using plain words. Relate it to something concrete if possible.
- For procedural questions ("what do I do next?", "how do I solve this?"): \
tell them only the very next small step, not the whole path. One step at a time.
- For verification questions ("is this right?", "did I do this correctly?"): \
check their work against the answer key and give a direct yes or no, then briefly explain why.
- Always reference their current work and the specific problem they're on.
- Keep it to 1-2 sentences. This is spoken aloud — short and clear beats thorough and long.\
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
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise RuntimeError("OPENROUTER_API_KEY not set")
    return LLMClient(
        api_key=api_key,
        model=REASONING_MODEL,
        base_url=OPENROUTER_BASE_URL,
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


async def build_context_structured(session_id: str, page: int) -> list[dict]:
    """Assemble reasoning context as structured sections for dashboard preview."""
    pool = get_pool()
    if not pool:
        return []

    sections: list[dict] = []

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
            sections.append({"title": "Student's Current Work", "content": tx_row["text"]})

        # 2. Original problem + answer key
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

        # Fallback to session_question_cache
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
            problem_lines = [q_row["text"]]
            q_parts = q_row["parts"]
            if isinstance(q_parts, str):
                q_parts = json.loads(q_parts)
            if q_parts:
                for p in q_parts:
                    problem_lines.append(f"  ({p.get('label', '?')}) {p.get('text', '')}")
            sections.append({"title": f"Original Problem ({q_row['label']})", "content": "\n".join(problem_lines)})

            ak_rows = await conn.fetch(
                "SELECT part_label, answer FROM answer_keys WHERE question_id = $1",
                q_id,
            )
            if ak_rows:
                ak_text = "\n".join(
                    f"  {r['part_label'] or 'Main'}: {r['answer']}" for r in ak_rows
                )
                sections.append({"title": "Answer Key", "content": ak_text})

        # 3. Last 5 reasoning interactions
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
            sections.append({"title": "Recent Tutor History", "content": "\n".join(history_lines)})

    return sections


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


async def run_question_reasoning(session_id: str, page: int, question: str) -> dict:
    """Run the reasoning model in response to a student's voice question.

    Returns {"action": "speak", "message": "..."}.
    """
    context = await build_context(session_id, page)
    if not context:
        context = "No problem context available."

    # Append the student's question
    context += f"\n\n## Student's Question\n\"{question}\""

    client = _get_client()

    raw = await asyncio.to_thread(
        client.generate,
        prompt=context,
        response_schema=RESPONSE_SCHEMA,
        system_message=SYSTEM_PROMPT + QUESTION_PROMPT_ADDENDUM,
        temperature=0.3,
    )

    result = json.loads(raw)
    # Force action to "speak" — the student asked a question, always respond
    action = "speak"
    message = result.get("message", "")

    prompt_tokens = len(context.split()) + len(SYSTEM_PROMPT.split()) + len(QUESTION_PROMPT_ADDENDUM.split())
    completion_tokens = len(message.split())
    estimated_cost = (
        prompt_tokens * PROMPT_COST_PER_TOKEN
        + completion_tokens * COMPLETION_COST_PER_TOKEN
    )

    # Log to DB with source="voice_question"
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO reasoning_logs
                    (session_id, page, context, action, message,
                     prompt_tokens, completion_tokens, estimated_cost,
                     source, question_text)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                """,
                session_id, page, context, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
                "voice_question", question,
            )

    print(
        f"[reasoning] QUESTION ({session_id}, page={page}): "
        f"q=\"{question[:60]}\", answer={message[:80]}, "
        f"tokens={prompt_tokens}+{completion_tokens}, cost=${estimated_cost:.4f}"
    )

    return {"action": action, "message": message}


def _flush_sentences(buffer: str, queue: asyncio.Queue) -> str:
    """Extract complete sentences from buffer, put them in queue.

    Returns the remaining buffer (incomplete sentence).
    Sentence boundary: [.!?] followed by whitespace with text after it.
    """
    pattern = re.compile(r'([.!?])\s+(?=\S)')
    last_end = 0
    for m in pattern.finditer(buffer):
        sentence = buffer[last_end:m.end()].strip()
        if sentence:
            queue.put_nowait(sentence)
        last_end = m.end()
    return buffer[last_end:]


async def run_question_reasoning_streaming(
    session_id: str, page: int, question: str, tts_queue: asyncio.Queue
) -> None:
    """Stream LLM response and feed sentences to tts_queue as they're detected.

    Parses streaming JSON to extract message content, detects sentence
    boundaries, and puts each complete sentence into the queue for TTS.
    Sends None sentinel when done.
    """
    context = await build_context(session_id, page)
    if not context:
        context = "No problem context available."

    context += f"\n\n## Student's Question\n\"{question}\""

    client = _get_client()

    # Accumulate full raw response for logging
    raw_tokens: list[str] = []
    # State for JSON message extraction
    found_marker = False
    message_buffer = ""

    try:
        async for token in client.agenerate_stream(
            prompt=context,
            response_schema=RESPONSE_SCHEMA,
            system_message=SYSTEM_PROMPT + QUESTION_PROMPT_ADDENDUM,
            temperature=0.3,
        ):
            raw_tokens.append(token)

            if not found_marker:
                # Look for "message": " marker in accumulated response
                accumulated = "".join(raw_tokens)
                marker = '"message": "'
                marker_alt = '"message":"'
                idx = accumulated.find(marker)
                if idx == -1:
                    idx = accumulated.find(marker_alt)
                    if idx != -1:
                        marker = marker_alt
                if idx != -1:
                    found_marker = True
                    # Everything after the marker opening quote is message content
                    after_marker = accumulated[idx + len(marker):]
                    message_buffer = after_marker
                    message_buffer = _flush_sentences(message_buffer, tts_queue)
            else:
                # We're inside the message value — accumulate and flush sentences
                message_buffer += token
                message_buffer = _flush_sentences(message_buffer, tts_queue)

        # Flush remaining buffer (strip trailing "} from JSON)
        remainder = message_buffer.rstrip()
        for suffix in ('"}', '"'):
            if remainder.endswith(suffix):
                remainder = remainder[:-len(suffix)]
                break
        remainder = remainder.strip()
        if remainder:
            tts_queue.put_nowait(remainder)

    except Exception as e:
        print(f"[reasoning] Streaming failed: {e}")
    finally:
        # Always send sentinel so TTS endpoint stops waiting
        await tts_queue.put(None)

    # Parse full response for logging
    full_raw = "".join(raw_tokens)
    try:
        result = json.loads(full_raw)
        message = result.get("message", "")
    except json.JSONDecodeError:
        message = full_raw
        print(f"[reasoning] Warning: could not parse streaming JSON: {full_raw[:100]}")

    action = "speak"
    prompt_tokens = len(context.split()) + len(SYSTEM_PROMPT.split()) + len(QUESTION_PROMPT_ADDENDUM.split())
    completion_tokens = len(message.split())
    estimated_cost = (
        prompt_tokens * PROMPT_COST_PER_TOKEN
        + completion_tokens * COMPLETION_COST_PER_TOKEN
    )

    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO reasoning_logs
                    (session_id, page, context, action, message,
                     prompt_tokens, completion_tokens, estimated_cost,
                     source, question_text)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                """,
                session_id, page, context, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
                "voice_question", question,
            )

    print(
        f"[reasoning] STREAM QUESTION ({session_id}, page={page}): "
        f"q=\"{question[:60]}\", answer={message[:80]}, "
        f"tokens={prompt_tokens}+{completion_tokens}, cost=${estimated_cost:.4f}"
    )
