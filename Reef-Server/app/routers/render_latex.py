"""POST /render-latex — render mixed text + LaTeX math to a PNG image."""

import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, Field

from app.auth import AuthenticatedUser, get_current_user
from app.services.latex_renderer import render_latex_to_png

logger = logging.getLogger(__name__)

router = APIRouter(tags=["render"])


class RenderLatexRequest(BaseModel):
    text: str = Field(
        ...,
        description=(
            "Mixed prose and LaTeX math.  Inline math uses $...$ delimiters; "
            "display math uses \\[...\\] delimiters."
        ),
        min_length=1,
    )
    font_size: float = Field(
        default=14.0,
        ge=6.0,
        le=72.0,
        description="Base font size in points.",
    )
    max_width: int = Field(
        default=260,
        ge=100,
        le=2000,
        description="Soft maximum content width in points before word-wrapping.",
    )


@router.post("/render-latex", response_class=Response)
async def render_latex(
    body: RenderLatexRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> Response:
    """Render *text* (with embedded LaTeX math) to a PNG image.

    Returns a ``image/png`` response whose dimensions fit the content tightly.
    The image has a white background and is rendered at 144 dpi for crisp
    display on HiDPI (Retina) screens.
    """
    try:
        png_bytes = await asyncio.to_thread(
            render_latex_to_png,
            body.text,
            font_size=body.font_size,
            max_width=body.max_width,
        )
    except Exception as e:
        logger.error(f"[render-latex] Rendering failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="LaTeX rendering failed")

    return Response(
        content=png_bytes,
        media_type="image/png",
        headers={
            # Tell clients the image is a fresh render; cache for 10 minutes.
            "Cache-Control": "public, max-age=600",
        },
    )
