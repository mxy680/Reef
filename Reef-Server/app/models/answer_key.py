"""Pydantic models for structured step-by-step answer key generation.

Each answer is broken into discrete Steps that serve both the student
(description) and the AI tutor (explanation + work).  The LLM produces
a QuestionAnswer object via structured output, stored as JSON in the
answer_keys table.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class Step(BaseModel):
    """A single step in a solution walkthrough."""

    description: str = Field(
        ...,
        description="Clear sentence describing what this step does and why (10-20 words), e.g. 'Apply Newton's second law to relate the net force to acceleration'",
    )
    explanation: str = Field(
        ...,
        description="Short, punchy hint for a stuck student — one sentence max, e.g. 'What does F=ma solve for here?'",
    )
    worked_example: str = Field(
        default="",
        description="A fully worked-out solution to a SIMILAR but DIFFERENT problem using the same technique. Change numbers/variables so the student can't copy directly. Use LaTeX ($...$ inline, \\[...\\] display). End with a bridge sentence.",
    )
    work: str = Field(
        ...,
        description="Just the math or key reasoning — no narration (LaTeX with $...$ inline, \\[...\\] display, or plain text)",
    )
    reinforcement: str = Field(
        default="",
        description="Short celebratory message when the student completes this step (1 sentence, warm and specific)",
    )
    tutor_speech: str = Field(
        default="",
        description="Spoken instruction for this step — a full natural sentence the tutor says OUT LOUD to guide the student. NO math notation, NO LaTeX, say formulas in plain English. Vary the phrasing: 'Your first step is...', 'Next up,...', 'Now try...', 'For the last step,...'. One sentence max.",
    )
    concepts: list[str] = Field(
        default_factory=list,
        description="1-3 short snake_case concept labels for cross-question tracking (e.g. 'chain_rule', 'u_substitution').",
    )


class PartAnswer(BaseModel):
    """Answer for a single labeled part of a question."""

    label: str = Field(..., description="Part label matching the question, e.g. 'a', 'b', 'i', 'ii'")
    steps: list[Step] = Field(..., description="Step-by-step solution walkthrough")
    final_answer: str = Field(..., description="Concise final answer, e.g. '$x = 5$', '$42$ cm$^2$'")
    parts: list[PartAnswer] = Field(default_factory=list, description="Answers for nested sub-parts")


PartAnswer.model_rebuild()


class QuestionAnswer(BaseModel):
    """Complete answer for a single question."""

    question_number: int = Field(..., description="The problem number this answers")
    steps: list[Step] = Field(
        default_factory=list,
        description="Step-by-step solution for simple questions with no parts",
    )
    final_answer: str = Field(
        default="",
        description="Final answer for simple questions with no parts",
    )
    parts: list[PartAnswer] = Field(
        default_factory=list,
        description="Per-part answers (empty for simple questions)",
    )
