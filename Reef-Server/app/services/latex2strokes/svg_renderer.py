"""Render LaTeX to stroke coordinates via tectonic + mutool SVG pipeline.

Pipeline: LaTeX string → tectonic (PDF) → mutool (SVG) → parse SVG paths → stroke coords

This produces pixel-perfect mathematical rendering that Mathpix recognizes
with near-100% accuracy, since it's tracing actual typeset glyphs.
"""

from __future__ import annotations

import math
import os
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET

Stroke = dict[str, list[float]]


def _parse_svg_path(d: str) -> list[tuple[float, float]]:
    """Parse SVG path d-attribute into (x,y) points by sampling bezier curves."""
    points: list[tuple[float, float]] = []
    tokens = re.findall(
        r'[MmLlCcZzHhVvSsQqTtAa]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?', d
    )

    cx, cy = 0.0, 0.0
    start_x, start_y = 0.0, 0.0
    i = 0

    def next_num() -> float:
        nonlocal i
        if i < len(tokens) and tokens[i][0] not in 'MmLlCcZzHhVvSsQqTtAa':
            v = float(tokens[i])
            i += 1
            return v
        return 0.0

    def is_num() -> bool:
        return i < len(tokens) and tokens[i][0] not in 'MmLlCcZzHhVvSsQqTtAa'

    while i < len(tokens):
        if not tokens[i][0].isalpha():
            i += 1
            continue
        cmd = tokens[i]
        i += 1

        if cmd == 'M':
            cx, cy = next_num(), next_num()
            start_x, start_y = cx, cy
            points.append((cx, cy))
            while is_num():
                cx, cy = next_num(), next_num()
                points.append((cx, cy))
        elif cmd == 'm':
            cx += next_num()
            cy += next_num()
            start_x, start_y = cx, cy
            points.append((cx, cy))
            while is_num():
                cx += next_num()
                cy += next_num()
                points.append((cx, cy))
        elif cmd == 'L':
            while is_num():
                cx, cy = next_num(), next_num()
                points.append((cx, cy))
        elif cmd == 'l':
            while is_num():
                cx += next_num()
                cy += next_num()
                points.append((cx, cy))
        elif cmd == 'H':
            while is_num():
                cx = next_num()
                points.append((cx, cy))
        elif cmd == 'h':
            while is_num():
                cx += next_num()
                points.append((cx, cy))
        elif cmd == 'V':
            while is_num():
                cy = next_num()
                points.append((cx, cy))
        elif cmd == 'v':
            while is_num():
                cy += next_num()
                points.append((cx, cy))
        elif cmd == 'C':
            while is_num():
                x1, y1 = next_num(), next_num()
                x2, y2 = next_num(), next_num()
                x3, y3 = next_num(), next_num()
                for t_i in range(1, 9):
                    t = t_i / 8
                    mt = 1 - t
                    x = mt**3 * cx + 3 * mt**2 * t * x1 + 3 * mt * t**2 * x2 + t**3 * x3
                    y = mt**3 * cy + 3 * mt**2 * t * y1 + 3 * mt * t**2 * y2 + t**3 * y3
                    points.append((x, y))
                cx, cy = x3, y3
        elif cmd == 'c':
            while is_num():
                dx1, dy1 = next_num(), next_num()
                dx2, dy2 = next_num(), next_num()
                dx3, dy3 = next_num(), next_num()
                x1, y1 = cx + dx1, cy + dy1
                x2, y2 = cx + dx2, cy + dy2
                x3, y3 = cx + dx3, cy + dy3
                for t_i in range(1, 9):
                    t = t_i / 8
                    mt = 1 - t
                    x = mt**3 * cx + 3 * mt**2 * t * x1 + 3 * mt * t**2 * x2 + t**3 * x3
                    y = mt**3 * cy + 3 * mt**2 * t * y1 + 3 * mt * t**2 * y2 + t**3 * y3
                    points.append((x, y))
                cx, cy = x3, y3
        elif cmd == 'Q':
            while is_num():
                x1, y1 = next_num(), next_num()
                x2, y2 = next_num(), next_num()
                for t_i in range(1, 9):
                    t = t_i / 8
                    mt = 1 - t
                    x = mt**2 * cx + 2 * mt * t * x1 + t**2 * x2
                    y = mt**2 * cy + 2 * mt * t * y1 + t**2 * y2
                    points.append((x, y))
                cx, cy = x2, y2
        elif cmd == 'q':
            while is_num():
                dx1, dy1 = next_num(), next_num()
                dx2, dy2 = next_num(), next_num()
                x1, y1 = cx + dx1, cy + dy1
                x2, y2 = cx + dx2, cy + dy2
                for t_i in range(1, 9):
                    t = t_i / 8
                    mt = 1 - t
                    x = mt**2 * cx + 2 * mt * t * x1 + t**2 * x2
                    y = mt**2 * cy + 2 * mt * t * y1 + t**2 * y2
                    points.append((x, y))
                cx, cy = x2, y2
        elif cmd in ('Z', 'z'):
            if points and (cx != start_x or cy != start_y):
                points.append((start_x, start_y))
            cx, cy = start_x, start_y
        else:
            pass  # skip unknown commands

    return points


def latex_to_svg_strokes(
    latex: str,
    *,
    scale: float = 1.0,
    offset_x: float = 0.0,
    offset_y: float = 0.0,
) -> list[Stroke]:
    """Convert a LaTeX math expression into stroke coordinates via SVG rendering.

    Args:
        latex: LaTeX math expression (no $ delimiters needed).
        scale: Scale factor applied to the output coordinates.
        offset_x, offset_y: Translation applied after scaling.

    Returns:
        List of stroke dicts with 'x' and 'y' float arrays.
    """
    with tempfile.TemporaryDirectory() as tmpdir:
        tex_path = os.path.join(tmpdir, "expr.tex")
        pdf_path = os.path.join(tmpdir, "expr.pdf")
        svg_base = os.path.join(tmpdir, "expr")

        # Write LaTeX document
        with open(tex_path, "w") as f:
            f.write(
                "\\documentclass[border=2pt]{standalone}\n"
                "\\usepackage{amsmath}\n"
                "\\begin{document}\n"
                f"${latex}$\n"
                "\\end{document}\n"
            )

        # Render to PDF via tectonic
        result = subprocess.run(
            ["tectonic", tex_path, "-o", tmpdir],
            capture_output=True, text=True, timeout=15,
        )
        if result.returncode != 0:
            raise RuntimeError(f"tectonic failed: {result.stderr[:500]}")

        # Convert PDF to SVG via mutool
        result = subprocess.run(
            ["mutool", "convert", "-o", f"{svg_base}.svg", pdf_path],
            capture_output=True, text=True, timeout=10,
        )
        if result.returncode != 0:
            raise RuntimeError(f"mutool failed: {result.stderr[:500]}")

        # mutool names output as expr1.svg
        svg_path = f"{svg_base}1.svg"
        if not os.path.exists(svg_path):
            # Try without the "1" suffix
            svg_path = f"{svg_base}.svg"
        if not os.path.exists(svg_path):
            raise RuntimeError("SVG output not found")

        return _parse_svg_to_strokes(svg_path, scale=scale, offset_x=offset_x, offset_y=offset_y)


def _parse_svg_to_strokes(
    svg_path: str,
    *,
    scale: float = 1.0,
    offset_x: float = 0.0,
    offset_y: float = 0.0,
) -> list[Stroke]:
    """Parse a mutool-generated SVG into stroke coordinate arrays."""
    tree = ET.parse(svg_path)
    root = tree.getroot()
    ns = {'svg': 'http://www.w3.org/2000/svg', 'xlink': 'http://www.w3.org/1999/xlink'}

    # Extract glyph path definitions
    glyph_paths: dict[str, list[tuple[float, float]]] = {}
    for path in root.findall('.//svg:defs/svg:path', ns):
        pid = path.get('id', '')
        d = path.get('d', '')
        if d:
            glyph_paths[pid] = _parse_svg_path(d)

    # Extract <use> elements with transform matrices
    strokes: list[Stroke] = []
    for use in root.findall('.//svg:use', ns):
        href = (
            use.get('{http://www.w3.org/1999/xlink}href', '') or
            use.get('href', '')
        ).lstrip('#')

        if href not in glyph_paths or not glyph_paths[href]:
            continue

        pts = glyph_paths[href]
        transform = use.get('transform', '')

        # Parse matrix(a,b,c,d,e,f)
        m = re.search(r'matrix\(([^)]+)\)', transform)
        if m:
            a, b, c, d, e, f = [float(x) for x in m.group(1).split(',')]
        else:
            a, b, c, d, e, f = 1, 0, 0, 1, 0, 0

        # Apply transform, then scale and offset
        xs: list[float] = []
        ys: list[float] = []
        for px, py in pts:
            tx = (a * px + c * py + e) * scale + offset_x
            ty = (b * px + d * py + f) * scale + offset_y
            xs.append(round(tx, 2))
            ys.append(round(ty, 2))

        if len(xs) >= 2:
            strokes.append({"x": xs, "y": ys})

    # Also handle direct <path> elements outside <defs> (e.g., horizontal rules)
    for path in root.findall('.//svg:path', ns):
        # Skip paths inside <defs>
        if path.get('id', '').startswith('font_'):
            continue
        parent = path
        d = path.get('d', '')
        if not d:
            continue
        pts = _parse_svg_path(d)
        if len(pts) < 2:
            continue

        transform = path.get('transform', '')
        m = re.search(r'matrix\(([^)]+)\)', transform)
        if m:
            a, b, c, d_val, e, f = [float(x) for x in m.group(1).split(',')]
        else:
            a, b, c, d_val, e, f = 1, 0, 0, 1, 0, 0

        xs = [round((a * px + c * py + e) * scale + offset_x, 2) for px, py in pts]
        ys = [round((b * px + d_val * py + f) * scale + offset_y, 2) for px, py in pts]
        if len(xs) >= 2:
            strokes.append({"x": xs, "y": ys})

    return strokes
