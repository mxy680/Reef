"""
LaTeX to Handwriting Demo
Run: python demo_handwriting.py
Open: http://localhost:8123
"""

import io
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.font_manager import FontProperties, fontManager
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel

matplotlib.use("Agg")

# ---------------------------------------------------------------------------
# Load handwriting font (Caveat)
# ---------------------------------------------------------------------------

_FONT_PATH = Path(__file__).parent / "fonts" / "Caveat-Regular.ttf"
_HAND_FONT = FontProperties(fname=str(_FONT_PATH))

# Register font so matplotlib's mathtext engine can find it
fontManager.addfont(str(_FONT_PATH))
_font_family = _HAND_FONT.get_name()

# Configure mathtext to use the handwriting font for all symbol classes
matplotlib.rcParams["mathtext.fontset"] = "custom"
matplotlib.rcParams["mathtext.rm"] = _font_family
matplotlib.rcParams["mathtext.it"] = _font_family
matplotlib.rcParams["mathtext.bf"] = _font_family
matplotlib.rcParams["mathtext.sf"] = _font_family
matplotlib.rcParams["mathtext.tt"] = _font_family

app = FastAPI()

# ---------------------------------------------------------------------------
# HTML Template
# ---------------------------------------------------------------------------

HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>LaTeX → Handwriting</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: system-ui, -apple-system, sans-serif;
    background: #f5f0e8;
    color: #1a1a1a;
    min-height: 100vh;
    display: flex;
    justify-content: center;
    padding: 40px 20px;
  }
  .container { max-width: 720px; width: 100%; }
  h1 {
    font-size: 1.8rem;
    margin-bottom: 8px;
    font-weight: 700;
  }
  .subtitle {
    color: #555;
    margin-bottom: 28px;
    font-size: 0.95rem;
  }
  label {
    display: block;
    font-weight: 600;
    margin-bottom: 4px;
    font-size: 0.88rem;
  }
  textarea {
    width: 100%;
    height: 64px;
    padding: 10px 12px;
    border: 2px solid #1a1a1a;
    border-radius: 8px;
    font-family: 'SF Mono', 'Fira Code', monospace;
    font-size: 1rem;
    resize: vertical;
    background: #fff;
  }
  textarea:focus { outline: none; border-color: #4a7c59; }
  .presets {
    margin: 10px 0 20px;
    display: flex;
    flex-wrap: wrap;
    gap: 6px;
  }
  .preset-btn {
    padding: 5px 12px;
    border: 1.5px solid #1a1a1a;
    border-radius: 6px;
    background: #fff;
    font-size: 0.82rem;
    font-family: 'SF Mono', monospace;
    cursor: pointer;
    transition: background 0.15s;
  }
  .preset-btn:hover { background: #e8e3d9; }
  .btn-row { display: flex; gap: 10px; margin-bottom: 24px; }
  button.convert {
    padding: 10px 28px;
    background: #1a1a1a;
    color: #fff;
    border: none;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  button.convert:hover { background: #333; }
  button.convert:disabled { opacity: 0.5; cursor: wait; }
  .output-card {
    background: #fff;
    border: 2px solid #1a1a1a;
    border-radius: 12px;
    padding: 32px;
    min-height: 160px;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 3px 3px 0 #1a1a1a;
  }
  .output-card svg { max-width: 100%; height: auto; }
  .placeholder { color: #aaa; font-style: italic; }
  .error { color: #c0392b; font-size: 0.9rem; margin-top: 8px; }
  .reseed {
    padding: 10px 20px;
    background: #fff;
    border: 2px solid #1a1a1a;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .reseed:hover { background: #e8e3d9; }
</style>
</head>
<body>
<div class="container">
  <h1>LaTeX → Handwriting</h1>
  <p class="subtitle">Type LaTeX and watch it render as hand-drawn strokes.</p>

  <label for="latex">LaTeX Expression</label>
  <textarea id="latex" spellcheck="false">$\int_0^1 x^2 \, dx$</textarea>

  <div class="presets">
    <button class="preset-btn" data-latex="$\int_0^1 x^2 \, dx$">∫ x² dx</button>
    <button class="preset-btn" data-latex="$E = mc^2$">E=mc²</button>
    <button class="preset-btn" data-latex="$\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$">Quadratic</button>
    <button class="preset-btn" data-latex="$\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}$">Basel</button>
    <button class="preset-btn" data-latex="$\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}$">Maxwell</button>
    <button class="preset-btn" data-latex="$e^{i\pi} + 1 = 0$">Euler</button>
  </div>

  <div class="btn-row">
    <button class="convert" id="convert-btn" onclick="convert()">Convert</button>
    <button class="reseed" id="reseed-btn" onclick="reseed()">Reseed</button>
  </div>

  <div class="output-card" id="output">
    <span class="placeholder">Rendered handwriting will appear here</span>
  </div>
  <div class="error" id="error"></div>
</div>

<script>
  const $ = id => document.getElementById(id);
  let debounceTimer = null;
  let seed = Math.floor(Math.random() * 10000);

  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      $('latex').value = btn.dataset.latex;
      convert();
    });
  });

  $('latex').addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(convert, 500);
  });

  function reseed() {
    seed = Math.floor(Math.random() * 10000);
    convert();
  }

  async function convert() {
    const btn = $('convert-btn');
    btn.disabled = true;
    $('error').textContent = '';

    try {
      const res = await fetch('/convert', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ latex: $('latex').value, seed }),
      });
      const data = await res.json();
      if (data.error) {
        $('error').textContent = data.error;
        $('output').innerHTML = '<span class="placeholder">Error — see below</span>';
      } else {
        $('output').innerHTML = data.svg;
      }
    } catch (e) {
      $('error').textContent = 'Request failed: ' + e.message;
    } finally {
      btn.disabled = false;
    }
  }

  convert();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Core: render LaTeX via matplotlib, inject SVG displacement filter
# ---------------------------------------------------------------------------

SVG_FILTER = """
<defs>
  <filter id="handdrawn" x="-5%%" y="-5%%" width="110%%" height="110%%">
    <!-- Low-freq warping for overall shape distortion -->
    <feTurbulence type="turbulence" baseFrequency="0.015" numOctaves="3"
                  seed="%d" result="warp"/>
    <feDisplacementMap in="SourceGraphic" in2="warp" scale="4"
                       xChannelSelector="R" yChannelSelector="G" result="warped"/>
    <!-- High-freq roughness for ink texture -->
    <feTurbulence type="turbulence" baseFrequency="0.06" numOctaves="2"
                  seed="%d" result="rough"/>
    <feDisplacementMap in="warped" in2="rough" scale="1.5"
                       xChannelSelector="R" yChannelSelector="G" result="roughed"/>
    <!-- Slight thickening to simulate ink spread -->
    <feMorphology operator="dilate" radius="0.3" in="roughed" result="thick"/>
    <!-- Soften edges slightly -->
    <feGaussianBlur stdDeviation="0.2" in="thick"/>
  </filter>
</defs>
"""


def latex_to_handwriting_svg(latex: str, seed: int = 42) -> str:
    """Render LaTeX via matplotlib SVG backend, then inject handwriting filter."""
    text = latex.strip()
    if not text.startswith("$"):
        text = "$" + text + "$"
    if not text.endswith("$"):
        text = text + "$"

    # Render with matplotlib to SVG (paths, not fonts)
    plt.rcParams["svg.fonttype"] = "path"
    fig, ax = plt.subplots(figsize=(8, 2))
    ax.text(
        0.5, 0.5, text,
        fontsize=36,
        fontproperties=_HAND_FONT,
        ha="center", va="center",
        transform=ax.transAxes,
        color="#1a1a1a",
    )
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")
    fig.patch.set_alpha(0)
    ax.patch.set_alpha(0)

    buf = io.BytesIO()
    fig.savefig(buf, format="svg", transparent=True, bbox_inches="tight", pad_inches=0.1)
    plt.close(fig)

    svg_str = buf.getvalue().decode("utf-8")

    # Inject the handwriting filter into the SVG
    rng = np.random.default_rng(seed)
    seed1 = int(rng.integers(0, 100000))
    seed2 = int(rng.integers(0, 100000))
    filter_def = SVG_FILTER % (seed1, seed2)

    # Insert filter defs after opening <svg> tag
    svg_str = svg_str.replace(
        "<defs>",
        filter_def + "\n<defs>" if "<defs>" in svg_str else filter_def,
        1,
    )

    # Wrap all content in a filtered group
    # Find the first <g> after defs and add filter
    svg_str = svg_str.replace(
        '</defs>\n',
        '</defs>\n<g filter="url(#handdrawn)">\n',
        1,
    )
    # Close the filter group before </svg>
    svg_str = svg_str.replace("</svg>", "</g>\n</svg>")

    return svg_str


# ---------------------------------------------------------------------------
# FastAPI routes
# ---------------------------------------------------------------------------


class ConvertRequest(BaseModel):
    latex: str
    seed: int = 42


@app.get("/", response_class=HTMLResponse)
async def index():
    return HTML_TEMPLATE


@app.post("/convert")
async def convert(req: ConvertRequest):
    try:
        svg = latex_to_handwriting_svg(latex=req.latex, seed=req.seed)
        return JSONResponse({"svg": svg})
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=400)


if __name__ == "__main__":
    import uvicorn

    print("Starting LaTeX → Handwriting demo at http://localhost:8123")
    uvicorn.run(app, host="0.0.0.0", port=8123)
