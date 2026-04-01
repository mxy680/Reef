"""Validate LaTeX strings against KaTeX and fix rendering errors via LLM.

Uses the KaTeX CLI (installed via npm) to check if LaTeX renders without
errors. If validation fails, the error is sent back to the LLM for a fix.
"""

import asyncio
import json
import logging
import re
import subprocess

from app.models.answer_key import PartAnswer, QuestionAnswer, Step
from app.services.llm_client import LLMClient

logger = logging.getLogger(__name__)

# Regex to extract math content from $ or $$ delimiters
_MATH_PATTERN = re.compile(r"\$\$(.+?)\$\$|\$(.+?)\$", re.DOTALL)

KATEX_FIX_PROMPT = """\
The following LaTeX math expression failed to render in KaTeX.
Fix it so it renders correctly. Return ONLY the fixed expression — no explanation, no code fences.

## Original expression
{expression}

## KaTeX error
{error}

## Rules
- Return the complete fixed text with math delimiters ($...$ or $$...$$) intact
- Do NOT add code fences or explanations
- Keep all non-math text unchanged
- Only fix the math that caused the error
"""


def _validate_katex_expression(expr: str) -> str | None:
    """Validate a single KaTeX math expression. Returns error string or None if valid."""
    if len(expr) > 10000:
        return "Expression too long for validation"
    try:
        result = subprocess.run(
            ["katex"],
            input=expr,
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode != 0:
            return result.stderr.strip() or "Unknown KaTeX error"
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError):
        # If KaTeX CLI isn't available, skip validation
        return None


def validate_latex_text(text: str) -> list[tuple[str, str]]:
    """Validate all math expressions in a text string.

    Returns a list of (expression, error) tuples for expressions that fail.
    """
    errors = []
    for match in _MATH_PATTERN.finditer(text):
        # Group 1 = display math ($$), Group 2 = inline math ($)
        expr = match.group(1) or match.group(2)
        if not expr:
            continue
        error = _validate_katex_expression(expr.strip())
        if error:
            errors.append((expr.strip(), error))
    return errors


async def validate_and_fix_answer_key(
    answer: QuestionAnswer,
    llm_client: LLMClient,
    max_fix_attempts: int = 2,
) -> QuestionAnswer:
    """Validate all LaTeX in an answer key and fix rendering errors via LLM.

    Checks `work` and `explanation` fields in all steps across all parts.
    If any fail KaTeX validation, sends the error to the LLM for a fix.
    """
    fixed_parts = []
    any_fixed = False

    for part in answer.parts:
        fixed_steps = []
        for step in part.steps:
            fixed_work = await _validate_and_fix_field(
                step.work, llm_client, max_fix_attempts
            )
            fixed_explanation = await _validate_and_fix_field(
                step.explanation, llm_client, max_fix_attempts
            )
            fixed_reinforcement = await _validate_and_fix_field(
                step.reinforcement, llm_client, max_fix_attempts
            )

            if fixed_work != step.work or fixed_explanation != step.explanation or fixed_reinforcement != step.reinforcement:
                any_fixed = True
                fixed_steps.append(Step(
                    description=step.description,
                    explanation=fixed_explanation,
                    work=fixed_work,
                    reinforcement=fixed_reinforcement,
                ))
            else:
                fixed_steps.append(step)

        fixed_parts.append(PartAnswer(
            label=part.label,
            steps=fixed_steps,
            final_answer=part.final_answer,
            parts=part.parts,
        ))

    if any_fixed:
        logger.info(f"  [katex-fix] Fixed LaTeX in Q{answer.question_number}")
        return QuestionAnswer(
            question_number=answer.question_number,
            steps=answer.steps,
            final_answer=answer.final_answer,
            parts=fixed_parts,
        )

    return answer


async def _validate_and_fix_field(
    text: str,
    llm_client: LLMClient,
    max_attempts: int,
) -> str:
    """Validate a text field and fix KaTeX errors via LLM."""
    if not text:
        return text

    for attempt in range(max_attempts):
        errors = await asyncio.to_thread(validate_latex_text, text)
        if not errors:
            return text

        # Build fix prompt with the first error
        expr, error = errors[0]
        logger.warning(
            f"  [katex-fix] Attempt {attempt + 1}: "
            f"expression={expr[:50]}... error={error[:80]}"
        )

        prompt = KATEX_FIX_PROMPT.format(expression=text, error=error)
        try:
            result = await llm_client.generate(
                prompt=prompt,
                timeout=30.0,
            )
            fixed = result.content.strip()
            # Strip code fences if the LLM added them
            if fixed.startswith("```"):
                fixed = re.sub(r"^```\w*\n?", "", fixed)
                fixed = re.sub(r"\n?```$", "", fixed)
            text = fixed
        except Exception as e:
            logger.warning(f"  [katex-fix] Fix attempt failed: {e}")
            break

    return text
