from pydantic import BaseModel, Field
from typing import Literal


class GenerateQuestionRequest(BaseModel):
    subject: Literal["math", "physics", "chemistry", "biology", "economics", "computer_science"]
    topic: str = Field(..., max_length=200)
    difficulty: int = Field(..., ge=1, le=5)
    num_steps: int = Field(..., ge=2, le=6)


class GenerateQuestionResponse(BaseModel):
    document_id: str
    filename: str
    page_count: int
    problem_count: int
