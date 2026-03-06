"""Pydantic models for answer key generation.

Mirrors the Question/Part hierarchy so answer keys align 1:1 with
extracted question parts.  The LLM produces a QuestionAnswer object
(via structured output) and it is stored as JSON in the answer_keys table.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class PartAnswer(BaseModel):
    """Answer for a single labeled part of a question."""

    label: str = Field(..., description="Part label matching the question, e.g. 'a', 'b', 'i', 'ii'")
    answer: str = Field(..., description="Step-by-step solution (LaTeX math: $...$ inline, \\[...\\] display)")
    final_answer: str = Field(..., description="Concise final answer, e.g. '$x = 5$', '$42$ cm$^2$'")
    parts: list[PartAnswer] = Field(default_factory=list, description="Answers for nested sub-parts")


PartAnswer.model_rebuild()


class QuestionAnswer(BaseModel):
    """Complete answer for a single question."""

    question_number: int = Field(..., description="The problem number this answers")
    answer: str = Field(
        default="",
        description="Solution for the stem/preamble if no parts, or general approach note",
    )
    final_answer: str = Field(
        default="",
        description="Final answer for simple questions with no parts",
    )
    parts: list[PartAnswer] = Field(
        default_factory=list,
        description="Per-part answers (empty for simple questions)",
    )
