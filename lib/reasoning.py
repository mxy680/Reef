"""Adaptive reasoning model for tutoring feedback.

Watches student handwritten math work via page transcriptions,
decides whether to intervene, and produces coaching feedback for TTS.

Uses Gemini 3 Flash Preview on OpenRouter for vision + structured inference.
"""

import asyncio
import base64
import json
import os
import re
import time
from dataclasses import dataclass, field

from lib.database import get_pool
from lib.llm_client import LLMClient

@dataclass
class ReasoningContext:
    """Text + optional images for the reasoning model."""
    text: str
    images: list[bytes] = field(default_factory=list)


OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
CEREBRAS_BASE_URL = "https://api.cerebras.ai/v1"
REASONING_MODEL_VISION = "qwen/qwen3-vl-235b-a22b-instruct"  # OpenRouter (vision)
REASONING_MODEL_TEXT = "qwen-3-235b-a22b-instruct-2507"       # Cerebras (fast, text-only)
_model_override: str | None = None  # Set by benchmark script to avoid server restarts

# Cost per token (Qwen3 VL 235B Instruct via OpenRouter)
PROMPT_COST_PER_TOKEN = 0.20 / 1_000_000
COMPLETION_COST_PER_TOKEN = 0.88 / 1_000_000

SYSTEM_PROMPT = """\
You are a math tutor observing a student's handwritten work on an iPad in real time. You have the original problem, the answer key, and the student's evolving work.

## Silence-first foundation

Your default state is SILENT. Productive struggle — the student wrestling with a problem on their own — is where the deepest learning happens. Every time you speak, you risk interrupting a train of thought the student was about to complete. Silence is not neglect; it is respect for the student's cognitive process.

Heuristics for productive vs unproductive struggle:
- **Productive**: trying different approaches, writing then pausing, crossing out and restarting, staring at the problem (thinking), partial work that's heading in the right direction.
- **Unproductive**: repeating the same wrong step, stuck for 60+ seconds with no new writing after you already stayed silent, spiraling into deeper errors.

Even when struggle looks unproductive, prefer the lightest intervention possible.

## CRITICAL: What counts as a mistake

Only these count as mistakes worth flagging:
- **Conceptual errors**: using the wrong formula, forgetting to invert a matrix, applying the wrong operation
- **Logical/constraint errors**: ignoring a limiting factor, using the wrong quantity as a bottleneck, or forgetting a constraint from the problem statement (e.g. doubling one resource but ignoring that a different resource is the real limit)
- **Simple sign errors**: writing that negative times negative is negative (basic sign rules)
- **Simple arithmetic errors**: 3 + 5 = 9, or 2 × 4 = 6

Do NOT try to verify matrix multiplications, dot products, or multi-step computations. You will get them wrong. If a step involves multiplying matrices or vectors, assume the student's arithmetic is correct unless it violates a basic sign rule.

Do NOT ask conceptual "teaching" questions about steps the student already completed correctly. Your job is to catch mistakes, not to quiz the student.

You may use the answer key to help you spot errors in the student's work at any time. However, do NOT flag work as wrong just because it is incomplete or uses a different approach than the key — only flag it if the student wrote something that is actually incorrect.
The answer key may include [Common mistake: ...] annotations — watch for these specific errors in the student's work.

## Error type classification

When you identify an error, classify it:
- **PROCEDURAL SLIP**: careless arithmetic, sign flip, copying error. The student knows the concept but made a mechanical mistake. Use Level 1-2.
- **CONCEPTUAL MISCONCEPTION**: applying the wrong rule, misunderstanding a definition, fundamental logic error. Use Level 2-3. Try cognitive conflict: show a consequence of their reasoning that contradicts something they already know.
- **STRATEGIC ERROR**: choosing an approach that cannot lead to a solution. Only flag this if it truly prevents solving the problem — many "non-standard" approaches are valid.

## Graduated escalation levels

When you decide to speak, choose the appropriate level:

- **Level 1 (FLAG)**: Brief nudge. Draw attention to the area without naming the error. "Take another look at your second step." / "Does that sign look right?"
- **Level 2 (QUESTION)**: Socratic question targeting the specific misconception. "What happens when you multiply two negative numbers?" / "What does that inequality mean for x?"
- **Level 3 (HINT)**: Name the concept or theorem without applying it. "Think about the chain rule here." / "Remember, determinants have a sign pattern."
- **Level 4 (EXPLAIN)**: Walk through reasoning using a parallel example. Never solve the actual problem. "For a simpler case like two x squared, the derivative would be..."

**Escalation rule**: Start at Level 1 for any new error. Only escalate for the SAME issue — check the tutor history. If your last message was Level 1 about the same error and the student hasn't fixed it, try Level 2. Never jump to Level 3-4 on a first intervention.

## When to SPEAK — exactly 6 triggers

You must be silent UNLESS one of these is true:

1. **The student made an error** (see types above). Do not flag matrix computation results you haven't verified with certainty.
2. **The student corrected a mistake you previously flagged.** Check tutor history: if you pointed out an error and the student has now fixed it, you MUST give brief positive reinforcement ("Nice catch on the sign." / "There you go." / "That's right."). This is a HARD RULE — no exceptions, no deferral, no "wait until they finish." The correction IS the moment to reinforce. Do NOT stay silent because you think reinforcement would "interrupt their flow" — fixing an error is a natural pause point. Do NOT wait for a boxed answer. Do NOT skip because you think they "haven't finished the step." If the trigger 2 check passes, action MUST be "speak" with delay_ms = 0.
3. **The student asked a voice question.** (This is handled separately — you will always be told when a question was asked.)
4. **The transcription is too garbled or ambiguous to evaluate.** If the student's work contains symbols or expressions you genuinely cannot parse — not just messy handwriting, but truly unreadable fragments — ask them to rewrite that part. Keep it casual: "Hey, I'm having trouble reading that last line — could you rewrite it?" Do NOT use this for partial/incomplete work (that's just the student mid-step). Only use it when you cannot determine what the student intended to write.
5. **The student boxed or circled a final answer, or wrote a completion marker** (QED, ∎, □, "Therefore..."). Treat any of these as "I'm done." Check the full answer against the answer key. If correct, brief confirmation. If wrong or incomplete (e.g. proof is missing a required direction), use graduated escalation.
6. **Accumulated work safety net.** The student has written several steps, all containing the same error that is compounding. Higher bar: only speak if the error is clearly compounding and the student shows no sign of catching it themselves.

Everything else is silent. Correct work, partial work, pauses, copying the problem, unchanged work — all silent. When in doubt, silent.

## Delay timing (delay_ms)

When you decide to speak, set delay_ms to control delivery timing:
- **0 ms**: Immediate. Use for trigger 2 (positive reinforcement — the moment of correction is fleeting) and trigger 4 (garbled text).
- **2000–5000 ms**: Short pause. Use for clear errors (trigger 1) where the student appears to have moved on to the next step — they're unlikely to self-correct.
- **5000–10000 ms**: Medium pause. Use for errors where the student might still be mid-thought or about to self-correct. Also use for trigger 5 (boxed answer) and trigger 6 (accumulated work).
- **10000–15000 ms**: Long pause. Use for gentle observations and nudges — anything where interrupting the student's train of thought would be worse than waiting.

The message will be discarded if new strokes arrive before the delay expires. When in doubt, add time.

## Multi-part questions

When the context shows "currently working on part (X)", focus ONLY on that part:
- Only check the answer key for part (X) — the context already filters this for you.
- Do not comment on other parts' work.
- "Previous Parts" shown in context are for reference only — do not flag errors in them, but DO use their results to check whether the current part's reasoning is consistent (e.g. a constraint established in an earlier part still applies).
- When the student asks "is this right?", check only the active part.

## Verify before deciding

Before choosing silent or speak, mentally check each completed step the student has written:
- For tables, check each cell.
- For equations, check each operation.
- For logical arguments, check each claim.
- For enumerations (listed pairs, set elements, truth values, cases), verify each item individually against the problem definition or answer key. An extra or missing element in a set, a wrong pair in a relation, or a missing negation in a logic problem are all errors.
- For proofs, check that the student uses every given premise/condition. If the student dismisses or ignores a given condition (e.g. "we don't need n to be prime" when the problem states n is prime), that is a conceptual error.
- For proofs that cite a named rule (transitivity, commutativity, associativity, etc.), verify the rule actually applies as stated. If the student writes "by transitivity" but the premises don't form a chain (e.g., aRb and aRx — the shared element 'a' is on the same side), that is a misapplication of the rule, even if the conclusion happens to be true by other means.
If something doesn't match what it should be, that's an error worth flagging.

## How to speak

**Anti-repetition rule**: BEFORE speaking, read the "Recent Tutor History" section below. Your new message MUST be different from every previous [speak] entry. If you are about to say something similar to what you already said, STOP — the student's work has changed since then. Look at what is NEW or DIFFERENT in their current work and address THAT instead. Exception: trigger 2 reinforcement for a NEW correction is always allowed even if you gave reinforcement for a different correction earlier — each fix deserves its own brief acknowledgment.

**Feedback rule — process over outcome**: Praise the action, not the person. "This step" not "you." Never say "great job," "you're smart," "good work," or similar. Acknowledge what they DID: "That factoring step is solid." / "Nice catch on the sign."

For mistakes:
- Point to ONE issue at a time. If there are multiple errors, address only the most important one.
- Never give away the answer or show the solution path.

For positive reinforcement (trigger 2):
- One brief sentence. "Nice, you caught that." / "There you go." / "That's right, solid work."

## Kokoro TTS pronunciation

Your message is read aloud via Kokoro TTS. Write ONLY spoken English:
- "x squared" not "x^2", "one half" not "1/2", "the integral of" not "∫"
- "negative three" not "-3", "the square root of x" not "√x"
- No LaTeX, no symbols, no fractions as a/b.

Greek letters — spell out phonetically:
- α → "alpha", β → "beta", γ → "gamma", δ → "delta", ε → "epsilon"
- θ → "theta", λ → "lambda", μ → "mew", π → "pie", σ → "sigma"
- φ → "fie", ψ → "sigh", ω → "oh-mega", Σ → "sigma", Δ → "delta"

Functions and operators:
- sin → "sine", cos → "cosine", tan → "tangent", log → "log", ln → "natural log"
- d/dx → "the derivative of", ∂/∂x → "the partial derivative with respect to x"
- lim → "the limit", Σ → "the sum", ∏ → "the product"

Math expressions:
- x² + 3x → "x squared plus three x"
- √(x+1) → "the square root of x plus one"
- |x| → "the absolute value of x"
- x ∈ S → "x is in the set S"
- A⁻¹ → "A inverse"
- det(A) → "the determinant of A"

## Image context

You may receive images alongside the text:
- **Question figures**: diagrams, charts, or tables from the original problem.
- **Student drawing**: a rendered image of the student's strokes when they are using the diagram tool or their work couldn't be transcribed to text.

## Erased work context

You may see a "Previously Erased Work" section showing what the student wrote \
before erasing. Use this to detect:
- Student erasing correct work and replacing it with something wrong
- Student second-guessing themselves repeatedly on the same step
- Student erasing your suggested correction instead of fixing the error

Do NOT comment on erased work unprompted unless the erasure introduced or \
worsened an error. Erasing and rewriting is normal — only flag it when it \
leads to a mistake.

## Output format

Respond with a JSON object:
- **action**: "silent" or "speak"
- **level**: 1-4 (required when action is "speak" for error triggers; omit for reinforcement/garbled)
- **error_type**: "procedural", "conceptual", or "strategic" (required when flagging an error; omit otherwise)
- **delay_ms**: milliseconds to wait before delivering the message (0 for immediate)
- **message**: When silent, a brief internal note. When speaking, your coaching message.
- **internal_reasoning**: Chain-of-thought explaining your decision (always required, never shown to student). You MUST begin with this EXACT template before ANY other reasoning:

  "TRIGGER 2 GATE: Last [speak] was: '[quote it]'. Was this an ERROR FLAG or REINFORCEMENT? [answer]. If ERROR FLAG: has the student fixed that specific error? [yes/no]. VERDICT: [PASS/FAIL]."

  Rules: PASS only when last [speak] was an ERROR FLAG and the student has now fixed it. An ERROR FLAG is a message that pointed out a specific mistake in the student's work (Level 1-4). A response to a voice question (e.g. "what's the first step?", "think about...") is NOT an error flag — it's answering a question. FAIL if last [speak] was REINFORCEMENT, a voice question answer, or if the error hasn't been fixed, or if there was no previous speak.
  If verdict is PASS: Set action="speak", delay_ms=0, and write a one-sentence reinforcement. Then CONTINUE scanning the student's CURRENT work for any NEW errors (different from the one just fixed). If you find a new error, append a second sentence that flags it — for example: "Nice catch on the sign. Now check your final solutions — what values make each factor zero?" This way the student gets reinforcement AND the new error doesn't go unnoticed.
  If verdict is FAIL: continue with normal error-checking reasoning.

### Action guide
- **silent**: Nothing to say. Correct work, partial work, pauses, copying — all silent. When in doubt, silent. Message should be an internal note (not spoken).
- **speak**: Feedback to deliver to the student. Set delay_ms to control timing. Message WILL be read aloud.

CRITICAL: If your internal_reasoning concludes you should speak (e.g. "I should give reinforcement", "I must flag this error"), then action MUST be "speak", not "silent". Do not write a spoken message and then set action to "silent" — that contradicts your own reasoning.

## Style

- ONE sentence. Maximum two if truly necessary.
- Simple language — assume the student is a beginner.
- Conversational and warm, like a patient friend.
- Reference what the student actually wrote.\
"""

QUESTION_PROMPT_ADDENDUM = """\

## Student's Voice Question

The student just asked you a question out loud. You MUST respond — this is not a moment to be silent.

YOUR DEFAULT MODE IS SOCRATIC. Ask a guiding question that helps them figure it out themselves. \
Do NOT give direct answers, formulas, or procedures unless the student has already asked follow-ups and is truly stuck.

Guidelines:
- Assume the student barely knows the topic. Use simple, everyday language. No jargon.
- Respond to ONE thing at a time. If they asked a big question, address only the first piece.
- For conceptual questions ("why does this work?", "what does this mean?"): \
ask them what they already know about the concept, or give a small analogy — but still frame it as a question when possible.
- For procedural questions ("what do I do next?", "how do I solve this?", "what formula do I use?", "what do I do with X?"): \
ALWAYS respond with a guiding question, NEVER give the answer or the step directly. \
"What theorem talks about maximizing power?" NOT "Use P = V squared over four R." \
"What do you think happens to a voltage source when you want to find resistance alone?" NOT "Replace it with a short circuit." \
"What kind of connection do those two resistors have?" NOT "They are in parallel." \
Only after the student has asked 2+ follow-ups on the SAME concept and still can't get it, give a small concrete hint — \
naming the concept or theorem is OK ("Think about the chain rule"), giving the computation is NOT ("Take the derivative of the outer function and multiply by the derivative of the inner").
- For verification questions ("is this right?", "did I do this correctly?"): \
check their final answer against the answer key. If it matches, say YES — "Yes, that's correct" or similar. \
Do NOT ask them to elaborate, show more work, or verify their own reasoning. Just confirm or deny directly.
- For "give me the answer" requests ("just tell me what x is", "what's the answer?"): \
NEVER give the answer. Redirect with a question: "Let's work through it — what's the first step?" \
This is a HARD RULE — even if the student begs, do not give the final answer or any intermediate result.
- For off-topic questions (not about the current problem or math): \
gently redirect — "Let's focus on the problem. Do you have a question about it?" Do NOT answer the off-topic question.
- Always reference their current work and the specific problem they're on.
- Keep it to 1-2 sentences. This is spoken aloud — short and clear beats thorough and long.\
"""

RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "internal_reasoning": {
            "type": "string",
        },
        "action": {
            "type": "string",
            "enum": ["silent", "speak"],
        },
        "level": {
            "anyOf": [
                {"type": "integer", "enum": [1, 2, 3, 4]},
                {"type": "null"},
            ],
        },
        "error_type": {
            "anyOf": [
                {"type": "string", "enum": ["procedural", "conceptual", "strategic"]},
                {"type": "null"},
            ],
        },
        "delay_ms": {
            "type": "integer",
        },
        "message": {
            "type": "string",
        },
    },
}


def _get_part_order(q_parts: list[dict]) -> list[str]:
    """Flatten nested parts JSONB into ordered label list: ["a", "a.i", "a.ii", "b"]."""
    order: list[str] = []
    for p in q_parts:
        label = p.get("label", "")
        if label:
            order.append(label)
        # Recurse into nested subparts
        subparts = p.get("parts", [])
        if subparts:
            for sub in subparts:
                sub_label = sub.get("label", "")
                if sub_label:
                    order.append(f"{label}.{sub_label}")
    return order


def _is_later_part(label: str, active_part: str, part_order: list[str]) -> bool:
    """True if label comes after active_part in ordering."""
    try:
        return part_order.index(label) > part_order.index(active_part)
    except ValueError:
        return False


def _get_client(vision: bool = False) -> LLMClient:
    """Return an LLM client. Uses fast Cerebras for text-only, OpenRouter for vision."""
    if _model_override:
        api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key:
            raise RuntimeError("OPENROUTER_API_KEY not set")
        return LLMClient(api_key=api_key, model=_model_override, base_url=OPENROUTER_BASE_URL)

    if vision:
        api_key = os.getenv("OPENROUTER_API_KEY")
        if not api_key:
            raise RuntimeError("OPENROUTER_API_KEY not set")
        return LLMClient(api_key=api_key, model=REASONING_MODEL_VISION, base_url=OPENROUTER_BASE_URL)
    else:
        api_key = os.getenv("CEREBRAS_API_KEY")
        if not api_key:
            raise RuntimeError("CEREBRAS_API_KEY not set")
        return LLMClient(api_key=api_key, model=REASONING_MODEL_TEXT, base_url=CEREBRAS_BASE_URL)


async def build_context(session_id: str, page: int) -> ReasoningContext:
    """Assemble reasoning context from transcription, problem/answer key, and history."""
    t_ctx_start = time.perf_counter()
    pool = get_pool()
    if not pool:
        return ReasoningContext(text="")

    parts: list[str] = []
    images: list[bytes] = []

    async with pool.acquire() as conn:
        # 1. Page transcription
        t_tx = time.perf_counter()
        tx_row = await conn.fetchrow(
            """
            SELECT latex, text FROM page_transcriptions
            WHERE session_id = $1 AND page = $2
            """,
            session_id, page,
        )
        # Read active part from session info
        from api.strokes import _active_sessions
        info = _active_sessions.get(session_id, {})
        active_part = info.get("active_part")

        if tx_row and tx_row["text"]:
            work_header = "## Student's Current Work"
            if active_part:
                work_header += f"\n**The student is currently working on part ({active_part}).**"
            parts.append(f"{work_header}\n{tx_row['text']}")
        elif tx_row and not tx_row["text"]:
            # Diagram detected (Mathpix cleared text) — render strokes as image
            stroke_rows = await conn.fetch(
                """
                SELECT id, strokes, event_type
                FROM stroke_logs
                WHERE session_id = $1 AND page = $2 AND event_type IN ('draw', 'erase')
                ORDER BY received_at
                """,
                session_id, page,
            )
            visible_rows: list[dict] = []
            for row in stroke_rows:
                if row["event_type"] == "erase":
                    visible_rows = [dict(row)]
                else:
                    visible_rows.append(dict(row))

            all_strokes: list[dict] = []
            for row in visible_rows:
                strokes_data = row["strokes"]
                if isinstance(strokes_data, str):
                    strokes_data = json.loads(strokes_data)
                all_strokes.extend(strokes_data)

            if all_strokes:
                from lib.stroke_renderer import render_strokes
                png_bytes = render_strokes(all_strokes)
                images.append(png_bytes)
                parts.append("## Student's Current Work\n[See attached image of student's drawing]")

        t_after_tx = time.perf_counter()

        # 1b. Previously erased work
        from lib.mathpix_client import _erase_snapshots
        erased = _erase_snapshots.get((session_id, page))
        if erased:
            lines = []
            for i, text in enumerate(reversed(erased), 1):
                lines.append(f"{i}. {text}")
            parts.append(
                "## Previously Erased Work (most recent first)\n"
                "The student wrote and then erased the following:\n\n"
                + "\n\n".join(lines)
            )

        # 2. Original problem + answer key
        # Primary: _active_sessions (live truth from iOS connect request)
        # Fallback: session_question_cache (persisted, may be stale)
        t_problem_start = time.perf_counter()
        q_id = None

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
                part_order = _get_part_order(q_parts)
                for p in q_parts:
                    label = p.get("label", "?")
                    text = p.get("text", "")
                    if active_part and label == active_part:
                        parts.append(f"  ({label}) {text} \u2190 currently working on this part")
                    elif active_part and _is_later_part(label, active_part, part_order):
                        continue  # hide later parts
                    else:
                        parts.append(f"  ({label}) {text}")

            ak_rows = await conn.fetch(
                "SELECT part_label, answer FROM answer_keys WHERE question_id = $1",
                q_id,
            )
            if ak_rows:
                if active_part and q_parts:
                    # Scoped: show only active part's answer key
                    active_ak = [r for r in ak_rows if r["part_label"] == active_part]
                    earlier_ak = [
                        r for r in ak_rows
                        if r["part_label"] and r["part_label"] != active_part
                        and not _is_later_part(r["part_label"], active_part, part_order)
                    ]
                    if active_ak:
                        ak_text = "\n".join(
                            f"  {r['part_label']}: {r['answer']}" for r in active_ak
                        )
                        parts.append(f"## Answer Key (Part {active_part})\n{ak_text}")
                    if earlier_ak:
                        prev_text = "\n".join(
                            f"  {r['part_label']}: {r['answer']}" for r in earlier_ak
                        )
                        parts.append(f"## Previous Parts (completed \u2014 for reference only)\n{prev_text}")
                else:
                    # No active part — show all (backward compat)
                    ak_text = "\n".join(
                        f"  {r['part_label'] or 'Main'}: {r['answer']}" for r in ak_rows
                    )
                    parts.append(f"## Answer Key\n{ak_text}")

            # Question figures — decode from DB and attach as images
            fig_rows = await conn.fetch(
                "SELECT image_b64 FROM question_figures WHERE question_id = $1",
                q_id,
            )
            for fig_row in fig_rows:
                images.append(base64.b64decode(fig_row["image_b64"]))

        # 3. Last 5 reasoning interactions (session history)
        t_history_start = time.perf_counter()
        history_rows = await conn.fetch(
            """
            SELECT action, message, internal_reasoning, source, created_at
            FROM reasoning_logs
            WHERE session_id = $1 AND page = $2
            ORDER BY created_at DESC LIMIT 5
            """,
            session_id, page,
        )
        if history_rows:
            history_lines = []
            last_speak = None
            last_speak_reasoning = None
            last_speak_is_voice_answer = False
            for r in reversed(history_rows):
                tag = r["action"]
                if r.get("source") == "voice_question":
                    tag = "speak:voice_answer"
                history_lines.append(f"  [{tag}] {r['message'] or ''}")
            # Find last speak message (history_rows is DESC, so first speak is most recent)
            for r in history_rows:
                if r["action"] == "speak":
                    last_speak = r["message"]
                    last_speak_reasoning = r.get("internal_reasoning", "")
                    last_speak_is_voice_answer = r.get("source") == "voice_question"
                    break
            parts.append(f"## Recent Tutor History\n" + "\n".join(history_lines))
            if last_speak:
                reasoning_context = ""
                if last_speak_is_voice_answer:
                    reasoning_context = (
                        "\nThis was a response to a voice question — NOT an error flag. "
                        "Do NOT treat it as an error flag in the trigger 2 gate.\n"
                    )
                elif last_speak_reasoning:
                    reasoning_context = (
                        f"\nYour reasoning at the time: \"{last_speak_reasoning}\"\n"
                        f"Compare the error described above to the student's CURRENT work. "
                        f"If the student has fixed that specific error, trigger 2 applies — give reinforcement.\n"
                    )
                parts.append(
                    f"## IMPORTANT: Do Not Repeat Yourself\n"
                    f"Your last spoken message was: \"{last_speak}\"\n"
                    f"{reasoning_context}"
                    f"You MUST NOT say the same thing again. If the student fixed the issue you flagged, "
                    f"give brief reinforcement. If there is a NEW error, address THAT instead."
                )

    t_ctx_end = time.perf_counter()
    print(
        f"[latency] build_context ({session_id}, p={page}): "
        f"transcription={t_after_tx - t_tx:.3f}s, "
        f"problem+ak={t_history_start - t_problem_start:.3f}s, "
        f"history={t_ctx_end - t_history_start:.3f}s, "
        f"total={t_ctx_end - t_ctx_start:.3f}s, "
        f"images={len(images)}"
    )

    return ReasoningContext(text="\n\n".join(parts), images=images)


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
        # Read active part from session info
        from api.strokes import _active_sessions
        info = _active_sessions.get(session_id, {})
        active_part = info.get("active_part")

        if tx_row and tx_row["text"]:
            content = tx_row["text"]
            if active_part:
                content = f"**The student is currently working on part ({active_part}).**\n{content}"
            sections.append({"title": "Student's Current Work", "content": content})
        elif tx_row and not tx_row["text"]:
            sections.append({"title": "Student Drawing", "content": "[Stroke rendering attached]"})

        from lib.mathpix_client import _erase_snapshots
        erased = _erase_snapshots.get((session_id, page))
        if erased:
            lines = []
            for i, text in enumerate(reversed(erased), 1):
                lines.append(f"{i}. {text}")
            sections.append({
                "title": "Previously Erased Work (most recent first)",
                "content": "\n\n".join(lines),
            })

        # 2. Original problem + answer key
        q_id = None

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
                part_order = _get_part_order(q_parts)
                for p in q_parts:
                    label = p.get("label", "?")
                    text = p.get("text", "")
                    if active_part and label == active_part:
                        problem_lines.append(f"  ({label}) {text} \u2190 currently working on this part")
                    elif active_part and _is_later_part(label, active_part, part_order):
                        continue  # hide later parts
                    else:
                        problem_lines.append(f"  ({label}) {text}")
            sections.append({"title": f"Original Problem ({q_row['label']})", "content": "\n".join(problem_lines)})

            ak_rows = await conn.fetch(
                "SELECT part_label, answer FROM answer_keys WHERE question_id = $1",
                q_id,
            )
            if ak_rows:
                if active_part and q_parts:
                    active_ak = [r for r in ak_rows if r["part_label"] == active_part]
                    earlier_ak = [
                        r for r in ak_rows
                        if r["part_label"] and r["part_label"] != active_part
                        and not _is_later_part(r["part_label"], active_part, part_order)
                    ]
                    if active_ak:
                        ak_text = "\n".join(
                            f"  {r['part_label']}: {r['answer']}" for r in active_ak
                        )
                        sections.append({"title": f"Answer Key (Part {active_part})", "content": ak_text})
                    if earlier_ak:
                        prev_text = "\n".join(
                            f"  {r['part_label']}: {r['answer']}" for r in earlier_ak
                        )
                        sections.append({"title": "Previous Parts (completed \u2014 for reference only)", "content": prev_text})
                else:
                    ak_text = "\n".join(
                        f"  {r['part_label'] or 'Main'}: {r['answer']}" for r in ak_rows
                    )
                    sections.append({"title": "Answer Key", "content": ak_text})

            fig_count = await conn.fetchval(
                "SELECT COUNT(*) FROM question_figures WHERE question_id = $1",
                q_id,
            )
            if fig_count:
                sections.append({"title": "Question Figures", "content": f"{fig_count} image(s) attached"})

        # 3. Last 5 reasoning interactions
        history_rows = await conn.fetch(
            """
            SELECT action, message, internal_reasoning, created_at FROM reasoning_logs
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
    t_run_start = time.perf_counter()
    ctx = await build_context(session_id, page)
    t_after_ctx = time.perf_counter()
    if not ctx.text:
        return {"action": "silent", "message": "No context available"}

    has_images = bool(ctx.images)
    client = _get_client(vision=has_images)
    backend = "openrouter" if has_images else "cerebras"

    # Call LLM in a thread (blocking OpenAI SDK), fallback to OpenRouter if Cerebras fails
    t_llm_start = time.perf_counter()
    try:
        raw = await asyncio.to_thread(
            client.generate,
            prompt=ctx.text,
            images=ctx.images or None,
            response_schema=RESPONSE_SCHEMA,
            system_message=SYSTEM_PROMPT,
            temperature=0.3,
        )
    except Exception as e:
        if backend == "cerebras":
            print(f"[reasoning] Cerebras failed, falling back to OpenRouter: {e}")
            client = _get_client(vision=True)
            backend = "openrouter-fallback"
            raw = await asyncio.to_thread(
                client.generate,
                prompt=ctx.text,
                images=ctx.images or None,
                response_schema=RESPONSE_SCHEMA,
                system_message=SYSTEM_PROMPT,
                temperature=0.3,
            )
        else:
            raise
    t_llm_end = time.perf_counter()

    # Fix invalid \uXXXX escapes from some backends (e.g. Cerebras)
    raw = re.sub(r'\\u(?![0-9a-fA-F]{4})', r'\\\\u', raw)
    result = json.loads(raw)
    action = result.get("action", "silent")
    message = result.get("message", "")
    level = result.get("level")
    error_type = result.get("error_type")
    delay_ms = result.get("delay_ms", 0)
    internal_reasoning = result.get("internal_reasoning", "")

    # Normalize: delayed_speak from old models → speak with delay
    if action == "delayed_speak":
        action = "speak"
        if delay_ms == 0:
            delay_ms = 10000

    # Trigger 2 safeguard: if reasoning says PASS but model chose silent, override
    # Only when there's an actual message to deliver (empty speak = TTS failure)
    if action == "silent" and "VERDICT: PASS" in internal_reasoning and message.strip():
        action = "speak"
        delay_ms = 0

    # Extract token usage from the raw response if available
    # LLMClient.generate() returns just the text, so we estimate from lengths
    prompt_tokens = len(ctx.text.split()) + len(SYSTEM_PROMPT.split())
    completion_tokens = len(message.split())
    estimated_cost = (
        prompt_tokens * PROMPT_COST_PER_TOKEN
        + completion_tokens * COMPLETION_COST_PER_TOKEN
    )

    # Log to DB
    t_db_start = time.perf_counter()
    pool = get_pool()
    if pool:
        async with pool.acquire() as conn:
            await conn.execute(
                """
                INSERT INTO reasoning_logs
                    (session_id, page, context, action, message,
                     prompt_tokens, completion_tokens, estimated_cost,
                     level, error_type, delay_ms, internal_reasoning)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
                """,
                session_id, page, ctx.text, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
                level, error_type, delay_ms, internal_reasoning,
            )
    t_db_end = time.perf_counter()

    print(
        f"[reasoning] ({session_id}, page={page}): "
        f"action={action}, level={level}, delay={delay_ms}ms, "
        f"message={message[:80]}, "
        f"tokens={prompt_tokens}+{completion_tokens}, cost=${estimated_cost:.4f}"
    )
    print(
        f"[latency] run_reasoning ({session_id}, p={page}): "
        f"backend={backend}, "
        f"build_context={t_after_ctx - t_run_start:.3f}s, "
        f"llm={t_llm_end - t_llm_start:.1f}s, "
        f"db_log={t_db_end - t_db_start:.3f}s, "
        f"total={t_db_end - t_run_start:.1f}s"
    )

    return {
        "action": action,
        "message": message,
        "level": level,
        "error_type": error_type,
        "delay_ms": delay_ms,
        "internal_reasoning": internal_reasoning,
    }


async def run_question_reasoning(session_id: str, page: int, question: str) -> dict:
    """Run the reasoning model in response to a student's voice question.

    Returns {"action": "speak", "message": "..."}.
    """
    ctx = await build_context(session_id, page)
    context_text = ctx.text if ctx.text else "No problem context available."

    # Append the student's question
    context_text += f"\n\n## Student's Question\n\"{question}\""

    has_images = bool(ctx.images)
    client = _get_client(vision=has_images)
    backend = "openrouter" if has_images else "cerebras"

    try:
        raw = await asyncio.to_thread(
            client.generate,
            prompt=context_text,
            images=ctx.images or None,
            response_schema=RESPONSE_SCHEMA,
            system_message=SYSTEM_PROMPT + QUESTION_PROMPT_ADDENDUM,
            temperature=0.3,
        )
    except Exception as e:
        if backend == "cerebras":
            print(f"[reasoning] Cerebras failed (question), falling back to OpenRouter: {e}")
            client = _get_client(vision=True)
            raw = await asyncio.to_thread(
                client.generate,
                prompt=context_text,
                images=ctx.images or None,
                response_schema=RESPONSE_SCHEMA,
                system_message=SYSTEM_PROMPT + QUESTION_PROMPT_ADDENDUM,
                temperature=0.3,
            )
        else:
            raise

    raw = re.sub(r'\\u(?![0-9a-fA-F]{4})', r'\\\\u', raw)
    result = json.loads(raw)
    # Force action to "speak" — the student asked a question, always respond
    action = "speak"
    message = result.get("message", "")
    level = result.get("level")
    error_type = result.get("error_type")
    internal_reasoning = result.get("internal_reasoning", "")

    prompt_tokens = len(context_text.split()) + len(SYSTEM_PROMPT.split()) + len(QUESTION_PROMPT_ADDENDUM.split())
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
                     source, question_text,
                     level, error_type, delay_ms, internal_reasoning)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
                """,
                session_id, page, context_text, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
                "voice_question", question,
                level, error_type, 0, internal_reasoning,
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
    ctx = await build_context(session_id, page)
    context_text = ctx.text if ctx.text else "No problem context available."

    context_text += f"\n\n## Student's Question\n\"{question}\""

    has_images = bool(ctx.images)
    client = _get_client(vision=has_images)
    backend = "openrouter" if has_images else "cerebras"

    # Accumulate full raw response for logging
    raw_tokens: list[str] = []
    # State for JSON message extraction
    found_marker = False
    message_buffer = ""

    # Pick the stream generator; fallback to OpenRouter if Cerebras fails to connect
    stream_gen = client.agenerate_stream(
        prompt=context_text,
        images=ctx.images or None,
        response_schema=RESPONSE_SCHEMA,
        system_message=SYSTEM_PROMPT + QUESTION_PROMPT_ADDENDUM,
        temperature=0.3,
    )

    try:
        async for token in stream_gen:
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
    full_raw = re.sub(r'\\u(?![0-9a-fA-F]{4})', r'\\\\u', full_raw)
    level = None
    error_type = None
    internal_reasoning = ""
    try:
        result = json.loads(full_raw)
        message = result.get("message", "")
        level = result.get("level")
        error_type = result.get("error_type")
        internal_reasoning = result.get("internal_reasoning", "")
    except json.JSONDecodeError:
        message = full_raw
        print(f"[reasoning] Warning: could not parse streaming JSON: {full_raw[:100]}")

    action = "speak"
    prompt_tokens = len(context_text.split()) + len(SYSTEM_PROMPT.split()) + len(QUESTION_PROMPT_ADDENDUM.split())
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
                     source, question_text,
                     level, error_type, delay_ms, internal_reasoning)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
                """,
                session_id, page, context_text, action, message,
                prompt_tokens, completion_tokens, estimated_cost,
                "voice_question", question,
                level, error_type, 0, internal_reasoning,
            )

    print(
        f"[reasoning] STREAM QUESTION ({session_id}, page={page}): "
        f"q=\"{question[:60]}\", answer={message[:80]}, "
        f"tokens={prompt_tokens}+{completion_tokens}, cost=${estimated_cost:.4f}"
    )
