"""Hershey font-based stroke templates for all math symbols.

Replaces hand-tuned templates with single-stroke vector data from the
Hershey font family. Each character is a set of polyline strokes that
Mathpix recognizes as handwriting.

Greek letters use the 'greek' font (A=Alpha, B=Beta, S=Sigma, etc.)
Math symbols use the 'mathupp' font.
Latin letters/digits use the 'futural' font (simplex sans-serif).
"""

from __future__ import annotations

from HersheyFonts import HersheyFonts

Stroke = dict[str, list[float]]

# Pre-load fonts
_latin_font = HersheyFonts()
_latin_font.load_default_font("futural")

_greek_font = HersheyFonts()
_greek_font.load_default_font("greek")

_math_font = HersheyFonts()
_math_font.load_default_font("mathupp")

# Map LaTeX symbol names / Unicode chars to (font, ascii_key) pairs.
# Greek font maps ASCII letters → Greek glyphs.
_GREEK_UPPER = {
    "Α": "A", "Β": "B", "Γ": "C", "Δ": "D", "Ε": "E", "Φ": "F",
    "Η": "G", "Χ": "H", "Ι": "I", "Κ": "K", "Λ": "L", "Μ": "M",
    "Ν": "N", "Ο": "O", "Π": "P", "Ρ": "R", "Σ": "S", "Τ": "T",
    "Υ": "U", "Θ": "V", "Ω": "W", "Ξ": "X", "Ψ": "Y", "Ζ": "Z",
}
_GREEK_LOWER = {
    "α": "a", "β": "b", "χ": "c", "δ": "d", "ε": "e", "φ": "f",
    "γ": "g", "η": "h", "ι": "i", "κ": "k", "λ": "l", "μ": "m",
    "ν": "n", "ο": "o", "π": "p", "ρ": "r", "σ": "s", "τ": "t",
    "υ": "u", "θ": "v", "ω": "w", "ξ": "x", "ψ": "y", "ζ": "z",
}


def _segments_to_strokes(
    segments: list[tuple[tuple[float, float], tuple[float, float]]],
    cx: float,
    cy: float,
    size: float,
    flip_y: bool = True,
) -> list[Stroke]:
    """Convert Hershey line segments into stroke dicts.

    Hershey segments are individual line pairs. Consecutive segments that
    share an endpoint belong to the same pen stroke. We merge them into
    continuous polylines, then scale/translate to (cx, cy, size).
    """
    if not segments:
        return []

    # Merge connected segments into polylines
    polylines: list[list[tuple[float, float]]] = []
    current: list[tuple[float, float]] = [segments[0][0], segments[0][1]]

    for seg in segments[1:]:
        if seg[0] == current[-1]:
            # Continuation of current stroke
            current.append(seg[1])
        else:
            # Pen up — start new stroke
            polylines.append(current)
            current = [seg[0], seg[1]]
    polylines.append(current)

    # Find bounding box of all points for normalization
    all_pts = [pt for poly in polylines for pt in poly]
    if not all_pts:
        return []

    min_x = min(p[0] for p in all_pts)
    max_x = max(p[0] for p in all_pts)
    min_y = min(p[1] for p in all_pts)
    max_y = max(p[1] for p in all_pts)

    w = max_x - min_x or 1
    h = max_y - min_y or 1
    scale = size / max(w, h)

    # Center the glyph at (cx, cy) and scale
    mid_x = (min_x + max_x) / 2
    mid_y = (min_y + max_y) / 2

    strokes: list[Stroke] = []
    for poly in polylines:
        xs = []
        ys = []
        for px, py in poly:
            x = cx + (px - mid_x) * scale
            if flip_y:
                y = cy + (py - mid_y) * scale
            else:
                y = cy - (py - mid_y) * scale
            xs.append(round(x, 2))
            ys.append(round(y, 2))

        # Interpolate short segments for smoother appearance
        if len(xs) >= 2:
            strokes.append({"x": xs, "y": ys})

    return strokes


def hershey_strokes(char: str, cx: float, cy: float, size: float) -> list[Stroke]:
    """Get Hershey stroke data for a character.

    Args:
        char: The character or Unicode symbol (e.g., 'A', 'σ', 'Σ', '+')
        cx, cy: Center position for the rendered glyph
        size: Approximate height of the rendered glyph in points

    Returns:
        List of stroke dicts with 'x' and 'y' coordinate arrays.
    """
    # Try Greek mapping first
    if char in _GREEK_UPPER:
        segments = list(_greek_font.lines_for_text(_GREEK_UPPER[char]))
        if segments:
            return _segments_to_strokes(segments, cx, cy, size)

    if char in _GREEK_LOWER:
        segments = list(_greek_font.lines_for_text(_GREEK_LOWER[char]))
        if segments:
            return _segments_to_strokes(segments, cx, cy, size)

    # Try math font for operators
    segments = list(_math_font.lines_for_text(char))
    if segments:
        return _segments_to_strokes(segments, cx, cy, size)

    # Fall back to Latin font
    segments = list(_latin_font.lines_for_text(char))
    if segments:
        return _segments_to_strokes(segments, cx, cy, size)

    return []


# LaTeX command → Unicode character mapping
LATEX_TO_CHAR: dict[str, str] = {
    # Greek uppercase
    "Alpha": "Α", "Beta": "Β", "Gamma": "Γ", "Delta": "Δ", "Epsilon": "Ε",
    "Zeta": "Ζ", "Eta": "Η", "Theta": "Θ", "Iota": "Ι", "Kappa": "Κ",
    "Lambda": "Λ", "Mu": "Μ", "Nu": "Ν", "Xi": "Ξ", "Pi": "Π",
    "Rho": "Ρ", "Sigma": "Σ", "Tau": "Τ", "Upsilon": "Υ", "Phi": "Φ",
    "Chi": "Χ", "Psi": "Ψ", "Omega": "Ω",
    # Greek lowercase
    "alpha": "α", "beta": "β", "gamma": "γ", "delta": "δ", "epsilon": "ε",
    "zeta": "ζ", "eta": "η", "theta": "θ", "iota": "ι", "kappa": "κ",
    "lambda": "λ", "mu": "μ", "nu": "ν", "xi": "ξ", "pi": "π",
    "rho": "ρ", "sigma": "σ", "tau": "τ", "upsilon": "υ", "phi": "φ",
    "chi": "χ", "psi": "ψ", "omega": "ω",
    # Special
    "sum": "Σ", "Sum": "Σ",
    "infty": "∞", "infinity": "∞",
    "partial": "∂",
    "pm": "±", "mp": "∓",
    "times": "×", "cdot": "·", "div": "÷",
    "leq": "≤", "geq": "≥", "neq": "≠", "approx": "≈",
    "rightarrow": "→", "leftarrow": "←",
}
