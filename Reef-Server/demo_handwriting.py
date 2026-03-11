"""
LaTeX to Handwriting Demo
Run: python demo_handwriting.py
Open: http://localhost:8123
"""

import numpy as np
from fastapi import FastAPI
from fastapi.responses import HTMLResponse, JSONResponse
from matplotlib.path import Path as MplPath
from matplotlib.textpath import TextPath
from pydantic import BaseModel
from scipy.ndimage import gaussian_filter1d

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

  // Wire up presets
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      $('latex').value = btn.dataset.latex;
      convert();
    });
  });

  // Auto-render on typing
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

  // Initial render
  convert();
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Core algorithm
# ---------------------------------------------------------------------------

# Tuned defaults
SPACING = 1.0       # Dense sampling for smooth curves
AMPLITUDE = 0.6     # Subtle but visible wobble
SMOOTH_SIGMA = 3.0  # Gaussian smoothing kernel for wobble (larger = smoother waves)
JITTER = 0.08       # Tiny micro-tremor
STROKE_WIDTH = 0.5  # Thin outline stroke on filled shapes


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


def sample_path_points(path, spacing: float = SPACING) -> list[np.ndarray]:
    """Split matplotlib Path into subpaths and sample points at regular intervals."""
    vertices = path.vertices
    codes = path.codes

    subpaths: list[list[np.ndarray]] = []
    current: list[np.ndarray] = []
    start_pt = None
    i = 0

    while i < len(codes):
        code = codes[i]

        if code == MplPath.MOVETO:
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
            p1 = vertices[i]
            p2 = vertices[i + 1]
            arc_len = _estimate_bezier2_length(p0, p1, p2)
            n_pts = max(3, int(arc_len / spacing))
            for t in np.linspace(0, 1, n_pts)[1:]:
                current.append(_bezier2(p0, p1, p2, t))
            i += 2

        elif code == MplPath.CURVE4:
            p0 = current[-1]
            p1 = vertices[i]
            p2 = vertices[i + 1]
            p3 = vertices[i + 2]
            arc_len = _estimate_bezier3_length(p0, p1, p2, p3)
            n_pts = max(3, int(arc_len / spacing))
            for t in np.linspace(0, 1, n_pts)[1:]:
                current.append(_bezier3(p0, p1, p2, p3, t))
            i += 3

        elif code == MplPath.CLOSEPOLY:
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
    rng: np.random.Generator,
) -> np.ndarray:
    """Displace points with smooth Gaussian-filtered wobble + micro jitter."""
    n = len(points)
    if n < 3:
        return points.copy()

    result = points.copy()

    # Generate white noise, then smooth it with a Gaussian kernel
    # This creates natural, low-frequency waves along the contour
    raw_noise = rng.normal(0, 1, size=(n, 2))
    smooth_wobble = np.column_stack([
        gaussian_filter1d(raw_noise[:, 0], sigma=SMOOTH_SIGMA, mode="wrap"),
        gaussian_filter1d(raw_noise[:, 1], sigma=SMOOTH_SIGMA, mode="wrap"),
    ])
    smooth_wobble *= AMPLITUDE

    # Tiny high-frequency jitter for pen texture
    jitter = rng.normal(0, JITTER, size=(n, 2))

    result += smooth_wobble + jitter
    return result


def points_to_svg_subpath(points: np.ndarray) -> str:
    """Generate an SVG path 'd' subpath (M...L...Z) from a point array."""
    parts = [f"M{points[0][0]:.2f},{points[0][1]:.2f}"]
    for x, y in points[1:]:
        parts.append(f"L{x:.2f},{y:.2f}")
    parts.append("Z")
    return " ".join(parts)


def latex_to_handwriting_svg(latex: str, seed: int = 42) -> str:
    """Full pipeline: LaTeX → TextPath → sample → noise → SVG string."""
    text = latex.strip()
    if text.startswith("$") and text.endswith("$"):
        text = "$" + text[1:-1] + "$"
    elif not text.startswith("$"):
        text = "$" + text + "$"

    path = TextPath((0, 0), text, size=48)
    subpaths = sample_path_points(path)

    if not subpaths:
        return (
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50">'
            '<text x="10" y="30" font-size="14" fill="#999">No path data</text></svg>'
        )

    rng = np.random.default_rng(seed)
    all_points = []

    for sp in subpaths:
        noisy = add_handwriting_noise(sp, rng)
        all_points.append(noisy)

    # Flip Y axis: TextPath uses math coords (y-up), SVG is y-down
    for i, pts in enumerate(all_points):
        all_points[i] = pts.copy()
        all_points[i][:, 1] *= -1

    all_pts = np.vstack(all_points)
    x_min, y_min = all_pts.min(axis=0)
    x_max, y_max = all_pts.max(axis=0)
    pad = 10
    vb_x = x_min - pad
    vb_y = y_min - pad
    vb_w = (x_max - x_min) + 2 * pad
    vb_h = (y_max - y_min) + 2 * pad

    d = " ".join(points_to_svg_subpath(pts) for pts in all_points)

    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="{vb_x:.2f} {vb_y:.2f} {vb_w:.2f} {vb_h:.2f}" '
        f'width="{vb_w:.0f}" height="{vb_h:.0f}">\n'
        f'  <path d="{d}" fill="#1a1a1a" fill-rule="evenodd" '
        f'stroke="#1a1a1a" stroke-width="{STROKE_WIDTH}" '
        f'stroke-linejoin="round" />\n'
        f'</svg>'
    )
    return svg


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
