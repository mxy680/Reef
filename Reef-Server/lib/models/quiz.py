"""Pydantic models for quiz generation API."""

from pydantic import BaseModel, Field


class QuizGenerationRequest(BaseModel):
    """Request body for /ai/generate-quiz endpoint."""

    topic: str = Field(..., description="Quiz topic (e.g. 'Chapter 3: Derivatives')")
    difficulty: str = Field(..., description="Difficulty level: easy, medium, or hard")
    num_questions: int = Field(..., description="Number of questions to generate (1-10)", ge=1, le=10)
    rag_context: str = Field(..., description="RAG-retrieved course content for grounding")
    use_general_knowledge: bool = Field(default=False, description="Allow questions beyond provided notes")
    additional_notes: str | None = Field(default=None, description="Extra instructions for quiz generation")
    question_types: list[str] = Field(default_factory=lambda: ["open_ended"], description="Question types to include")


class QuizQuestionResponse(BaseModel):
    """A single generated quiz question with its compiled PDF."""

    number: int = Field(..., description="Question number (1-indexed)")
    pdf_base64: str = Field(..., description="Base64-encoded PDF of the compiled question")
    topic: str | None = Field(default=None, description="Optional topic tag for this question")
