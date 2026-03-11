"""LaTeX-to-PNG rendering service using tectonic + PyMuPDF.

Compiles mixed text with LaTeX math to a tight-cropped PNG image.
Uses the same tectonic TeX engine as the document reconstruction pipeline
for high-quality output with proper fonts and math rendering.

This module is CPU-bound and synchronous; callers should use
`asyncio.to_thread` to avoid blocking the event loop.
"""

from __future__ import annotations

import io
import shutil
import subprocess
import tempfile
from pathlib import Path

import fitz  # PyMuPDF
from PIL import Image, ImageChops

# ---------------------------------------------------------------------------
# LaTeX template
# ---------------------------------------------------------------------------

_TEMPLATE = r"""
\documentclass[{base_size}pt]{{article}}

\usepackage[
  paperwidth={paper_w}pt,
  paperheight=1440pt,
  margin=0pt,
  top={pad}pt,
  left={pad}pt,
  right={pad}pt,
  bottom={pad}pt
]{{geometry}}

\usepackage{{amsmath}}
\usepackage{{amssymb}}
\usepackage{{amsfonts}}
\usepackage{{lmodern}}
\usepackage[T1]{{fontenc}}

\pagestyle{{empty}}
\setlength{{\parindent}}{{0pt}}
\setlength{{\parskip}}{{0.5em}}
\binoppenalty=10000
\relpenalty=10000

\begin{{document}}
{font_cmd}
{content}
\end{{document}}
"""


# ---------------------------------------------------------------------------
# Renderer
# ---------------------------------------------------------------------------

def render_latex_to_png(
    text: str,
    font_size: float = 18.0,
    max_width: int = 260,
    dpi: int = 216,
    padding: int = 16,
) -> bytes:
    """Render *text* (mixed prose + LaTeX math) to a PNG and return raw bytes.

    Parameters
    ----------
    text:
        Input string with LaTeX markup (``$...$``, ``\\[...\\]``, etc.).
    font_size:
        Base font size in points.
    max_width:
        Text area width in points.
    dpi:
        Output resolution.
    padding:
        Padding in points around the content.

    Returns
    -------
    bytes
        Raw PNG image data.
    """
    if not text.strip():
        img = Image.new("RGB", (1, 1), (255, 255, 255))
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()

    # Build LaTeX document
    base_size = min([10, 11, 12], key=lambda s: abs(s - font_size))
    paper_w = max_width + 2 * padding

    if font_size not in (10.0, 11.0, 12.0):
        font_cmd = rf"\fontsize{{{font_size:.1f}pt}}{{{font_size * 1.2:.1f}pt}}\selectfont"
    else:
        font_cmd = ""

    document = _TEMPLATE.format(
        base_size=base_size,
        paper_w=paper_w,
        pad=padding,
        font_cmd=font_cmd,
        content=text,
    )

    # Compile with tectonic
    temp_dir = Path(tempfile.mkdtemp())
    try:
        tex_file = temp_dir / "render.tex"
        tex_file.write_text(document, encoding="utf-8")

        result = subprocess.run(
            ["tectonic", str(tex_file), "--outdir", str(temp_dir)],
            capture_output=True, text=True, timeout=30,
        )

        if result.returncode != 0:
            raise RuntimeError(f"tectonic failed: {result.stderr}")

        pdf_bytes = (temp_dir / "render.pdf").read_bytes()
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)

    # Render PDF to pixmap
    doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    page = doc[0]
    mat = fitz.Matrix(dpi / 72, dpi / 72)
    pix = page.get_pixmap(matrix=mat, alpha=False)

    # Crop whitespace
    img = Image.frombytes("RGB", (pix.width, pix.height), pix.samples)
    doc.close()

    bg = Image.new("RGB", img.size, (255, 255, 255))
    diff = ImageChops.difference(img, bg)
    bbox = diff.getbbox()

    if bbox is None:
        buf = io.BytesIO()
        Image.new("RGB", (1, 1), (255, 255, 255)).save(buf, format="PNG")
        return buf.getvalue()

    # Add padding back around content
    pad_px = int(padding * dpi / 72)
    x0 = max(0, bbox[0] - pad_px)
    y0 = max(0, bbox[1] - pad_px)
    x1 = min(img.width, bbox[2] + pad_px)
    y1 = min(img.height, bbox[3] + pad_px)
    cropped = img.crop((x0, y0, x1, y1))

    buf = io.BytesIO()
    cropped.save(buf, format="PNG")
    return buf.getvalue()
