"""Pydantic models for onboarding demo problem generation."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field
from app.models.answer_key import Step


class DemoProblemRequest(BaseModel):
    """Request body for POST /ai/demo-problem."""

    topic: str = Field(..., max_length=200, description="Student's favorite topic, e.g. 'derivatives', 'Newton's laws'")
    student_type: Literal["high_school", "college", "graduate"] = Field(default="college")


class DemoProblem(BaseModel):
    """LLM-generated demo problem with answer key."""

    question_text: str = Field(..., description="The problem statement in LaTeX ($...$ for math)")
    steps: list[Step] = Field(..., description="2-3 step solution walkthrough")
    final_answer: str = Field(..., description="Concise final answer")
    tutor_intro: str = Field(..., description="Casual one-liner the tutor says to introduce the problem, e.g. 'Alright, let's try some derivatives.'")


class DemoProblemResponse(BaseModel):
    """Response body for POST /ai/demo-problem."""

    question_text: str
    steps: list[Step]
    final_answer: str
    tutor_intro: str


class DemoChatHistoryMessage(BaseModel):
    """A single message in the demo chat history."""

    role: str = Field(..., description="student or tutor")
    text: str = Field(..., max_length=2000)


class DemoChatRequest(BaseModel):
    """Request body for POST /ai/demo-chat."""

    user_message: str = Field(..., max_length=1000, description="Student's message to the tutor")
    question_text: str = Field(..., description="The demo problem text")
    steps_overview: str = Field(default="", description="Steps overview for context")
    current_step_description: str = Field(default="", description="Current step description")
    student_work: str = Field(default="", max_length=5000, description="Student's work so far")
    history: list[DemoChatHistoryMessage] = Field(default_factory=list, max_length=20)


class DemoChatResponse(BaseModel):
    """Response body for POST /ai/demo-chat."""

    reply: str
    speech_audio: str | None = None


class DemoDocumentRequest(BaseModel):
    """Request body for POST /ai/demo-document."""

    topic: str = Field(..., max_length=200)
    student_type: Literal["high_school", "college", "graduate"] = Field(default="college")


class DemoDocumentResponse(BaseModel):
    """Response body for POST /ai/demo-document."""

    document_id: str
    filename: str
    page_count: int
    problem_count: int
