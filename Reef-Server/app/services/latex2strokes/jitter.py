"""Handwriting naturalization — add realistic imperfections to stroke data."""
from __future__ import annotations

import math
import random


Stroke = dict[str, list[float]]


def _moving_average(values: list[float], window: int = 3) -> list[float]:
    """Smooth a list of values with a simple moving average."""
    if len(values) < window:
        return list(values)
    result: list[float] = []
    half = window // 2
    for i in range(len(values)):
        lo = max(0, i - half)
        hi = min(len(values), i + half + 1)
        result.append(sum(values[lo:hi]) / (hi - lo))
    return result


def _gaussian_noise(n: int, stddev: float, rng: random.Random) -> list[float]:
    """Generate n Gaussian noise values, spatially correlated via smoothing."""
    raw = [rng.gauss(0.0, stddev) for _ in range(n)]
    return _moving_average(raw, window=3)


def _rotate_points(
    xs: list[float],
    ys: list[float],
    cx: float,
    cy: float,
    angle_rad: float,
) -> tuple[list[float], list[float]]:
    """Rotate a stroke around (cx, cy) by angle_rad."""
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    new_xs: list[float] = []
    new_ys: list[float] = []
    for x, y in zip(xs, ys):
        dx = x - cx
        dy = y - cy
        new_xs.append(cx + dx * cos_a - dy * sin_a)
        new_ys.append(cy + dx * sin_a + dy * cos_a)
    return new_xs, new_ys


def naturalize(
    strokes: list[Stroke],
    *,
    seed: int | None = None,
) -> list[Stroke]:
    """Add handwriting imperfections to stroke data.

    Applies:
    - Spatially-correlated Gaussian noise (stddev=0.5)
    - Slight per-stroke rotation (±2 degrees)
    - Gentle baseline sine-wave drift across the full expression
    """
    if not strokes:
        return strokes

    rng = random.Random(seed)

    # Compute total x-extent for baseline drift period
    all_x: list[float] = [x for s in strokes for x in s["x"]]
    x_min = min(all_x) if all_x else 0.0
    x_max = max(all_x) if all_x else 1.0
    x_range = max(x_max - x_min, 1.0)

    result: list[Stroke] = []
    for stroke in strokes:
        xs = list(stroke["x"])
        ys = list(stroke["y"])
        n = len(xs)
        if n == 0:
            result.append(stroke)
            continue

        # --- Gaussian noise ---
        noise_x = _gaussian_noise(n, stddev=0.5, rng=rng)
        noise_y = _gaussian_noise(n, stddev=0.5, rng=rng)

        xs = [x + nx for x, nx in zip(xs, noise_x)]
        ys = [y + ny for y, ny in zip(ys, noise_y)]

        # --- Baseline drift (sine wave) ---
        drift_amplitude = 1.0
        drift_period = x_range
        drifted_ys: list[float] = []
        for x, y in zip(xs, ys):
            phase = (x - x_min) / drift_period * 2 * math.pi
            drift = drift_amplitude * math.sin(phase)
            drifted_ys.append(y + drift)
        ys = drifted_ys

        # --- Per-stroke rotation ±2° ---
        max_angle = math.radians(2.0)
        angle = rng.uniform(-max_angle, max_angle)
        cx = sum(xs) / n
        cy = sum(ys) / n
        xs, ys = _rotate_points(xs, ys, cx, cy, angle)

        result.append({"x": xs, "y": ys})

    return result
