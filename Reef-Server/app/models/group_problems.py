"""Models for the group-problems endpoint."""

from pydantic import BaseModel, Field


class ProblemGroup(BaseModel):
    """A group of annotations that belong to the same problem."""
    problem_number: int = Field(
        ...,
        description="Problem number as shown in the document (0 for headers/titles)"
    )
    annotation_indices: list[int] = Field(
        ...,
        description="List of annotation indices belonging to this problem"
    )
    label: str = Field(
        default="",
        description="Human-readable label for this problem group"
    )


class GroupProblemsResponse(BaseModel):
    """Response from the group-problems endpoint."""
    problems: list[ProblemGroup] = Field(
        ...,
        description="List of problem groups with their annotation indices"
    )
    total_annotations: int = Field(
        ...,
        description="Total number of annotations across all pages"
    )
    total_problems: int = Field(
        ...,
        description="Total number of problem groups"
    )
    page_count: int = Field(
        ...,
        description="Number of pages in the PDF"
    )
