"""LaTeX-to-PNG rendering service using matplotlib's mathtext engine.

Accepts mixed text with inline `$...$` and display `\\[...\\]` math blocks and
renders them to a tight-fitting PNG image.

Matplotlib's mathtext renderer understands TeX math syntax natively inside
`$...$` delimiters.  Plain text segments are rendered as-is.  Display-math
blocks (`\\[...\\]`) are rendered centered on their own line.

This module is CPU-bound and synchronous; callers should use
`asyncio.to_thread` to avoid blocking the event loop.
"""

from __future__ import annotations

import io
import re
import textwrap
from dataclasses import dataclass, field

import matplotlib
import matplotlib.pyplot as plt
from matplotlib.figure import Figure

# Use the non-interactive Agg backend so no display is required.
matplotlib.use("Agg")

# ---------------------------------------------------------------------------
# Text segmentation
# ---------------------------------------------------------------------------

@dataclass
class _Segment:
    """A run of text that is either plain prose or a math expression."""
    text: str
    is_display_math: bool = False   # True → \\[...\\] block (centered, own line)
    is_inline_math: bool = False    # True → $...$ span


def _parse_segments(text: str) -> list[_Segment]:
    """Split *text* into alternating plain-text and math segments.

    Handles:
    - Display math: ``\\[...\\]`` (may span newlines)
    - Inline math:  ``$...$``

    Plain newlines in prose segments are preserved so that callers can decide
    how to wrap them.
    """
    segments: list[_Segment] = []

    # Combined pattern: display math (\\[...\\]) takes priority over inline ($...$).
    # We use non-greedy matching and DOTALL so display blocks can span lines.
    pattern = re.compile(
        r'(\\\[.*?\\\]|\$[^$]+?\$)',
        re.DOTALL,
    )

    pos = 0
    for m in pattern.finditer(text):
        start, end = m.start(), m.end()

        # Plain-text segment before this match
        if start > pos:
            segments.append(_Segment(text=text[pos:start]))

        raw = m.group(0)
        if raw.startswith(r'\['):
            # Strip the \\[ ... \\] delimiters; keep inner content.
            inner = raw[2:-2].strip()
            segments.append(_Segment(text=inner, is_display_math=True))
        else:
            # Inline $...$: keep the delimiters so matplotlib renders it as math.
            segments.append(_Segment(text=raw, is_inline_math=True))

        pos = end

    # Trailing plain text
    if pos < len(text):
        segments.append(_Segment(text=text[pos:]))

    return segments


# ---------------------------------------------------------------------------
# Line builder
# ---------------------------------------------------------------------------

@dataclass
class _Line:
    """A single rendered line composed of one or more (text, style) pairs."""
    parts: list[tuple[str, dict]] = field(default_factory=list)
    is_display: bool = False  # Centred display-math line


def _build_lines(segments: list[_Segment], max_width: int, font_size: float) -> list[_Line]:
    """Convert segments into renderable lines, honouring *max_width* (pixels).

    Plain-text is word-wrapped.  Display-math blocks are placed on their own
    centred line.  Inline math stays inline with adjacent prose.

    *max_width* is in pixels at 96 dpi; we use a rough character-width
    estimate to wrap prose so we don't over-rely on font metrics at this stage.
    """
    # Approximate characters per line based on font size and pixel width.
    # At 96 dpi, font_size pts ≈ font_size * 96/72 px per em.
    px_per_char = font_size * 96 / 72 * 0.55  # 0.55 = typical width/height ratio
    chars_per_line = max(20, int(max_width / px_per_char))

    lines: list[_Line] = []
    current_line = _Line()

    def flush():
        nonlocal current_line
        if current_line.parts:
            lines.append(current_line)
            current_line = _Line()

    plain_style: dict = {"color": "black"}
    math_style: dict = {"color": "black"}

    for seg in segments:
        if seg.is_display_math:
            # Display math always starts and ends on its own line.
            flush()
            # Wrap the math expression itself in $...$ for matplotlib rendering.
            lines.append(_Line(parts=[("$" + seg.text + "$", math_style)], is_display=True))

        elif seg.is_inline_math:
            current_line.parts.append((seg.text, math_style))

        else:
            # Plain text — split on hard newlines first, then word-wrap each chunk.
            hard_lines = seg.text.split("\n")
            for hi, hard_line in enumerate(hard_lines):
                if hi > 0:
                    flush()
                if not hard_line:
                    continue
                # Word-wrap this chunk
                wrapped = textwrap.wrap(hard_line, width=chars_per_line) or [hard_line]
                for wi, chunk in enumerate(wrapped):
                    if wi > 0:
                        flush()
                    current_line.parts.append((chunk, plain_style))

    flush()
    return lines


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

_DISPLAY_MATH_FONT_SCALE = 1.15  # Display math rendered slightly larger


def render_latex_to_png(
    text: str,
    font_size: float = 14.0,
    max_width: int = 260,
    dpi: int = 144,
    padding: int = 12,
) -> bytes:
    """Render *text* (mixed prose + LaTeX math) to a PNG and return raw bytes.

    Parameters
    ----------
    text:
        Input string with optional ``$...$`` inline math and ``\\[...\\]``
        display-math blocks.
    font_size:
        Base font size in points.
    max_width:
        Soft maximum content width in *points* (not pixels).  The actual image
        may be slightly wider if a single math expression is wider.
    dpi:
        Output resolution.  144 dpi gives crisp results on Retina / HiDPI
        displays without being excessively large.
    padding:
        Horizontal and vertical padding in points around the content.

    Returns
    -------
    bytes
        Raw PNG image data.
    """
    segments = _parse_segments(text)
    lines = _build_lines(segments, max_width=max_width, font_size=font_size)

    if not lines:
        # Return a 1×1 transparent PNG for empty input.
        fig = Figure(figsize=(0.01, 0.01), dpi=dpi)
        buf = io.BytesIO()
        fig.savefig(buf, format="png", transparent=True)
        return buf.getvalue()

    # ------------------------------------------------------------------ #
    # Measure each line using a temporary figure, then produce the final  #
    # figure sized to exactly fit the content.                            #
    # ------------------------------------------------------------------ #

    # Points per inch — matplotlib uses inches internally.
    PPI = 72.0

    # Create a scratch figure for measurement.  We give it a generous size so
    # text never clips during measurement.
    scratch_width_in = (max_width + 4 * padding) / PPI
    scratch_height_in = max(4.0, len(lines) * (font_size + 4) * len(lines) / PPI)
    scratch = Figure(figsize=(scratch_width_in, scratch_height_in), dpi=dpi)
    ax = scratch.add_axes([0, 0, 1, 1])
    ax.set_axis_off()
    ax.set_xlim(0, scratch_width_in * PPI)
    ax.set_ylim(0, scratch_height_in * PPI)

    line_height = font_size * 1.6   # points (leading)
    display_line_height = font_size * _DISPLAY_MATH_FONT_SCALE * 2.0

    line_heights: list[float] = []
    line_widths: list[float] = []

    renderer = scratch.canvas.get_renderer()

    for line in lines:
        if line.is_display:
            lh = display_line_height
        else:
            lh = line_height

        # Measure total width of parts joined together.
        combined = "".join(p for p, _ in line.parts)
        fs = font_size * _DISPLAY_MATH_FONT_SCALE if line.is_display else font_size
        t = ax.text(
            0, 0, combined,
            fontsize=fs,
            usetex=False,  # matplotlib mathtext, not full LaTeX
            va="baseline",
            ha="left",
        )
        try:
            bb = t.get_window_extent(renderer=renderer)
            # Convert from display units (pixels) back to points.
            w_pts = bb.width * PPI / dpi
        except Exception:
            w_pts = max_width
        t.remove()

        line_heights.append(lh)
        line_widths.append(w_pts)

    plt.close("all")

    # Final image dimensions
    content_width = min(max(line_widths) if line_widths else max_width, max_width * 2)
    content_height = sum(line_heights)
    img_width_in = (content_width + 2 * padding) / PPI
    img_height_in = (content_height + 2 * padding) / PPI

    fig = Figure(figsize=(img_width_in, img_height_in), dpi=dpi)
    fig.patch.set_facecolor("white")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_axis_off()
    ax.set_facecolor("white")

    fig_width_pts = img_width_in * PPI
    fig_height_pts = img_height_in * PPI

    # Draw lines top-to-bottom.  Matplotlib y=0 is bottom, so we start near
    # the top and work downward.
    y = fig_height_pts - padding  # current baseline (pts from bottom)

    for i, line in enumerate(lines):
        y -= line_heights[i]  # move baseline down by this line's height

        fs = font_size * _DISPLAY_MATH_FONT_SCALE if line.is_display else font_size

        # Combine all parts into a single string — matplotlib handles the
        # math segments because they remain wrapped in `$...$`.
        combined = "".join(p for p, _ in line.parts)

        if line.is_display:
            x = fig_width_pts / 2.0
            ha = "center"
        else:
            x = padding
            ha = "left"

        ax.text(
            x, y,
            combined,
            fontsize=fs,
            color="black",
            va="baseline",
            ha=ha,
            transform=ax.transData,
            usetex=False,
        )

    ax.set_xlim(0, fig_width_pts)
    ax.set_ylim(0, fig_height_pts)

    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=dpi, bbox_inches=None, facecolor="white")
    plt.close("all")
    return buf.getvalue()
