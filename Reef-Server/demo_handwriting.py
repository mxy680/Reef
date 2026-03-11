"""
LaTeX to Handwriting Demo
Run: python demo_handwriting.py
Open: http://localhost:8123
"""

import io
from typing import Optional

import numpy as np
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse
from matplotlib.path import Path as MplPath
from matplotlib.textpath import TextPath
from pydantic import BaseModel

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
  .controls {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 16px 24px;
    margin-bottom: 24px;
  }
  .control-group { display: flex; flex-direction: column; }
  .slider-header {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
  }
  .slider-value {
    font-family: 'SF Mono', monospace;
    font-size: 0.82rem;
    color: #666;
  }
  input[type="range"] {
    width: 100%;
    margin-top: 4px;
    accent-color: #4a7c59;
  }
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
  .auto-label {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 0.88rem;
    cursor: pointer;
    user-select: none;
  }
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

  <div class="controls">
    <div class="control-group">
      <div class="slider-header">
        <label for="noise">Noise</label>
        <span class="slider-value" id="noise-val">1.0</span>
      </div>
      <input type="range" id="noise" min="0" max="3" step="0.1" value="1.0">
    </div>
    <div class="control-group">
      <div class="slider-header">
        <label for="stroke">Stroke Width</label>
        <span class="slider-value" id="stroke-val">1.0</span>
      </div>
      <input type="range" id="stroke" min="0.2" max="2" step="0.1" value="1.0">
    </div>
    <div class="control-group">
      <div class="slider-header">
        <label for="spacing">Point Spacing</label>
        <span class="slider-value" id="spacing-val">1.5</span>
      </div>
      <input type="range" id="spacing" min="0.5" max="5" step="0.1" value="1.5">
    </div>
    <div class="control-group">
      <div class="slider-header">
        <label for="seed">Seed</label>
        <span class="slider-value" id="seed-val">42</span>
      </div>
      <input type="range" id="seed" min="0" max="999" step="1" value="42">
    </div>
  </div>

  <div class="btn-row">
    <button class="convert" id="convert-btn" onclick="convert()">Convert</button>
    <label class="auto-label">
      <input type="checkbox" id="auto-render" checked> Auto-render
    </label>
  </div>

  <div class="output-card" id="output">
    <span class="placeholder">Rendered handwriting will appear here</span>
  </div>
  <div class="error" id="error"></div>
</div>

<script>
  const $ = id => document.getElementById(id);
  let debounceTimer = null;

  // Wire up sliders
  for (const name of ['noise', 'stroke', 'spacing', 'seed']) {
    const el = $(name);
    el.addEventListener('input', () => {
      $(name + '-val').textContent = el.value;
      scheduleAutoRender();
    });
  }

  // Wire up presets
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      $('latex').value = btn.dataset.latex;
      scheduleAutoRender();
    });
  });

  // Wire up textarea
  $('latex').addEventListener('input', () => scheduleAutoRender());

  function scheduleAutoRender() {
    if (!$('auto-render').checked) return;
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(convert, 400);
  }

  async function convert() {
    const btn = $('convert-btn');
    btn.disabled = true;
    $('error').textContent = '';

    try {
      const res = await fetch('/convert', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          latex: $('latex').value,
          noise: parseFloat($('noise').value),
          stroke_width: parseFloat($('stroke').value),
          spacing: parseFloat($('spacing').value),
          seed: parseInt($('seed').value),
        }),
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

  // Initial render
  convert();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Core algorithm
# ---------------------------------------------------------------------------


def _bezier2(p0, p1, p2, t):
    """Evaluate quadratic Bezier at parameter t."""
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t**2 * p2


def _bezier3(p0, p1, p2, p3, t):
    """Evaluate cubic Bezier at parameter t."""
    return (
        (1 - t) ** 3 * p0
        + 3 * (1 - t) ** 2 * t * p1
        + 3 * (1 - t) * t**2 * p2
        + t**3 * p3
    )


def _estimate_bezier2_length(p0, p1, p2, n=10):
    ts = np.linspace(0, 1, n)
    pts = np.array([_bezier2(p0, p1, p2, t) for t in ts])
    return np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1))


def _estimate_bezier3_length(p0, p1, p2, p3, n=10):
    ts = np.linspace(0, 1, n)
    pts = np.array([_bezier3(p0, p1, p2, p3, t) for t in ts])
    return np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1))


def sample_path_points(path, spacing: float = 1.5) -> list[np.ndarray]:
    """Split matplotlib Path into subpaths and sample points at regular intervals.

    Returns a list of numpy arrays, each shape (N, 2), one per subpath.
    """
    vertices = path.vertices
    codes = path.codes

    subpaths: list[list[np.ndarray]] = []
    current: list[np.ndarray] = []
    start_pt = None
    i = 0

    while i < len(codes):
        code = codes[i]

        if code == MplPath.MOVETO:
            # Start a new subpath
            if current:
                subpaths.append(current)
            current = [vertices[i].copy()]
            start_pt = vertices[i].copy()
            i += 1

        elif code == MplPath.LINETO:
            p0 = current[-1]
            p1 = vertices[i]
            seg_len = np.linalg.norm(p1 - p0)
            n_pts = max(2, int(seg_len / spacing))
            for t in np.linspace(0, 1, n_pts)[1:]:
                current.append(p0 + t * (p1 - p0))
            i += 1

        elif code == MplPath.CURVE3:
            p0 = current[-1]
            p1 = vertices[i]      # control point
            p2 = vertices[i + 1]  # end point
            arc_len = _estimate_bezier2_length(p0, p1, p2)
            n_pts = max(3, int(arc_len / spacing))
            for t in np.linspace(0, 1, n_pts)[1:]:
                current.append(_bezier2(p0, p1, p2, t))
            i += 2

        elif code == MplPath.CURVE4:
            p0 = current[-1]
            p1 = vertices[i]      # control point 1
            p2 = vertices[i + 1]  # control point 2
            p3 = vertices[i + 2]  # end point
            arc_len = _estimate_bezier3_length(p0, p1, p2, p3)
            n_pts = max(3, int(arc_len / spacing))
            for t in np.linspace(0, 1, n_pts)[1:]:
                current.append(_bezier3(p0, p1, p2, p3, t))
            i += 3

        elif code == MplPath.CLOSEPOLY:
            # Close back to start
            if start_pt is not None and current:
                p0 = current[-1]
                seg_len = np.linalg.norm(start_pt - p0)
                if seg_len > 0.1:
                    n_pts = max(2, int(seg_len / spacing))
                    for t in np.linspace(0, 1, n_pts)[1:]:
                        current.append(p0 + t * (start_pt - p0))
                current.append(start_pt.copy())
            subpaths.append(current)
            current = []
            start_pt = None
            i += 1

        else:
            i += 1

    if current:
        subpaths.append(current)

    return [np.array(sp) for sp in subpaths if len(sp) >= 2]


def add_handwriting_noise(
    points: np.ndarray,
    amplitude: float = 1.0,
    smoothness: float = 0.85,
    rng: np.random.Generator | None = None,
) -> np.ndarray:
    """Displace points with random-walk wobble + Gaussian jitter."""
    if rng is None:
        rng = np.random.default_rng()
    if amplitude == 0:
        return points.copy()

    n = len(points)
    result = points.copy()

    # Low-frequency wobble: random walk with mean reversion
    walk = np.zeros((n, 2))
    for i in range(1, n):
        walk[i] = smoothness * walk[i - 1] + rng.normal(0, 0.3, size=2)
    walk *= amplitude * 0.4

    # High-frequency jitter
    jitter = rng.normal(0, amplitude * 0.15, size=(n, 2))

    result += walk + jitter
    return result


def points_to_svg_polyline(
    points: np.ndarray,
    stroke_width: float = 1.0,
    color: str = "#1a1a1a",
) -> str:
    """Generate <polyline> SVG element from a point array."""
    coords = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return (
        f'<polyline points="{coords}" '
        f'fill="none" stroke="{color}" '
        f'stroke-width="{stroke_width}" '
        f'stroke-linecap="round" stroke-linejoin="round" />'
    )


def latex_to_handwriting_svg(
    latex: str,
    noise: float = 1.0,
    stroke_width: float = 1.0,
    spacing: float = 1.5,
    seed: int = 42,
) -> str:
    """Full pipeline: LaTeX → TextPath → sample → noise → SVG string."""
    # Strip $ wrappers — TextPath's mathtext expects raw math
    text = latex.strip()
    if text.startswith("$") and text.endswith("$"):
        text = "$" + text[1:-1] + "$"
    elif not text.startswith("$"):
        text = "$" + text + "$"

    path = TextPath((0, 0), text, size=48)
    subpaths = sample_path_points(path, spacing=spacing)

    if not subpaths:
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"><text x="10" y="30" font-size="14" fill="#999">No path data</text></svg>'

    rng = np.random.default_rng(seed)
    polylines = []
    all_points = []

    for sp in subpaths:
        noisy = add_handwriting_noise(sp, amplitude=noise, smoothness=0.85, rng=rng)
        polylines.append(points_to_svg_polyline(noisy, stroke_width, color="#1a1a1a"))
        all_points.append(noisy)

    all_pts = np.vstack(all_points)
    x_min, y_min = all_pts.min(axis=0)
    x_max, y_max = all_pts.max(axis=0)
    pad = max(stroke_width * 3, 8)
    vb_x = x_min - pad
    vb_y = y_min - pad
    vb_w = (x_max - x_min) + 2 * pad
    vb_h = (y_max - y_min) + 2 * pad

    # Flip Y axis since TextPath uses math coords (y-up) but SVG is y-down
    transform = f'transform="scale(1, -1) translate(0, {-(y_min + y_max):.2f})"'

    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{vb_x:.2f} {-y_max - pad:.2f} {vb_w:.2f} {vb_h:.2f}" '
        f'width="{vb_w:.0f}" height="{vb_h:.0f}">\n'
        f'  <g {transform}>\n'
    )
    for pl in polylines:
        svg += f"    {pl}\n"
    svg += "  </g>\n</svg>"
    return svg


# ---------------------------------------------------------------------------
# FastAPI routes
# ---------------------------------------------------------------------------


class ConvertRequest(BaseModel):
    latex: str
    noise: float = 1.0
    stroke_width: float = 1.0
    spacing: float = 1.5
    seed: int = 42


@app.get("/", response_class=HTMLResponse)
async def index():
    return HTML_TEMPLATE


@app.post("/convert")
async def convert(req: ConvertRequest):
    try:
        svg = latex_to_handwriting_svg(
            latex=req.latex,
            noise=req.noise,
            stroke_width=req.stroke_width,
            spacing=req.spacing,
            seed=req.seed,
        )
        return JSONResponse({"svg": svg})
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=400)


if __name__ == "__main__":
    import uvicorn

    print("Starting LaTeX → Handwriting demo at http://localhost:8123")
    uvicorn.run(app, host="0.0.0.0", port=8123)
