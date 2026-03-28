"""Stroke templates for each symbol.

Each template function takes (cx, cy, size) and returns a list of stroke dicts,
where each dict has 'x' and 'y' keys with lists of float coordinates.

Digit 0-9, plus, minus, equals, and x patterns are copied EXACTLY from
stress_test_strokes.py to preserve Mathpix recognition fidelity.
"""
from __future__ import annotations

import math
from typing import Callable


Stroke = dict[str, list[float]]
TemplateFunc = Callable[[float, float, float], list[Stroke]]


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _pts(n: int = 20) -> range:
    return range(n)


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


# ---------------------------------------------------------------------------
# Digits — EXACT copies from stress_test_strokes.py
# (offset_x → cx, offset_y → cy, same math)
# ---------------------------------------------------------------------------

def _digit_0(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = 2 * math.pi * i / (points - 1)
        xs.append(cx + size * 0.4 * math.cos(t))
        ys.append(cy + size * 0.5 * math.sin(t))
    return [{"x": xs, "y": ys}]


def _digit_1(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        xs.append(cx + size * 0.1 * (1 - t))
        ys.append(cy - size * 0.5 + size * t)
    return [{"x": xs, "y": ys}]


def _digit_2(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.4:
            a = math.pi * (1 - t / 0.4)
            xs.append(cx + size * 0.3 * math.cos(a))
            ys.append(cy - size * 0.3 + size * 0.3 * math.sin(a))
        else:
            p = (t - 0.4) / 0.6
            xs.append(cx + size * 0.3 - size * 0.6 * p)
            ys.append(cy + size * 0.2 * p)
    return [{"x": xs, "y": ys}]


def _digit_3(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.5:
            a = math.pi * (1 - 2 * t)
            xs.append(cx + size * 0.25 * math.cos(a))
            ys.append(cy - size * 0.25 + size * 0.2 * math.sin(a))
        else:
            a = math.pi * (1 - 2 * (t - 0.5))
            xs.append(cx + size * 0.25 * math.cos(a))
            ys.append(cy + size * 0.05 + size * 0.2 * math.sin(a))
    return [{"x": xs, "y": ys}]


def _digit_4(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.4:
            p = t / 0.4
            xs.append(cx - size * 0.2 * (1 - p))
            ys.append(cy - size * 0.4 + size * 0.5 * p)
        elif t < 0.6:
            p = (t - 0.4) / 0.2
            xs.append(cx - size * 0.2 + size * 0.5 * p)
            ys.append(cy + size * 0.1)
        else:
            p = (t - 0.6) / 0.4
            xs.append(cx + size * 0.2)
            ys.append(cy - size * 0.4 + size * 0.8 * p)
    return [{"x": xs, "y": ys}]


def _digit_5(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.3:
            p = t / 0.3
            xs.append(cx + size * 0.3 - size * 0.5 * p)
            ys.append(cy - size * 0.4)
        elif t < 0.5:
            p = (t - 0.3) / 0.2
            xs.append(cx - size * 0.2)
            ys.append(cy - size * 0.4 + size * 0.4 * p)
        else:
            a = math.pi * (0.5 + (t - 0.5) / 0.5)
            xs.append(cx + size * 0.2 * math.cos(a))
            ys.append(cy + size * 0.15 + size * 0.2 * math.sin(a))
    return [{"x": xs, "y": ys}]


def _digit_6(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.4:
            p = t / 0.4
            xs.append(cx + size * 0.2 * math.cos(math.pi * 0.5 * (1 - p)))
            ys.append(cy - size * 0.4 + size * 0.5 * p)
        else:
            a = 2 * math.pi * (t - 0.4) / 0.6
            xs.append(cx + size * 0.2 * math.cos(a))
            ys.append(cy + size * 0.15 + size * 0.2 * math.sin(a))
    return [{"x": xs, "y": ys}]


def _digit_7(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.3:
            p = t / 0.3
            xs.append(cx - size * 0.25 + size * 0.5 * p)
            ys.append(cy - size * 0.4)
        else:
            p = (t - 0.3) / 0.7
            xs.append(cx + size * 0.25 - size * 0.3 * p)
            ys.append(cy - size * 0.4 + size * 0.8 * p)
    return [{"x": xs, "y": ys}]


def _digit_8(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = 2 * math.pi * i / (points - 1)
        xs.append(cx + size * 0.2 * math.cos(t))
        ys.append(cy + size * 0.15 * math.sin(2 * t))
    return [{"x": xs, "y": ys}]


def _digit_9(cx: float, cy: float, size: float) -> list[Stroke]:
    points = 30
    xs, ys = [], []
    for i in range(points):
        t = i / (points - 1)
        if t < 0.6:
            a = 2 * math.pi * t / 0.6
            xs.append(cx + size * 0.2 * math.cos(a))
            ys.append(cy - size * 0.15 + size * 0.2 * math.sin(a))
        else:
            p = (t - 0.6) / 0.4
            xs.append(cx + size * 0.2)
            ys.append(cy + size * 0.05 + size * 0.35 * p)
    return [{"x": xs, "y": ys}]


# ---------------------------------------------------------------------------
# Operators — EXACT copies from stress_test_strokes.py
# ---------------------------------------------------------------------------

def _plus(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    h_xs = [cx - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    h_ys = [cy] * pts
    v_xs = [cx] * pts
    v_ys = [cy - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    return [{"x": h_xs, "y": h_ys}, {"x": v_xs, "y": v_ys}]


def _minus(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    xs = [cx - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    ys = [cy] * pts
    return [{"x": xs, "y": ys}]


def _equals(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    gap = size * 0.15
    top_xs = [cx - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    top_ys = [cy - gap] * pts
    bot_xs = list(top_xs)
    bot_ys = [cy + gap] * pts
    return [{"x": top_xs, "y": top_ys}, {"x": bot_xs, "y": bot_ys}]


def _letter_x(cx: float, cy: float, size: float) -> list[Stroke]:
    """Letter x — two crossing strokes (EXACT from stress_test_strokes.py)."""
    pts = 15
    s1_xs = [cx - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.2 - size * 0.4 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


# ---------------------------------------------------------------------------
# Additional operators
# ---------------------------------------------------------------------------

def _multiply(cx: float, cy: float, size: float) -> list[Stroke]:
    """Times / multiplication dot — small cross."""
    pts = 10
    s1_xs = [cx - size * 0.15 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.15 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.15 - size * 0.3 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.15 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _divide(cx: float, cy: float, size: float) -> list[Stroke]:
    """Division sign — horizontal bar with two dots."""
    pts = 10
    bar_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy] * pts
    return [{"x": bar_xs, "y": bar_ys}]


def _period(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 6
    xs = [cx + size * 0.03 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    ys = [cy + size * 0.4 + size * 0.03 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _comma(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 10
    xs = [cx + size * 0.02 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts // 2)]
    ys = [cy + size * 0.4 + size * 0.02 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts // 2)]
    # Tail going down-left
    for i in range(pts // 2):
        t = i / (pts // 2 - 1)
        xs.append(cx - size * 0.05 * t)
        ys.append(cy + size * 0.42 + size * 0.1 * t)
    return [{"x": xs, "y": ys}]


def _prime(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 8
    xs = [cx + size * 0.05 * i / (pts - 1) for i in range(pts)]
    ys = [cy - size * 0.45 + size * 0.15 * i / (pts - 1) for i in range(pts)]
    return [{"x": xs, "y": ys}]


# ---------------------------------------------------------------------------
# Parentheses and brackets
# ---------------------------------------------------------------------------

def _left_paren(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        angle = math.pi * 0.4 + math.pi * 1.2 * t  # arc from top-right to bottom-right
        xs.append(cx + size * 0.15 * math.cos(angle))
        ys.append(cy + size * 0.5 * math.sin(angle))
    return [{"x": xs, "y": ys}]


def _right_paren(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        angle = math.pi * 0.6 - math.pi * 1.2 * t
        xs.append(cx + size * 0.15 * math.cos(angle))
        ys.append(cy + size * 0.5 * math.sin(angle))
    return [{"x": xs, "y": ys}]


def _left_bracket(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    # Top horizontal, vertical, bottom horizontal
    top_xs = [cx - size * 0.05 + size * 0.2 * i / (pts // 3) for i in range(pts // 3)]
    top_ys = [cy - size * 0.5] * (pts // 3)
    vert_xs = [cx - size * 0.05] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    bot_xs = [cx - size * 0.05 + size * 0.2 * i / (pts // 3) for i in range(pts // 3)]
    bot_ys = [cy + size * 0.5] * (pts // 3)
    return [
        {"x": top_xs, "y": top_ys},
        {"x": vert_xs, "y": vert_ys},
        {"x": bot_xs, "y": bot_ys},
    ]


def _right_bracket(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    top_xs = [cx + size * 0.05 - size * 0.2 * i / (pts // 3) for i in range(pts // 3)]
    top_ys = [cy - size * 0.5] * (pts // 3)
    vert_xs = [cx + size * 0.05] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    bot_xs = [cx + size * 0.05 - size * 0.2 * i / (pts // 3) for i in range(pts // 3)]
    bot_ys = [cy + size * 0.5] * (pts // 3)
    return [
        {"x": top_xs, "y": top_ys},
        {"x": vert_xs, "y": vert_ys},
        {"x": bot_xs, "y": bot_ys},
    ]


# ---------------------------------------------------------------------------
# Lowercase letters — simple single/two-stroke approximations
# ---------------------------------------------------------------------------

def _letter_a(cx: float, cy: float, size: float) -> list[Stroke]:
    """a: small circle + right vertical tail."""
    pts = 20
    # Circle (slightly open at right)
    circle_xs = [cx - size * 0.05 + size * 0.2 * math.cos(t)
                 for t in [2 * math.pi * i / (pts - 1) for i in range(pts)]]
    circle_ys = [cy + size * 0.1 + size * 0.2 * math.sin(t)
                 for t in [2 * math.pi * i / (pts - 1) for i in range(pts)]]
    # Tail: right side going down
    tail_xs = [cx + size * 0.15] * 8
    tail_ys = [cy - size * 0.1 + size * 0.4 * i / 7 for i in range(8)]
    return [{"x": circle_xs, "y": circle_ys}, {"x": tail_xs, "y": tail_ys}]


def _letter_b(cx: float, cy: float, size: float) -> list[Stroke]:
    """b: vertical stroke + right bump."""
    pts = 15
    # Vertical line
    vert_xs = [cx - size * 0.1] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    # Bump: arc on right
    bump_xs = [cx - size * 0.1 + size * 0.25 * math.cos(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump_ys = [cy + size * 0.15 + size * 0.2 * math.sin(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump_xs, "y": bump_ys}]


def _letter_c(cx: float, cy: float, size: float) -> list[Stroke]:
    """c: open arc."""
    pts = 20
    xs = [cx + size * 0.2 * math.cos(t)
          for t in [math.pi * 0.2 + math.pi * 1.6 * i / (pts - 1) for i in range(pts)]]
    ys = [cy + size * 0.15 + size * 0.2 * math.sin(t)
          for t in [math.pi * 0.2 + math.pi * 1.6 * i / (pts - 1) for i in range(pts)]]
    return [{"x": xs, "y": ys}]


def _letter_d(cx: float, cy: float, size: float) -> list[Stroke]:
    """d: arc on left + right vertical line going to top."""
    pts = 15
    vert_xs = [cx + size * 0.1] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    bump_xs = [cx + size * 0.1 - size * 0.25 * math.cos(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump_ys = [cy + size * 0.15 + size * 0.2 * math.sin(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump_xs, "y": bump_ys}]


def _letter_e(cx: float, cy: float, size: float) -> list[Stroke]:
    """e: horizontal mid-bar + arc."""
    pts = 15
    # Mid bar
    bar_xs = [cx - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy + size * 0.12] * pts
    # Arc from right of bar going up and around
    arc_xs = [cx + size * 0.2 * math.cos(t)
              for t in [0.0 + math.pi * 1.7 * i / (pts - 1) for i in range(pts)]]
    arc_ys = [cy + size * 0.12 + size * 0.2 * math.sin(t)
              for t in [0.0 + math.pi * 1.7 * i / (pts - 1) for i in range(pts)]]
    return [{"x": bar_xs, "y": bar_ys}, {"x": arc_xs, "y": arc_ys}]


def _letter_f(cx: float, cy: float, size: float) -> list[Stroke]:
    """f: vertical with top hook + crossbar."""
    pts = 15
    # Vertical with top hook
    vert_xs = []
    vert_ys = []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.25:
            a = math.pi * (0.5 + t / 0.25 * 0.5)
            vert_xs.append(cx + size * 0.12 * math.cos(a))
            vert_ys.append(cy - size * 0.38 + size * 0.12 * math.sin(a))
        else:
            vert_xs.append(cx)
            vert_ys.append(cy - size * 0.5 + size * t)
    # Crossbar
    bar_xs = [cx - size * 0.15 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy - size * 0.1] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_g(cx: float, cy: float, size: float) -> list[Stroke]:
    """g: circle + descender."""
    pts = 20
    circle_xs = [cx + size * 0.2 * math.cos(t)
                 for t in [math.pi * 0.1 + math.pi * 1.8 * i / (pts - 1) for i in range(pts)]]
    circle_ys = [cy + size * 0.12 + size * 0.2 * math.sin(t)
                 for t in [math.pi * 0.1 + math.pi * 1.8 * i / (pts - 1) for i in range(pts)]]
    # Descender
    desc_xs = [cx + size * 0.2] * 10
    desc_ys = [cy + size * 0.12 + size * 0.3 * i / 9 for i in range(10)]
    desc_xs2 = [cx + size * 0.2 - size * 0.3 * i / 9 for i in range(10)]
    desc_ys2 = [cy + size * 0.42] * 10
    return [{"x": circle_xs, "y": circle_ys}, {"x": desc_xs + desc_xs2, "y": desc_ys + desc_ys2}]


def _letter_h(cx: float, cy: float, size: float) -> list[Stroke]:
    """h: vertical + arch + leg."""
    pts = 15
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    # Arch and right leg
    arch_xs, arch_ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.4:
            a = math.pi - math.pi * t / 0.4
            arch_xs.append(cx - size * 0.15 + size * 0.15 * (1 - math.cos(a)))
            arch_ys.append(cy - size * 0.1 * math.sin(a))
        else:
            arch_xs.append(cx + size * 0.15)
            arch_ys.append(cy + size * 0.4 * (t - 0.4) / 0.6)
    return [{"x": vert_xs, "y": vert_ys}, {"x": arch_xs, "y": arch_ys}]


def _letter_i(cx: float, cy: float, size: float) -> list[Stroke]:
    """i: vertical stroke + dot."""
    pts = 12
    vert_xs = [cx] * pts
    vert_ys = [cy - size * 0.15 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    dot_xs = [cx + size * 0.02 * math.cos(2 * math.pi * j / 5) for j in range(6)]
    dot_ys = [cy - size * 0.35 + size * 0.02 * math.sin(2 * math.pi * j / 5) for j in range(6)]
    return [{"x": vert_xs, "y": vert_ys}, {"x": dot_xs, "y": dot_ys}]


def _letter_j(cx: float, cy: float, size: float) -> list[Stroke]:
    """j: vertical with bottom hook + dot."""
    pts = 15
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.8:
            xs.append(cx + size * 0.05)
            ys.append(cy - size * 0.2 + size * 0.6 * t / 0.8)
        else:
            a = math.pi * (t - 0.8) / 0.2
            xs.append(cx + size * 0.05 - size * 0.12 * math.sin(a))
            ys.append(cy + size * 0.4 + size * 0.1 * (1 - math.cos(a)))
    dot_xs = [cx + size * 0.02 * math.cos(2 * math.pi * j / 5) for j in range(6)]
    dot_ys = [cy - size * 0.35 + size * 0.02 * math.sin(2 * math.pi * j / 5) for j in range(6)]
    return [{"x": xs, "y": ys}, {"x": dot_xs, "y": dot_ys}]


def _letter_k(cx: float, cy: float, size: float) -> list[Stroke]:
    """k: vertical + two diagonal strokes."""
    pts = 12
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    upper_xs = [cx + size * 0.15 - size * 0.3 * i / (pts - 1) for i in range(pts)]
    upper_ys = [cy - size * 0.35 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    lower_xs = [cx - size * 0.0 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    lower_ys = [cy + size * 0.35 * i / (pts - 1) for i in range(pts)]
    return [{"x": vert_xs, "y": vert_ys}, {"x": upper_xs, "y": upper_ys}, {"x": lower_xs, "y": lower_ys}]


def _letter_l(cx: float, cy: float, size: float) -> list[Stroke]:
    """l: simple vertical stroke."""
    pts = 15
    xs = [cx] * pts
    ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_m(cx: float, cy: float, size: float) -> list[Stroke]:
    """m: three humps."""
    pts = 25
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        xs.append(cx - size * 0.3 + size * 0.6 * t)
        ys.append(cy + size * 0.15 + size * 0.25 * abs(math.sin(math.pi * 2 * t)))
    # Start from top
    xs2 = [cx - size * 0.3] + xs
    ys2 = [cy - size * 0.15] + ys
    return [{"x": xs2, "y": ys2}]


def _letter_n(cx: float, cy: float, size: float) -> list[Stroke]:
    """n: two verticals with arch."""
    pts = 15
    left_xs = [cx - size * 0.15] * pts
    left_ys = [cy - size * 0.15 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    arch_xs, arch_ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.4:
            a = math.pi - math.pi * t / 0.4
            arch_xs.append(cx - size * 0.15 + size * 0.15 * (1 - math.cos(a)))
            arch_ys.append(cy - size * 0.15 - size * 0.1 * math.sin(a))
        else:
            arch_xs.append(cx + size * 0.15)
            arch_ys.append(cy - size * 0.15 + size * 0.5 * (t - 0.4) / 0.6)
    return [{"x": left_xs, "y": left_ys}, {"x": arch_xs, "y": arch_ys}]


def _letter_o(cx: float, cy: float, size: float) -> list[Stroke]:
    """o: closed oval."""
    pts = 25
    xs = [cx + size * 0.22 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    ys = [cy + size * 0.15 + size * 0.22 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_p(cx: float, cy: float, size: float) -> list[Stroke]:
    """p: vertical with descender + right bump."""
    pts = 15
    vert_xs = [cx - size * 0.1] * pts
    vert_ys = [cy - size * 0.15 + size * 0.7 * i / (pts - 1) for i in range(pts)]
    bump_xs = [cx - size * 0.1 + size * 0.25 * math.cos(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump_ys = [cy + size * 0.1 + size * 0.2 * math.sin(t)
               for t in [math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump_xs, "y": bump_ys}]


def _letter_q(cx: float, cy: float, size: float) -> list[Stroke]:
    """q: circle + right vertical with descender."""
    pts = 20
    circle_xs = [cx + size * 0.22 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    circle_ys = [cy + size * 0.12 + size * 0.22 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    tail_xs = [cx + size * 0.15] * 12
    tail_ys = [cy - size * 0.1 + size * 0.6 * i / 11 for i in range(12)]
    return [{"x": circle_xs, "y": circle_ys}, {"x": tail_xs, "y": tail_ys}]


def _letter_r(cx: float, cy: float, size: float) -> list[Stroke]:
    """r: vertical + short shoulder."""
    pts = 12
    vert_xs = [cx - size * 0.1] * pts
    vert_ys = [cy - size * 0.15 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    shoulder_xs, shoulder_ys = [], []
    for i in range(pts // 2):
        t = i / (pts // 2 - 1)
        a = math.pi - math.pi * 0.5 * t
        shoulder_xs.append(cx - size * 0.1 + size * 0.15 * (1 - math.cos(a)))
        shoulder_ys.append(cy - size * 0.15 - size * 0.1 * math.sin(a))
    return [{"x": vert_xs, "y": vert_ys}, {"x": shoulder_xs, "y": shoulder_ys}]


def _letter_s(cx: float, cy: float, size: float) -> list[Stroke]:
    """s: S-curve."""
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        xs.append(cx + size * 0.18 * math.sin(math.pi * (t + 0.5)))
        ys.append(cy - size * 0.25 + size * 0.5 * t)
    return [{"x": xs, "y": ys}]


def _letter_t(cx: float, cy: float, size: float) -> list[Stroke]:
    """t: vertical + crossbar."""
    pts = 15
    vert_xs = [cx] * pts
    vert_ys = [cy - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    bar_xs = [cx - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy - size * 0.1] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_u(cx: float, cy: float, size: float) -> list[Stroke]:
    """u: U-shape."""
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.3:
            xs.append(cx - size * 0.15)
            ys.append(cy - size * 0.15 + size * 0.35 * t / 0.3)
        elif t < 0.7:
            a = math.pi + math.pi * (t - 0.3) / 0.4
            xs.append(cx + size * 0.15 * math.cos(a))
            ys.append(cy + size * 0.2 + size * 0.15 * math.sin(a))
        else:
            xs.append(cx + size * 0.15)
            ys.append(cy + size * 0.2 - size * 0.35 * (t - 0.7) / 0.3)
    return [{"x": xs, "y": ys}]


def _letter_v(cx: float, cy: float, size: float) -> list[Stroke]:
    """v: V-shape."""
    pts = 15
    s1_xs = [cx - size * 0.2 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.2 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy + size * 0.25 - size * 0.5 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _letter_w(cx: float, cy: float, size: float) -> list[Stroke]:
    """w: W-shape."""
    pts = 20
    xs = [cx - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    ys = [cy - size * 0.2 + size * 0.45 * abs(math.sin(math.pi * 1.5 * i / (pts - 1))) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_y(cx: float, cy: float, size: float) -> list[Stroke]:
    """y: two diagonals meeting + descender."""
    pts = 12
    s1_xs = [cx - size * 0.2 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.25 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.2 - size * 0.4 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.25 + size * 0.65 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _letter_z(cx: float, cy: float, size: float) -> list[Stroke]:
    """z: Z-shape."""
    pts = 15
    top_xs = [cx - size * 0.2 + size * 0.4 * i / (pts // 3) for i in range(pts // 3)]
    top_ys = [cy - size * 0.25] * (pts // 3)
    diag_xs = [cx + size * 0.2 - size * 0.4 * i / (pts // 3) for i in range(pts // 3)]
    diag_ys = [cy - size * 0.25 + size * 0.5 * i / (pts // 3) for i in range(pts // 3)]
    bot_xs = [cx - size * 0.2 + size * 0.4 * i / (pts // 3) for i in range(pts // 3)]
    bot_ys = [cy + size * 0.25] * (pts // 3)
    return [{"x": top_xs, "y": top_ys}, {"x": diag_xs, "y": diag_ys}, {"x": bot_xs, "y": bot_ys}]


# ---------------------------------------------------------------------------
# Uppercase letters — scaled/simplified versions of lowercase
# ---------------------------------------------------------------------------

def _letter_A(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    left_xs = [cx - size * 0.2 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    left_ys = [cy + size * 0.4 - size * 0.8 * i / (pts - 1) for i in range(pts)]
    right_xs = [cx + size * 0.2 * i / (pts - 1) for i in range(pts)]
    right_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bar_xs = [cx - size * 0.1 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy + size * 0.05] * pts
    return [{"x": left_xs, "y": left_ys}, {"x": right_xs, "y": right_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_B(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    # Upper bump
    upper_xs = [cx - size * 0.15 + size * 0.2 * math.cos(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    upper_ys = [cy - size * 0.2 + size * 0.2 * math.sin(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    # Lower bump
    lower_xs = [cx - size * 0.15 + size * 0.25 * math.cos(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    lower_ys = [cy + size * 0.2 + size * 0.2 * math.sin(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": upper_xs, "y": upper_ys}, {"x": lower_xs, "y": lower_ys}]


def _letter_C(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    xs = [cx + size * 0.25 * math.cos(t)
          for t in [math.pi * 0.15 + math.pi * 1.7 * i / (pts - 1) for i in range(pts)]]
    ys = [cy + size * 0.25 * math.sin(t)
          for t in [math.pi * 0.15 + math.pi * 1.7 * i / (pts - 1) for i in range(pts)]]
    return [{"x": xs, "y": ys}]


def _letter_D(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    vert_xs = [cx - size * 0.15] * (pts // 3)
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts // 3 - 1) for i in range(pts // 3)]
    arc_xs = [cx - size * 0.15 + size * 0.3 * math.cos(t)
              for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    arc_ys = [cy + size * 0.3 * math.sin(t)
              for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": arc_xs, "y": arc_ys}]


def _letter_E(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 10
    vert_xs = [cx - size * 0.2] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    top_xs = [cx - size * 0.2 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    top_ys = [cy - size * 0.4] * pts
    mid_xs = [cx - size * 0.2 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    mid_ys = [cy] * pts
    bot_xs = [cx - size * 0.2 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    bot_ys = [cy + size * 0.4] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": top_xs, "y": top_ys},
            {"x": mid_xs, "y": mid_ys}, {"x": bot_xs, "y": bot_ys}]


def _letter_F(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 10
    vert_xs = [cx - size * 0.2] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    top_xs = [cx - size * 0.2 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    top_ys = [cy - size * 0.4] * pts
    mid_xs = [cx - size * 0.2 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    mid_ys = [cy] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": top_xs, "y": top_ys}, {"x": mid_xs, "y": mid_ys}]


def _letter_G(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    arc_xs = [cx + size * 0.25 * math.cos(t)
              for t in [math.pi * 0.1 + math.pi * 1.5 * i / (pts - 1) for i in range(pts)]]
    arc_ys = [cy + size * 0.25 * math.sin(t)
              for t in [math.pi * 0.1 + math.pi * 1.5 * i / (pts - 1) for i in range(pts)]]
    # Horizontal bar at mid-right
    bar_xs = [cx + size * 0.25 - size * 0.25 * i / (pts // 3 - 1) for i in range(pts // 3)]
    bar_ys = [cy] * (pts // 3)
    return [{"x": arc_xs, "y": arc_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_H(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    left_xs = [cx - size * 0.2] * pts
    left_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    right_xs = [cx + size * 0.2] * pts
    right_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bar_xs = [cx - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy] * pts
    return [{"x": left_xs, "y": left_ys}, {"x": right_xs, "y": right_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_I(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    xs = [cx] * pts
    ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_J(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.8:
            xs.append(cx + size * 0.1)
            ys.append(cy - size * 0.4 + size * 0.6 * t / 0.8)
        else:
            a = math.pi * (t - 0.8) / 0.2
            xs.append(cx + size * 0.1 - size * 0.15 * math.sin(a))
            ys.append(cy + size * 0.2 + size * 0.15 * (1 - math.cos(a)))
    return [{"x": xs, "y": ys}]


def _letter_K(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    vert_xs = [cx - size * 0.2] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    upper_xs = [cx + size * 0.2 - size * 0.4 * i / (pts - 1) for i in range(pts)]
    upper_ys = [cy - size * 0.4 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    lower_xs = [cx - size * 0.0 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    lower_ys = [cy + size * 0.4 * i / (pts - 1) for i in range(pts)]
    return [{"x": vert_xs, "y": vert_ys}, {"x": upper_xs, "y": upper_ys}, {"x": lower_xs, "y": lower_ys}]


def _letter_L(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bot_xs = [cx - size * 0.15 + size * 0.35 * i / (pts - 1) for i in range(pts)]
    bot_ys = [cy + size * 0.4] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": bot_xs, "y": bot_ys}]


def _letter_M(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    p1_xs = [cx - size * 0.3] * pts
    p1_ys = [cy + size * 0.4 - size * 0.8 * i / (pts - 1) for i in range(pts)]
    p2_xs = [cx - size * 0.3 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    p2_ys = [cy - size * 0.4 + size * 0.3 * i / (pts - 1) for i in range(pts)]
    p3_xs = [cx + size * 0.3 * i / (pts - 1) for i in range(pts)]
    p3_ys = [cy - size * 0.1 - size * 0.3 * i / (pts - 1) for i in range(pts)]
    p4_xs = [cx + size * 0.3] * pts
    p4_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": p1_xs, "y": p1_ys}, {"x": p2_xs, "y": p2_ys},
            {"x": p3_xs, "y": p3_ys}, {"x": p4_xs, "y": p4_ys}]


def _letter_N(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    left_xs = [cx - size * 0.2] * pts
    left_ys = [cy + size * 0.4 - size * 0.8 * i / (pts - 1) for i in range(pts)]
    diag_xs = [cx - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    diag_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    right_xs = [cx + size * 0.2] * pts
    right_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": left_xs, "y": left_ys}, {"x": diag_xs, "y": diag_ys}, {"x": right_xs, "y": right_ys}]


def _letter_O(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 25
    xs = [cx + size * 0.27 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    ys = [cy + size * 0.27 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_P(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bump_xs = [cx - size * 0.15 + size * 0.22 * math.cos(t)
               for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump_ys = [cy - size * 0.2 + size * 0.2 * math.sin(t)
               for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump_xs, "y": bump_ys}]


def _letter_Q(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 25
    circle_xs = [cx + size * 0.27 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    circle_ys = [cy + size * 0.27 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    tail_xs = [cx + size * 0.1 + size * 0.15 * i / 8 for i in range(9)]
    tail_ys = [cy + size * 0.1 + size * 0.25 * i / 8 for i in range(9)]
    return [{"x": circle_xs, "y": circle_ys}, {"x": tail_xs, "y": tail_ys}]


def _letter_R(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    vert_xs = [cx - size * 0.15] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bump_xs = [cx - size * 0.15 + size * 0.22 * math.cos(t)
               for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump_ys = [cy - size * 0.2 + size * 0.2 * math.sin(t)
               for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    leg_xs = [cx + size * 0.07 + size * 0.15 * i / (pts - 1) for i in range(pts)]
    leg_ys = [cy - size * 0.0 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump_xs, "y": bump_ys}, {"x": leg_xs, "y": leg_ys}]


def _letter_S(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 25
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        xs.append(cx + size * 0.22 * math.sin(math.pi * (t + 0.5)))
        ys.append(cy - size * 0.4 + size * 0.8 * t)
    return [{"x": xs, "y": ys}]


def _letter_T(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    vert_xs = [cx] * pts
    vert_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bar_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy - size * 0.4] * pts
    return [{"x": vert_xs, "y": vert_ys}, {"x": bar_xs, "y": bar_ys}]


def _letter_U(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.3:
            xs.append(cx - size * 0.2)
            ys.append(cy - size * 0.4 + size * 0.5 * t / 0.3)
        elif t < 0.7:
            a = math.pi + math.pi * (t - 0.3) / 0.4
            xs.append(cx + size * 0.2 * math.cos(a))
            ys.append(cy + size * 0.1 + size * 0.2 * math.sin(a))
        else:
            xs.append(cx + size * 0.2)
            ys.append(cy + size * 0.1 - size * 0.5 * (t - 0.7) / 0.3)
    return [{"x": xs, "y": ys}]


def _letter_V(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    s1_xs = [cx - size * 0.25 + size * 0.25 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.25 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy + size * 0.4 - size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _letter_W(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 20
    xs = [cx - size * 0.35 + size * 0.7 * i / (pts - 1) for i in range(pts)]
    ys = [cy - size * 0.4 + size * 0.8 * abs(math.sin(math.pi * 1.5 * i / (pts - 1))) for i in range(pts)]
    return [{"x": xs, "y": ys}]


def _letter_X(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 15
    s1_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.25 - size * 0.5 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _letter_Y(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    s1_xs = [cx - size * 0.25 + size * 0.25 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy - size * 0.4 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.25 - size * 0.25 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.4 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    stem_xs = [cx] * pts
    stem_ys = [cy + size * 0.4 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}, {"x": stem_xs, "y": stem_ys}]


def _letter_Z(cx: float, cy: float, size: float) -> list[Stroke]:
    pts = 12
    top_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    top_ys = [cy - size * 0.4] * pts
    diag_xs = [cx + size * 0.25 - size * 0.5 * i / (pts - 1) for i in range(pts)]
    diag_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    bot_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    bot_ys = [cy + size * 0.4] * pts
    return [{"x": top_xs, "y": top_ys}, {"x": diag_xs, "y": diag_ys}, {"x": bot_xs, "y": bot_ys}]


# ---------------------------------------------------------------------------
# Greek letters
# ---------------------------------------------------------------------------

def _alpha(cx: float, cy: float, size: float) -> list[Stroke]:
    """α: two loops."""
    pts = 20
    # Left loop
    loop1_xs = [cx - size * 0.05 + size * 0.15 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    loop1_ys = [cy + size * 0.1 + size * 0.18 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    # Right loop + tail
    loop2_xs, loop2_ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.7:
            a = math.pi * 0.2 + math.pi * 2 * t / 0.7
            loop2_xs.append(cx + size * 0.1 + size * 0.15 * math.cos(a))
            loop2_ys.append(cy + size * 0.1 + size * 0.18 * math.sin(a))
        else:
            loop2_xs.append(cx + size * 0.25)
            loop2_ys.append(cy - size * 0.08 + size * 0.4 * (t - 0.7) / 0.3)
    return [{"x": loop1_xs, "y": loop1_ys}, {"x": loop2_xs, "y": loop2_ys}]


def _beta(cx: float, cy: float, size: float) -> list[Stroke]:
    """β: vertical with two bumps."""
    pts = 20
    vert_xs = [cx - size * 0.1] * (pts // 3)
    vert_ys = [cy - size * 0.5 + size * 0.6 * i / (pts // 3 - 1) for i in range(pts // 3)]
    bump1_xs = [cx - size * 0.1 + size * 0.2 * math.cos(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump1_ys = [cy - size * 0.25 + size * 0.2 * math.sin(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump2_xs = [cx - size * 0.1 + size * 0.22 * math.cos(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    bump2_ys = [cy + size * 0.15 + size * 0.2 * math.sin(t)
                for t in [-math.pi / 2 + math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": vert_xs, "y": vert_ys}, {"x": bump1_xs, "y": bump1_ys}, {"x": bump2_xs, "y": bump2_ys}]


def _theta(cx: float, cy: float, size: float) -> list[Stroke]:
    """θ: circle with horizontal bar."""
    pts = 25
    circle_xs = [cx + size * 0.22 * math.cos(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    circle_ys = [cy + size * 0.22 * math.sin(2 * math.pi * i / (pts - 1)) for i in range(pts)]
    bar_xs = [cx - size * 0.2 + size * 0.4 * i / (pts // 3 - 1) for i in range(pts // 3)]
    bar_ys = [cy] * (pts // 3)
    return [{"x": circle_xs, "y": circle_ys}, {"x": bar_xs, "y": bar_ys}]


def _pi(cx: float, cy: float, size: float) -> list[Stroke]:
    """π: horizontal top bar + two legs."""
    pts = 12
    bar_xs = [cx - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    bar_ys = [cy - size * 0.2] * pts
    left_xs = [cx - size * 0.15] * pts
    left_ys = [cy - size * 0.2 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    right_xs, right_ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.7:
            right_xs.append(cx + size * 0.15)
            right_ys.append(cy - size * 0.2 + size * 0.4 * t / 0.7)
        else:
            right_xs.append(cx + size * 0.15 - size * 0.08 * (t - 0.7) / 0.3)
            right_ys.append(cy + size * 0.2)
    return [{"x": bar_xs, "y": bar_ys}, {"x": left_xs, "y": left_ys}, {"x": right_xs, "y": right_ys}]


def _sigma(cx: float, cy: float, size: float) -> list[Stroke]:
    """σ: sigma shape."""
    pts = 20
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.15:
            xs.append(cx + size * 0.2 - size * 0.4 * t / 0.15)
            ys.append(cy - size * 0.25)
        elif t < 0.5:
            a = math.pi * 0.8 + math.pi * 1.4 * (t - 0.15) / 0.35
            xs.append(cx + size * 0.2 * math.cos(a))
            ys.append(cy + size * 0.12 + size * 0.2 * math.sin(a))
        else:
            xs.append(cx - size * 0.2 + size * 0.4 * (t - 0.5) / 0.5)
            ys.append(cy + size * 0.12 + size * 0.15)
    return [{"x": xs, "y": ys}]


def _lambda_(cx: float, cy: float, size: float) -> list[Stroke]:
    """λ: inverted V with right tail."""
    pts = 12
    s1_xs = [cx - size * 0.2 + size * 0.2 * i / (pts - 1) for i in range(pts)]
    s1_ys = [cy + size * 0.4 - size * 0.8 * i / (pts - 1) for i in range(pts)]
    s2_xs = [cx + size * 0.25 * i / (pts - 1) for i in range(pts)]
    s2_ys = [cy - size * 0.4 + size * 0.8 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _mu(cx: float, cy: float, size: float) -> list[Stroke]:
    """μ: like u with descender on left."""
    pts = 18
    xs, ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.15:
            xs.append(cx - size * 0.15)
            ys.append(cy + size * 0.35 + size * 0.15 * t / 0.15)
        elif t < 0.45:
            xs.append(cx - size * 0.15)
            ys.append(cy - size * 0.2 + size * 0.35 * (t - 0.15) / 0.3)
        elif t < 0.75:
            a = math.pi + math.pi * (t - 0.45) / 0.3
            xs.append(cx + size * 0.15 * math.cos(a))
            ys.append(cy + size * 0.15 + size * 0.15 * math.sin(a))
        else:
            xs.append(cx + size * 0.15)
            ys.append(cy + size * 0.15 - size * 0.35 * (t - 0.75) / 0.25)
    return [{"x": xs, "y": ys}]


def _infinity(cx: float, cy: float, size: float) -> list[Stroke]:
    """∞: lemniscate (figure-8 on its side)."""
    pts = 30
    xs = [cx + size * 0.35 * math.cos(t) / (1 + math.sin(t) ** 2)
          for t in [2 * math.pi * i / (pts - 1) for i in range(pts)]]
    ys = [cy + size * 0.2 * math.sin(t) * math.cos(t) / (1 + math.sin(t) ** 2)
          for t in [2 * math.pi * i / (pts - 1) for i in range(pts)]]
    return [{"x": xs, "y": ys}]


# ---------------------------------------------------------------------------
# Special math structures
# ---------------------------------------------------------------------------

def _fraction_bar(cx: float, cy: float, size: float) -> list[Stroke]:
    """Horizontal fraction bar."""
    pts = 15
    xs = [cx - size * 0.5 + size * i / (pts - 1) for i in range(pts)]
    ys = [cy] * pts
    return [{"x": xs, "y": ys}]


def _sqrt_radical(cx: float, cy: float, size: float) -> list[Stroke]:
    """√ radical: small tick + horizontal bar."""
    pts = 15
    # Tick: short diagonal going down then up
    tick_xs, tick_ys = [], []
    for i in range(pts):
        t = i / (pts - 1)
        if t < 0.25:
            tick_xs.append(cx - size * 0.3 + size * 0.08 * t / 0.25)
            tick_ys.append(cy + size * 0.1 * t / 0.25)
        elif t < 0.5:
            p = (t - 0.25) / 0.25
            tick_xs.append(cx - size * 0.22 + size * 0.1 * p)
            tick_ys.append(cy + size * 0.1 - size * 0.4 * p)
        else:
            p = (t - 0.5) / 0.5
            tick_xs.append(cx - size * 0.12 + size * 0.62 * p)
            tick_ys.append(cy - size * 0.3)
    return [{"x": tick_xs, "y": tick_ys}]


# ---------------------------------------------------------------------------
# Template registry
# ---------------------------------------------------------------------------

TEMPLATES: dict[str, TemplateFunc] = {
    # Digits
    "0": _digit_0, "1": _digit_1, "2": _digit_2,
    "3": _digit_3, "4": _digit_4, "5": _digit_5,
    "6": _digit_6, "7": _digit_7, "8": _digit_8, "9": _digit_9,
    # Operators
    "+": _plus, "-": _minus, "=": _equals,
    "×": _multiply, "·": _multiply, "÷": _divide,
    # Punctuation
    ".": _period, ",": _comma, "'": _prime, "′": _prime,
    # Lowercase letters
    "a": _letter_a, "b": _letter_b, "c": _letter_c,
    "d": _letter_d, "e": _letter_e, "f": _letter_f,
    "g": _letter_g, "h": _letter_h, "i": _letter_i,
    "j": _letter_j, "k": _letter_k, "l": _letter_l,
    "m": _letter_m, "n": _letter_n, "o": _letter_o,
    "p": _letter_p, "q": _letter_q, "r": _letter_r,
    "s": _letter_s, "t": _letter_t, "u": _letter_u,
    "v": _letter_v, "w": _letter_w, "x": _letter_x,
    "y": _letter_y, "z": _letter_z,
    # Uppercase letters
    "A": _letter_A, "B": _letter_B, "C": _letter_C,
    "D": _letter_D, "E": _letter_E, "F": _letter_F,
    "G": _letter_G, "H": _letter_H, "I": _letter_I,
    "J": _letter_J, "K": _letter_K, "L": _letter_L,
    "M": _letter_M, "N": _letter_N, "O": _letter_O,
    "P": _letter_P, "Q": _letter_Q, "R": _letter_R,
    "S": _letter_S, "T": _letter_T, "U": _letter_U,
    "V": _letter_V, "W": _letter_W, "X": _letter_X,
    "Y": _letter_Y, "Z": _letter_Z,
    # Parens and brackets
    "(": _left_paren, ")": _right_paren,
    "[": _left_bracket, "]": _right_bracket,
    # Greek
    "α": _alpha, "β": _beta, "θ": _theta, "π": _pi,
    "σ": _sigma, "λ": _lambda_, "μ": _mu, "∞": _infinity,
    # Special math structures
    "_frac_bar": _fraction_bar,
    "_sqrt": _sqrt_radical,
}


def get_strokes(symbol: str, cx: float, cy: float, size: float) -> list[Stroke]:
    """Return stroke data for symbol at (cx, cy) with given size.

    Falls back to rendering the symbol as individual characters if not found,
    or returns an empty list for unrenderable symbols.
    """
    fn = TEMPLATES.get(symbol)
    if fn is not None:
        return fn(cx, cy, size)
    # Unknown symbol — attempt letter-by-letter fallback
    strokes: list[Stroke] = []
    char_width = size * 0.6
    offset = 0.0
    for ch in symbol:
        fn = TEMPLATES.get(ch)
        if fn is not None:
            strokes.extend(fn(cx + offset, cy, size))
            offset += char_width
    return strokes
