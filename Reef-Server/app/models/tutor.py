"""Pydantic models for real-time tutor evaluation."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

TutorStatus = Literal["idle", "working", "mistake", "completed"]


class TutorEvaluateRequest(BaseModel):
    """Request body for POST /ai/tutor-evaluate."""

    document_id: str = Field(..., description="Supabase document UUID")
    question_number: int = Field(..., description="1-based question number")
    part_label: str | None = Field(None, description="Part label (a, b, i, ii) or null for top-level")
    step_index: int = Field(..., description="0-based step index within the part")
    student_latex: str = Field(..., max_length=5000, description="Transcribed LaTeX from student handwriting")
    figure_urls: list[str] = Field(default_factory=list, description="Signed URLs for question figures")
    student_image: str | None = Field(None, max_length=2_000_000, description="Base64-encoded JPEG of student's drawing")


class TutorEvaluation(BaseModel):
    """Structured output schema for the LLM evaluation."""

    progress: float = Field(
        ...,
        description="Progress through this step: 0.0 (nothing) to 1.0 (complete)",
        ge=0.0,
        le=1.0,
    )
    status: TutorStatus = Field(
        ...,
        description="One of: idle, working, mistake, completed",
    )
    mistake_explanation: str | None = Field(
        None,
        description="LaTeX explanation of the mistake (null unless status is mistake)",
    )


class TutorEvaluateResponse(BaseModel):
    """Response body for POST /ai/tutor-evaluate."""

    progress: float
    status: TutorStatus
    mistake_explanation: str | None = None


class ChatHistoryMessage(BaseModel):
    """A single message in the conversation history."""
    role: Literal["student", "error", "reinforcement", "answer"] = Field(...)
    text: str = Field(..., max_length=2000)


class TutorChatRequest(BaseModel):
    """Request body for POST /ai/tutor-chat."""

    document_id: str = Field(..., description="Supabase document UUID")
    question_number: int = Field(..., description="1-based question number")
    part_label: str | None = Field(None, description="Part label or null")
    step_index: int = Field(..., description="0-based step index")
    student_latex: str = Field(default="", max_length=5000, description="Current transcribed work")
    user_message: str = Field(..., max_length=1000, description="User's question to the tutor")
    history: list[ChatHistoryMessage] = Field(default_factory=list, description="Previous chat messages for context")
    student_image: str | None = Field(None, max_length=2_000_000, description="Base64-encoded JPEG of student's drawing")


class TutorChatLLMOutput(BaseModel):
    """Structured output from the LLM for chat responses."""

    reply: str = Field(..., description="Written response with $...$ math notation for display")
    speech: str = Field(..., max_length=500, description="Verbal response — no math notation, say numbers and formulas in words, 1-2 sentences max")


class TutorChatResponse(BaseModel):
    """Response body for POST /ai/tutor-chat."""

    reply: str
    speech_audio: str | None = None  # base64-encoded audio
