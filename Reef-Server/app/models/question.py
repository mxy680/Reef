"""Pydantic models for structured question representation.

Used as the intermediate schema between LLM extraction and deterministic
LaTeX generation.  The LLM produces a Question object (via structured
output), and a converter turns it into LaTeX with zero LLM involvement.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class Part(BaseModel):
    """A labeled part of a question (e.g. a, b, i, ii). Recursive."""
    label: str = Field(..., description="Part label, e.g. 'a', 'b', 'i', 'ii'")
    text: str = Field(..., description="Question text (inline $...$ and display \\[...\\] math)")
    figures: list[str] = Field(default_factory=list, description="Figure filenames for this part")
    parts: list[Part] = Field(default_factory=list, description="Recursive subparts")
    answer_space_cm: float = Field(
        default=8.0,
        description="Vertical answer space in cm. Ignored if subparts present.",
        ge=0,
        le=25,
    )


Part.model_rebuild()


class Question(BaseModel):
    """A single homework/exam question with optional parts.

    Hierarchy: Question → Part → Part → ...  The LLM fills this via
    structured output; a deterministic converter turns it into LaTeX.
    """
    number: int = Field(..., description="Problem number as shown in the document")
    text: str = Field(..., description="Stem / preamble text (inline $...$ and display \\[...\\] math)")
    figures: list[str] = Field(default_factory=list, description="Figure filenames for the stem")
    parts: list[Part] = Field(default_factory=list, description="Parts (a, b, c, ...). Empty for simple questions.")
    answer_space_cm: float = Field(
        default=8.0,
        description="Vertical answer space in cm. Ignored if parts present.",
        ge=0,
        le=25,
    )


class QuestionBatch(BaseModel):
    """Multiple questions extracted from a single image containing several problems."""
    questions: list[Question] = Field(..., description="All questions found in the image")


class VerificationResult(BaseModel):
    """Result of visual verification comparing original document vs reconstruction."""
    needs_fix: bool = Field(
        ...,
        description="True if the reconstruction has meaningful discrepancies from the original",
    )
    issues: list[str] = Field(
        default_factory=list,
        description="List of specific issues found (empty if needs_fix is false)",
    )
    fixed_latex: str = Field(
        default="",
        description="Corrected LaTeX body content (empty if needs_fix is false)",
    )
