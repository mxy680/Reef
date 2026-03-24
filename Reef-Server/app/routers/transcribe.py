"""POST /ai/transcribe-strokes — proxy handwriting strokes to Mathpix v3 Strokes API."""

import asyncio
import logging
import re as _re

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.services.katex_sanitizer import sanitize_for_katex
from app.services.katex_validator import _validate_katex_expression

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


def _latex_to_plain(latex: str) -> str:
    """Strip LaTeX commands to extract readable plain text as a last resort."""
    s = latex
    # Remove math delimiters
    s = _re.sub(r"\$\$\s*|\s*\$\$", "", s)
    s = _re.sub(r"\$", "", s)
    s = _re.sub(r"\\\[|\\\]|\\\(|\\\)", "", s)
    # \text{content} → content
    s = _re.sub(r"\\text\{([^}]*)\}", r"\1", s)
    s = _re.sub(r"\\mathrm\{([^}]*)\}", r"\1", s)
    s = _re.sub(r"\\textbf\{([^}]*)\}", r"\1", s)
    # \frac{a}{b} → (a)/(b)
    s = _re.sub(r"\\frac\{([^}]*)\}\{([^}]*)\}", r"(\1)/(\2)", s)
    # \sqrt{x} → sqrt(x)
    s = _re.sub(r"\\sqrt\{([^}]*)\}", r"sqrt(\1)", s)
    # Common symbols
    s = s.replace("\\rightarrow", "→")
    s = s.replace("\\leftarrow", "←")
    s = s.replace("\\Rightarrow", "⇒")
    s = s.replace("\\Leftarrow", "⇐")
    s = s.replace("\\leq", "≤").replace("\\geq", "≥")
    s = s.replace("\\neq", "≠").replace("\\approx", "≈")
    s = s.replace("\\times", "×").replace("\\cdot", "·")
    s = s.replace("\\pm", "±").replace("\\infty", "∞")
    s = s.replace("\\alpha", "α").replace("\\beta", "β")
    s = s.replace("\\gamma", "γ").replace("\\delta", "δ")
    s = s.replace("\\theta", "θ").replace("\\pi", "π")
    s = s.replace("\\sigma", "σ").replace("\\mu", "μ")
    s = s.replace("\\lambda", "λ").replace("\\omega", "ω")
    s = s.replace("\\Delta", "Δ").replace("\\Sigma", "Σ")
    # Strip remaining \command patterns
    s = _re.sub(r"\\[a-zA-Z]+\*?(?:\{[^}]*\})*", "", s)
    # Clean up braces and extra whitespace
    s = s.replace("{", "").replace("}", "")
    s = _re.sub(r"[_^]", "", s)
    s = _re.sub(r"\s+", " ", s).strip()
    return s


class StrokeData(BaseModel):
    x: list[float] = Field(..., max_length=2000)
    y: list[float] = Field(..., max_length=2000)


class TranscribeStrokesRequest(BaseModel):
    strokes: list[StrokeData] = Field(..., max_length=100)
    session_id: str | None = None
    app_token: str | None = None


class TranscribeStrokesResponse(BaseModel):
    latex: str
    session_id: str | None = None


class CreateSessionResponse(BaseModel):
    app_token: str
    strokes_session_id: str
    expires_at: int  # unix timestamp ms


@router.post("/strokes-session", response_model=CreateSessionResponse)
async def create_strokes_session(
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.mathpix_app_key:
        raise HTTPException(status_code=503, detail="Mathpix credentials not configured")

    try:
        from app.services.mathpix_pool import acquire_session
        token, session_id, expires_at = await acquire_session()
        return CreateSessionResponse(
            app_token=token,
            strokes_session_id=session_id,
            expires_at=expires_at,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=502, detail=str(e))


@router.post("/transcribe-strokes", response_model=TranscribeStrokesResponse)
async def transcribe_strokes(
    body: TranscribeStrokesRequest,
    user: AuthenticatedUser = Depends(get_current_user),
):
    if not settings.mathpix_app_id or not settings.mathpix_app_key:
        raise HTTPException(status_code=503, detail="Mathpix credentials not configured")

    # Use the client's session for temporal continuity, fall back to pool if not provided
    if body.app_token and body.session_id:
        token = body.app_token
        sid = body.session_id
    else:
        from app.services.mathpix_pool import acquire_session
        token, sid, _ = await acquire_session()

    headers = {"app_token": token, "Content-Type": "application/json"}

    payload: dict = {
        "strokes": {
            "strokes": {
                "x": [s.x for s in body.strokes],
                "y": [s.y for s in body.strokes],
            }
        },
        "strokes_session_id": sid,
    }

    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/strokes",
            json=payload,
            headers=headers,
        )

    if resp.status_code != 200:
        log.warning(f"Mathpix strokes API returned {resp.status_code}: {resp.text}")
        raise HTTPException(status_code=502, detail="Mathpix transcription failed")

    data = resp.json()
    if "error" in data:
        raise HTTPException(status_code=502, detail=f"Mathpix error: {data.get('error')}")

    latex = data.get("latex", data.get("text", ""))
    session_id = data.get("strokes_session_id", data.get("session_id"))

    # Sanitize for KaTeX compatibility before wrapping
    if latex:
        latex = sanitize_for_katex(latex)

        # Validate — if KaTeX fails, fall back to plain text (no slow LLM fix)
        error = await asyncio.to_thread(_validate_katex_expression, latex)
        if error:
            log.warning(f"KaTeX validation failed: {error[:80]}")
            plain = _latex_to_plain(latex)
            if plain.strip():
                log.info(f"[transcribe] Falling back to plain text: {plain[:60]}")
                return TranscribeStrokesResponse(latex=plain, session_id=session_id)

    # Wrap in display math delimiters if not already wrapped
    if latex and not latex.startswith("$") and not latex.startswith("\\[") and not latex.startswith("\\("):
        latex = f"$$ {latex} $$"
    return TranscribeStrokesResponse(latex=latex, session_id=session_id)
