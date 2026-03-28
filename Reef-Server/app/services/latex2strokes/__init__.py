"""latex2strokes — convert LaTeX math expressions into handwriting stroke data.

Public API:

    from app.services.latex2strokes import latex_to_strokes

    strokes = latex_to_strokes("3x + 5")
    # Returns list[dict[str, list[float]]] — each dict has "x" and "y" arrays.
    # Compatible with Mathpix /v3/strokes API format.
"""
from __future__ import annotations

from .jitter import naturalize
from .layout import layout
from .parser import parse_latex
from .templates import get_strokes


def latex_to_strokes(
    latex: str,
    *,
    origin_x: float = 50.0,
    origin_y: float = 100.0,
    font_size: float = 40.0,
    jitter: bool = True,
    seed: int | None = None,
) -> list[dict[str, list[float]]]:
    """Convert a LaTeX math expression into handwriting stroke data.

    Args:
        latex: LaTeX math string (no surrounding $ delimiters needed).
        origin_x: Left margin x-coordinate of the expression baseline start.
        origin_y: Baseline y-coordinate.
        font_size: Nominal character height in canvas units.
        jitter: Whether to add handwriting imperfections.
        seed: Random seed for reproducible jitter. None = random each call.

    Returns:
        List of stroke dicts, each with "x" and "y" keys holding float arrays.
        Suitable for passing directly to Mathpix /v3/strokes API.
    """
    tree = parse_latex(latex)
    placed = layout(tree, origin_x=origin_x, origin_y=origin_y, font_size=font_size)

    strokes: list[dict[str, list[float]]] = []
    for sym in placed:
        sym_strokes = get_strokes(sym.symbol, sym.x, sym.y, sym.size)
        strokes.extend(sym_strokes)

    if jitter and strokes:
        strokes = naturalize(strokes, seed=seed)

    return strokes


__all__ = ["latex_to_strokes"]
