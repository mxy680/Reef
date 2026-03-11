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

_FONT_PATH = Path(__file__).parent / "fonts" / "IndieFlower-Regular.ttf"
_HAND_FONT = FontProperties(fname=str(_FONT_PATH))

# Register font so matplotlib's mathtext engine can find it
fontManager.addfont(str(_FONT_PATH))
_font_family = _HAND_FONT.get_name()

# Configure mathtext to use the handwriting font for letters/numbers,
# falling back to STIX for math operators (∫, Σ, √, etc.)
matplotlib.rcParams["mathtext.fontset"] = "custom"
matplotlib.rcParams["mathtext.rm"] = _font_family
matplotlib.rcParams["mathtext.it"] = _font_family
matplotlib.rcParams["mathtext.bf"] = _font_family
matplotlib.rcParams["mathtext.sf"] = _font_family
matplotlib.rcParams["mathtext.tt"] = _font_family
matplotlib.rcParams["mathtext.fallback"] = "stix"

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
  .play {
    padding: 10px 20px;
    background: #fff;
    border: 2px solid #1a1a1a;
    border-radius: 8px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
    transition: background 0.15s;
  }
  .play:hover { background: #e8e3d9; }
  .play:disabled { opacity: 0.5; cursor: wait; }
  @keyframes glyphFadeIn {
    from { opacity: 0; transform: translateY(2px); }
    to { opacity: 1; transform: translateY(0); }
  }
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
    <button class="play" id="play-btn" onclick="playAnimation()">Play</button>
  </div>

  <div class="output-card" id="output">
    <span class="placeholder">Rendered handwriting will appear here</span>
  </div>
  <div class="error" id="error"></div>

  <h2 style="margin-top:32px; font-size:1.2rem;">Debug: Path Points</h2>
  <p style="color:#555; font-size:0.85rem; margin-bottom:12px;">Shows the raw SVG path commands for each glyph. Red=MoveTo, Blue=LineTo, Green=Curve endpoints, Gray=Control points.</p>
  <div class="output-card" id="debug-output" style="min-height:200px; overflow:auto;">
    <span class="placeholder">Click Convert, then points appear here</span>
  </div>
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

  let animCleanup = null;

  // Compute a centerline through a glyph by sampling its outline and averaging
  function computeCenterline(pathD, svg, NS) {
    // Create temp path to sample points
    const tmp = document.createElementNS(NS, 'path');
    tmp.setAttribute('d', pathD);
    tmp.style.visibility = 'hidden';
    svg.appendChild(tmp);

    const totalLen = tmp.getTotalLength();
    const numSamples = 200;
    const samples = [];
    for (let i = 0; i <= numSamples; i++) {
      const pt = tmp.getPointAtLength((i / numSamples) * totalLen);
      samples.push({ x: pt.x, y: pt.y });
    }
    tmp.remove();

    // Compute bounds
    let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity;
    samples.forEach(p => {
      minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
    });
    const w = maxX - minX, h = maxY - minY;
    if (w === 0 && h === 0) return null;

    const isVertical = h > w * 1.5;
    const numBins = 25;
    const bins = Array.from({length: numBins}, () => []);

    let centerline, thickness;
    if (isVertical) {
      // Bin by Y, centerline runs top-to-bottom
      samples.forEach(p => {
        const b = Math.min(Math.floor(((p.y - minY) / h) * numBins), numBins - 1);
        bins[b].push(p.x);
      });
      centerline = bins.map((bin, i) => {
        if (bin.length === 0) return null;
        return { x: bin.reduce((s,v) => s+v, 0) / bin.length, y: minY + (i/(numBins-1)) * h };
      }).filter(Boolean);
      thickness = w * 0.9;
    } else {
      // Bin by X, centerline runs left-to-right
      samples.forEach(p => {
        const b = Math.min(Math.floor(((p.x - minX) / w) * numBins), numBins - 1);
        bins[b].push(p.y);
      });
      centerline = bins.map((bin, i) => {
        if (bin.length === 0) return null;
        return { x: minX + (i/(numBins-1)) * w, y: bin.reduce((s,v) => s+v, 0) / bin.length };
      }).filter(Boolean);
      thickness = h * 0.9;
    }

    if (centerline.length < 2) return null;

    // Build path string
    let d = `M ${centerline[0].x} ${centerline[0].y}`;
    for (let i = 1; i < centerline.length; i++) {
      d += ` L ${centerline[i].x} ${centerline[i].y}`;
    }
    return { d, thickness };
  }

  function playAnimation() {
    const svg = $('output').querySelector('svg');
    if (!svg) return;
    const btn = $('play-btn');
    btn.disabled = true;

    if (animCleanup) { animCleanup(); animCleanup = null; }

    const NS = 'http://www.w3.org/2000/svg';
    const textGroup = svg.querySelector('#text_1');
    if (!textGroup) { btn.disabled = false; return; }

    // Collect <use> glyphs and standalone <path>s
    const items = [];
    function collect(el) {
      for (const child of el.children) {
        if (child.tagName === 'use') {
          items.push({ el: child, type: 'use', parentG: child.parentElement });
        } else if (child.tagName === 'path') {
          const p = child.closest('[id]');
          if (p && p.id === 'patch_1') continue;
          items.push({ el: child, type: 'path', parentG: child.parentElement });
        } else if (child.tagName === 'g') {
          collect(child);
        }
      }
    }
    collect(textGroup);
    if (items.length === 0) { btn.disabled = false; return; }

    // Sort by screen position
    items.forEach(item => {
      const r = item.el.getBoundingClientRect();
      item.x = r.left; item.y = r.top; item.w = r.width; item.h = r.height;
    });
    items.sort((a, b) => {
      const xOverlap = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
      if (xOverlap > Math.min(a.w, b.w) * 0.3) return a.y - b.y;
      return a.x - b.x;
    });

    // Create anim defs for clip paths
    let animDefs = svg.querySelector('defs.anim-clips');
    if (!animDefs) {
      animDefs = document.createElementNS(NS, 'defs');
      animDefs.setAttribute('class', 'anim-clips');
      svg.insertBefore(animDefs, svg.firstChild);
    }

    const created = [];
    const timeouts = [];

    // Hide all
    items.forEach(item => { item.el.style.opacity = '0'; });

    function animateItem(idx) {
      if (idx >= items.length) {
        timeouts.push(setTimeout(() => { btn.disabled = false; }, 200));
        return;
      }
      const item = items[idx];

      if (item.type === 'use') {
        const href = item.el.getAttribute('xlink:href') || item.el.getAttribute('href');
        const refPath = textGroup.querySelector(href);
        if (!refPath) { item.el.style.opacity = '1'; animateItem(idx + 1); return; }

        const pathD = refPath.getAttribute('d');
        const cl = computeCenterline(pathD, svg, NS);
        if (!cl) { item.el.style.opacity = '1'; animateItem(idx + 1); return; }

        // Create clip path from glyph outline (in raw font units)
        const clipId = 'anim-clip-' + idx;
        const clipPathEl = document.createElementNS(NS, 'clipPath');
        clipPathEl.id = clipId;
        const clipShape = document.createElementNS(NS, 'path');
        clipShape.setAttribute('d', pathD);
        clipPathEl.appendChild(clipShape);
        animDefs.appendChild(clipPathEl);

        // Build: <g transform="useT"> → <g transform="defT" clip-path> → <path d="centerline">
        const wrapper = document.createElementNS(NS, 'g');
        const useT = item.el.getAttribute('transform') || '';
        const defT = refPath.getAttribute('transform') || '';
        if (useT) wrapper.setAttribute('transform', useT);

        const innerG = document.createElementNS(NS, 'g');
        if (defT) innerG.setAttribute('transform', defT);
        // Clip is in innerG's coordinate system (after defT scale),
        // but clipShape uses raw font units. Since defT is scale(0.015625),
        // and clipPathUnits defaults to userSpaceOnUse (parent coords of innerG = wrapper coords),
        // we need the clipShape in wrapper coords. So add defT to clipShape too.
        if (defT) clipShape.setAttribute('transform', defT);

        innerG.setAttribute('clip-path', `url(#${clipId})`);

        const strokePath = document.createElementNS(NS, 'path');
        strokePath.setAttribute('d', cl.d);
        strokePath.setAttribute('transform', defT || '');
        strokePath.style.fill = 'none';
        strokePath.style.stroke = '#1a1a1a';
        strokePath.style.strokeWidth = cl.thickness;
        strokePath.style.strokeLinecap = 'round';
        strokePath.style.strokeLinejoin = 'round';

        innerG.appendChild(strokePath);
        wrapper.appendChild(innerG);
        item.parentG.appendChild(wrapper);
        created.push(wrapper);

        // Animate with stroke-dasharray
        const len = strokePath.getTotalLength();
        if (len === 0) { item.el.style.opacity = '1'; wrapper.remove(); animateItem(idx + 1); return; }
        strokePath.style.strokeDasharray = len;
        strokePath.style.strokeDashoffset = len;
        strokePath.getBoundingClientRect(); // force reflow

        const dur = Math.max(200, Math.min(600, len * 3));
        strokePath.style.transition = `stroke-dashoffset ${dur}ms ease-out`;
        strokePath.style.strokeDashoffset = '0';

        // After stroke finishes, snap to clean filled glyph
        timeouts.push(setTimeout(() => {
          item.el.style.opacity = '1';
          wrapper.style.display = 'none';
          timeouts.push(setTimeout(() => animateItem(idx + 1), 40));
        }, dur));

      } else {
        // Standalone path (fraction line, sqrt bar): simple dasharray wipe
        const el = item.el;
        const len = el.getTotalLength();
        el.style.opacity = '1';
        if (len > 0) {
          el.style.strokeDasharray = len;
          el.style.strokeDashoffset = len;
          el.getBoundingClientRect();
          const dur = Math.max(150, Math.min(400, len * 2));
          el.style.transition = `stroke-dashoffset ${dur}ms ease-out`;
          el.style.strokeDashoffset = '0';
          timeouts.push(setTimeout(() => {
            el.style.strokeDasharray = '';
            el.style.strokeDashoffset = '';
            el.style.transition = '';
            animateItem(idx + 1);
          }, dur));
        } else {
          animateItem(idx + 1);
        }
      }
    }

    animateItem(0);

    animCleanup = () => {
      timeouts.forEach(clearTimeout);
      created.forEach(el => { try { el.remove(); } catch(e) {} });
      items.forEach(item => {
        item.el.style.opacity = '1';
        item.el.style.strokeDasharray = '';
        item.el.style.strokeDashoffset = '';
        item.el.style.transition = '';
      });
      if (animDefs) { animDefs.innerHTML = ''; animDefs.remove(); }
    };
  }

  // Debug: visualize path points after each convert
  function debugPaths() {
    const svg = $('output').querySelector('svg');
    if (!svg) return;

    const textGroup = svg.querySelector('#text_1');
    if (!textGroup) return;

    // Glyph path defs are nested inside text_1's child <g> > <defs>
    const allDefPaths = textGroup.querySelectorAll('defs path[id]');
    const uses = textGroup.querySelectorAll('use');

    const dbg = $('debug-output');
    dbg.innerHTML = '';

    // Build a mapping of href -> path data
    const pathMap = {};
    allDefPaths.forEach(p => { pathMap['#' + p.id] = p.getAttribute('d'); });

    // For each use, show the path points
    uses.forEach((use, idx) => {
      const href = use.getAttribute('xlink:href') || use.getAttribute('href');
      const d = pathMap[href];
      if (!d) return;

      // Parse path commands
      const points = parsePath(d);

      // Find bounds
      let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
      points.forEach(p => {
        if (p.x < minX) minX = p.x; if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y; if (p.y > maxY) maxY = p.y;
      });
      const pad = 100;
      const w = maxX - minX + pad * 2;
      const h = maxY - minY + pad * 2;

      // Create a mini SVG for this glyph
      const container = document.createElement('div');
      container.style.cssText = 'display:inline-block; margin:8px; vertical-align:top;';

      const label = document.createElement('div');
      label.style.cssText = 'font-size:0.75rem; font-weight:600; margin-bottom:4px;';
      label.textContent = href.replace('#', '') + ` (${points.length} pts)`;
      container.appendChild(label);

      const NS = 'http://www.w3.org/2000/svg';
      const s = document.createElementNS(NS, 'svg');
      const scale = Math.min(200 / w, 200 / h);
      s.setAttribute('width', Math.ceil(w * scale));
      s.setAttribute('height', Math.ceil(h * scale));
      s.setAttribute('viewBox', `${minX - pad} ${minY - pad} ${w} ${h}`);
      s.style.border = '1px solid #ccc';
      s.style.borderRadius = '6px';
      s.style.background = '#fafafa';

      // Draw the filled path faintly
      const bg = document.createElementNS(NS, 'path');
      bg.setAttribute('d', d);
      bg.style.fill = '#eee';
      bg.style.stroke = '#ccc';
      bg.style.strokeWidth = '20';
      s.appendChild(bg);

      // Draw line segments between consecutive points
      for (let i = 1; i < points.length; i++) {
        const prev = points[i - 1];
        const cur = points[i];
        if (cur.cmd === 'M') continue; // new subpath, no line
        const line = document.createElementNS(NS, 'line');
        line.setAttribute('x1', prev.x); line.setAttribute('y1', prev.y);
        line.setAttribute('x2', cur.x); line.setAttribute('y2', cur.y);
        line.style.stroke = '#bbb';
        line.style.strokeWidth = '15';
        s.appendChild(line);
      }

      // Draw control points for curves
      points.forEach(p => {
        if (p.cpx !== undefined) {
          const cp = document.createElementNS(NS, 'circle');
          cp.setAttribute('cx', p.cpx); cp.setAttribute('cy', p.cpy);
          cp.setAttribute('r', '40');
          cp.style.fill = '#aaa';
          s.appendChild(cp);
          // Line from control point to endpoint
          const cl = document.createElementNS(NS, 'line');
          cl.setAttribute('x1', p.cpx); cl.setAttribute('y1', p.cpy);
          cl.setAttribute('x2', p.x); cl.setAttribute('y2', p.y);
          cl.style.stroke = '#ddd'; cl.style.strokeWidth = '10';
          s.appendChild(cl);
        }
      });

      // Draw endpoint dots
      points.forEach((p, i) => {
        const dot = document.createElementNS(NS, 'circle');
        dot.setAttribute('cx', p.x); dot.setAttribute('cy', p.y);
        dot.setAttribute('r', '50');
        if (p.cmd === 'M') dot.style.fill = '#e74c3c'; // red = moveTo
        else if (p.cmd === 'L') dot.style.fill = '#3498db'; // blue = lineTo
        else dot.style.fill = '#2ecc71'; // green = curve endpoint

        // Add order number
        const txt = document.createElementNS(NS, 'text');
        txt.setAttribute('x', p.x + 60); txt.setAttribute('y', p.y + 30);
        txt.style.fontSize = '80px';
        txt.style.fill = '#666';
        txt.textContent = i;

        s.appendChild(dot);
        s.appendChild(txt);
      });

      container.appendChild(s);
      dbg.appendChild(container);
    });
  }

  // Parse SVG path d-string into array of {x, y, cmd, cpx?, cpy?}
  function parsePath(d) {
    const points = [];
    // Tokenize: split into command + numbers
    const tokens = d.match(/[MLQCZHVSmlqczhvs]|[-+]?\d*\.?\d+/g);
    if (!tokens) return points;

    let i = 0;
    let cmd = '';
    let cx = 0, cy = 0; // current point

    while (i < tokens.length) {
      const t = tokens[i];
      if (/[A-Za-z]/.test(t)) {
        cmd = t;
        i++;
        if (cmd === 'Z' || cmd === 'z') continue;
      }
      // Read numbers based on command
      if (cmd === 'M' || cmd === 'L') {
        cx = parseFloat(tokens[i]); cy = parseFloat(tokens[i+1]);
        points.push({ x: cx, y: cy, cmd });
        i += 2;
        if (cmd === 'M') cmd = 'L'; // implicit lineTo after moveTo
      } else if (cmd === 'Q') {
        const cpx = parseFloat(tokens[i]), cpy = parseFloat(tokens[i+1]);
        cx = parseFloat(tokens[i+2]); cy = parseFloat(tokens[i+3]);
        points.push({ x: cx, y: cy, cmd: 'Q', cpx, cpy });
        i += 4;
      } else if (cmd === 'C') {
        const cp1x = parseFloat(tokens[i]), cp1y = parseFloat(tokens[i+1]);
        const cp2x = parseFloat(tokens[i+2]), cp2y = parseFloat(tokens[i+3]);
        cx = parseFloat(tokens[i+4]); cy = parseFloat(tokens[i+5]);
        points.push({ x: cx, y: cy, cmd: 'C', cpx: cp2x, cpy: cp2y });
        i += 6;
      } else if (cmd === 'H') {
        cx = parseFloat(tokens[i]); i++;
        points.push({ x: cx, y: cy, cmd: 'L' });
      } else if (cmd === 'V') {
        cy = parseFloat(tokens[i]); i++;
        points.push({ x: cx, y: cy, cmd: 'L' });
      } else {
        i++; // skip unknown
      }
    }
    return points;
  }

  // Hook into convert to also update debug
  const _origConvert = convert;
  convert = async function() {
    await _origConvert();
    setTimeout(debugPaths, 100);
  };

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
  <filter id="handdrawn" x="-10%%" y="-10%%" width="120%%" height="120%%">
    <!-- Low-freq warping for overall shape distortion -->
    <feTurbulence type="turbulence" baseFrequency="0.008" numOctaves="4"
                  seed="%d" result="warp"/>
    <feDisplacementMap in="SourceGraphic" in2="warp" scale="5"
                       xChannelSelector="R" yChannelSelector="G" result="warped"/>
    <!-- High-freq roughness for ink texture -->
    <feTurbulence type="turbulence" baseFrequency="0.04" numOctaves="3"
                  seed="%d" result="rough"/>
    <feDisplacementMap in="warped" in2="rough" scale="2"
                       xChannelSelector="R" yChannelSelector="G" result="roughed"/>
    <!-- Soften edges slightly -->
    <feGaussianBlur stdDeviation="0.15" in="roughed"/>
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
