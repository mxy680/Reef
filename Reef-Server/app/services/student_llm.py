"""Student LLM — generates LaTeX as if a student is solving a problem."""
from __future__ import annotations

import asyncio
import json
import logging
from dataclasses import dataclass

from app.config import settings
from app.services.llm_client import LLMClient

log = logging.getLogger(__name__)

TUTOR_MODEL = "google/gemini-2.0-flash-001"


@dataclass(frozen=True)
class StudentResponse:
    latex: str
    reasoning: str


STUDENT_SYSTEM = """\
You are a {personality} college student solving a math/science/economics problem.
You write your work as LaTeX. Output ONLY a JSON object with two fields:
- "latex": the LaTeX for your next line of work (what you write on paper)
- "reasoning": one sentence explaining your thought process

Rules:
- Write ONLY the work for the current step, not the entire solution
- Use standard LaTeX: x^2, \\frac{{}}{{}}, \\sqrt{{}}, etc.
- If the tutor pointed out a mistake, correct it
- If personality is "mistake_prone": ~30% chance of making a small computational error (wrong sign, wrong coefficient, forgot a term)
- If personality is "confused": sometimes write incomplete work or skip a step
- If personality is "careful": always write correct work
"""

STUDENT_PROMPT = """\
Problem: {question_text}

You are on step {step_num} of {total_steps}.
Step description: {step_description}

{feedback_section}

Write your next line of work as LaTeX.
"""


async def generate_student_work(
    question_text: str,
    step_index: int,
    total_steps: int,
    step_description: str,
    step_expected_work: str,
    personality: str = "mistake_prone",
    tutor_feedback: str | None = None,
    previous_work: list[str] | None = None,
) -> StudentResponse:
    """Generate the student's next piece of work."""

    feedback_section = ""
    if tutor_feedback:
        feedback_section = f'The tutor just told you: "{tutor_feedback}"\nCorrect your work based on this feedback.'
    if previous_work:
        feedback_section += f"\n\nYour work so far:\n" + "\n".join(previous_work)

    system = STUDENT_SYSTEM.format(personality=personality)
    prompt = STUDENT_PROMPT.format(
        question_text=question_text,
        step_num=step_index + 1,
        total_steps=total_steps,
        step_description=step_description,
        feedback_section=feedback_section or "(This is your first attempt at this step.)",
    )

    llm = LLMClient(
        api_key=settings.openrouter_api_key,
        model=TUTOR_MODEL,
        base_url="https://openrouter.ai/api/v1",
    )

    result = await asyncio.to_thread(
        llm.generate,
        prompt=prompt,
        system_prompt=system,
        timeout=15.0,
    )

    try:
        data = json.loads(result.content)
        return StudentResponse(latex=data.get("latex", ""), reasoning=data.get("reasoning", ""))
    except (json.JSONDecodeError, KeyError):
        # Fallback: use the raw output as latex
        return StudentResponse(latex=result.content.strip(), reasoning="(parse failed)")
