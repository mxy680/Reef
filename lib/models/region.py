"""Pydantic model for question part regions in compiled PDFs."""

from __future__ import annotations

from pydantic import BaseModel, Field


class PartRegion(BaseModel):
    """A region in a compiled PDF corresponding to a question part.

    Coordinates are in PDF points (72 DPI), origin at top-left.
    """
    label: str | None = Field(
        ...,
        description="Part label (e.g. 'a', 'b', 'a.i'), or None for the question stem",
    )
    page: int = Field(..., description="0-indexed page number")
    y_start: float = Field(..., description="Top of region in PDF points")
    y_end: float = Field(..., description="Bottom of region in PDF points")
