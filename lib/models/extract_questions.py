"""Models for question extraction endpoint."""

from pydantic import BaseModel, Field


class ExtractQuestionsRequest(BaseModel):
    """Request body for question extraction."""
    pdf_base64: str = Field(
        ...,
        description="Base64-encoded PDF file content"
    )
    note_id: str = Field(
        ...,
        description="UUID of the note for tracking"
    )


class QuestionData(BaseModel):
    """A single extracted question."""
    order_index: int = Field(
        ...,
        description="Zero-based index of the question in order"
    )
    question_number: str = Field(
        ...,
        description="Question number/identifier from the document"
    )
    pdf_base64: str = Field(
        ...,
        description="Base64-encoded PDF of this question"
    )
    has_images: bool = Field(
        default=False,
        description="Whether the question contains images"
    )
    has_tables: bool = Field(
        default=False,
        description="Whether the question contains tables"
    )


class ExtractQuestionsResponse(BaseModel):
    """Response from question extraction endpoint."""
    questions: list[QuestionData] = Field(
        ...,
        description="List of extracted questions as individual PDFs"
    )
    note_id: str = Field(
        ...,
        description="UUID of the source note"
    )
    total_count: int = Field(
        ...,
        description="Total number of questions extracted"
    )
