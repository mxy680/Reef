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
        description="Short label shown to the student, e.g. 'Set up the equation', 'Apply the chain rule'",
    )
    explanation: str = Field(
        ...,
        description="Teaching guidance for the tutor: why this step matters, common mistakes, pedagogy hints",
    )
    work: str = Field(
        ...,
        description="Actual solution content for this step (LaTeX math with $...$ inline, \\[...\\] display, or plain text)",
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
