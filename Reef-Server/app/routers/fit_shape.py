"""Shape fitting endpoint — uses RDP simplification + circle-fit for geometric shape detection."""

import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
import numpy as np
from rdp import rdp
from circle_fit import taubinSVD

from app.auth import AuthenticatedUser, get_current_user

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class FitShapeRequest(BaseModel):
    points: list[list[float]] = Field(..., max_length=5000)
    closed: bool = False


class FitShapeResponse(BaseModel):
    shape: str
    confidence: float
    geometry: dict


@router.post("/fit-shape", response_model=FitShapeResponse)
async def fit_shape(req: FitShapeRequest, user: AuthenticatedUser = Depends(get_current_user)) -> FitShapeResponse:
    pts = req.points
    if len(pts) < 3:
        return FitShapeResponse(shape="none", confidence=0, geometry={})
    points = np.array(pts, dtype=np.float64)
    return FitShapeResponse(**detect_shape(points))


# ─── Detection Engine ─────────────────────────────────────────────────


def detect_shape(points: np.ndarray) -> dict:
    """Given Nx2 array of (x,y) points, return shape classification + clean geometry."""
    if len(points) < 3:
        return {"shape": "none", "confidence": 0, "geometry": {}}

    perimeter = float(np.sum(np.linalg.norm(np.diff(points, axis=0), axis=1)))
    if perimeter < 10:
        return {"shape": "none", "confidence": 0, "geometry": {}}

    # Closure check
    close_dist = float(np.linalg.norm(points[0] - points[-1]))
    is_closed = close_dist < perimeter * 0.15

    # ── Open stroke: try line ──
    if not is_closed:
        result = _try_line(points, perimeter)
        if result:
            return result
        return {"shape": "none", "confidence": 0, "geometry": {}}

    # ── Closed stroke: check circularity first with tight threshold ──
    if len(points) >= 5:
        circle_result = _try_circle(points, threshold=0.08)
        if circle_result:
            return circle_result

    # ── RDP simplification to count vertices ──
    bbox_diag = _bbox_diagonal(points)

    for eps_frac in [0.04, 0.06, 0.08, 0.10, 0.12]:
        eps = bbox_diag * eps_frac
        simplified = rdp(points, epsilon=eps)
        n = len(simplified)

        # 4 points = 3 vertices + close → triangle
        if n == 4:
            tri = _try_triangle(simplified[:3])
            if tri:
                return tri

        # 5 points = 4 vertices + close → rectangle
        if n == 5:
            rect = _try_rectangle(simplified[:4])
            if rect:
                return rect

        # 4 points could be a rectangle with one merged corner
        if n == 4:
            rect = _try_rectangle_from_bbox(points)
            if rect:
                return rect

    # ── Fallback: looser circle check ──
    if len(points) >= 5:
        circle_result = _try_circle(points, threshold=0.15)
        if circle_result:
            return circle_result

    return {"shape": "none", "confidence": 0, "geometry": {}}


def _try_line(points: np.ndarray, perimeter: float) -> dict | None:
    start, end = points[0], points[-1]
    line_len = float(np.linalg.norm(end - start))
    if line_len < 10:
        return None
    if perimeter / line_len > 1.3:
        return None

    d = end - start
    n = np.array([-d[1], d[0]]) / line_len
    deviations = np.abs((points - start) @ n)
    max_dev = float(np.max(deviations))
    if max_dev / line_len > 0.10:
        return None

    confidence = 1.0 - (max_dev / line_len)
    return {
        "shape": "line",
        "confidence": float(min(confidence, 1.0)),
        "geometry": {"start": start.tolist(), "end": end.tolist()},
    }


def _try_circle(points: np.ndarray, threshold: float = 0.15) -> dict | None:
    try:
        xc, yc, r, sigma = taubinSVD(points)
    except Exception:
        return None

    if r < 5:
        return None

    distances = np.linalg.norm(points - np.array([xc, yc]), axis=1)
    residuals = np.abs(distances - r)
    cv = float(np.mean(residuals) / r)
    if cv > threshold:
        return None

    # RDP check: circles stay complex after simplification, polygons don't
    bbox_diag = _bbox_diagonal(points)
    simplified = rdp(points, epsilon=bbox_diag * 0.06)
    if len(simplified) <= 6:
        return None

    xs, ys = points[:, 0], points[:, 1]
    rx = float((np.max(xs) - np.min(xs)) / 2.0)
    ry = float((np.max(ys) - np.min(ys)) / 2.0)

    return {
        "shape": "circle",
        "confidence": float(min(1.0 - cv / threshold, 1.0)),
        "geometry": {"center": [float(xc), float(yc)], "radius_x": rx, "radius_y": ry},
    }


def _try_triangle(vertices: np.ndarray) -> dict | None:
    if len(vertices) < 3:
        return None
    angles = []
    for i in range(3):
        v = vertices[i]
        p1 = vertices[(i + 1) % 3]
        p2 = vertices[(i + 2) % 3]
        a, b = p1 - v, p2 - v
        cos_a = np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9)
        angles.append(float(np.degrees(np.arccos(np.clip(cos_a, -1, 1)))))

    if abs(sum(angles) - 180) > 30:
        return None
    if any(a < 10 for a in angles):
        return None

    return {
        "shape": "triangle",
        "confidence": float(1.0 - abs(sum(angles) - 180) / 30),
        "geometry": {"vertices": vertices.tolist()},
    }


def _try_rectangle(vertices: np.ndarray) -> dict | None:
    if len(vertices) < 4:
        return None
    angles = []
    for i in range(4):
        prev = vertices[(i - 1) % 4]
        curr = vertices[i]
        next_ = vertices[(i + 1) % 4]
        v1, v2 = curr - prev, next_ - curr
        cos_a = np.dot(v1, v2) / (np.linalg.norm(v1) * np.linalg.norm(v2) + 1e-9)
        angles.append(float(np.degrees(np.arccos(np.clip(cos_a, -1, 1)))))

    if any(abs(a - 90) > 30 for a in angles):
        return None

    xs, ys = vertices[:, 0], vertices[:, 1]
    return {
        "shape": "rectangle",
        "confidence": float(1.0 - max(abs(a - 90) for a in angles) / 30),
        "geometry": {
            "x": float(np.min(xs)), "y": float(np.min(ys)),
            "width": float(np.max(xs) - np.min(xs)),
            "height": float(np.max(ys) - np.min(ys)),
            "angle": 0.0,
        },
    }


def _try_rectangle_from_bbox(points: np.ndarray) -> dict | None:
    """Fallback: check if points trace a bounding box shape."""
    xs, ys = points[:, 0], points[:, 1]
    x_min, y_min = float(np.min(xs)), float(np.min(ys))
    x_max, y_max = float(np.max(xs)), float(np.max(ys))
    w, h = x_max - x_min, y_max - y_min
    if w < 10 or h < 10:
        return None

    margin = max(w, h) * 0.15
    near_edge = sum(
        1 for pt in points
        if (abs(pt[0] - x_min) < margin or abs(pt[0] - x_max) < margin or
            abs(pt[1] - y_min) < margin or abs(pt[1] - y_max) < margin)
    )
    ratio = near_edge / len(points)
    if ratio < 0.65:
        return None

    return {
        "shape": "rectangle",
        "confidence": float(ratio),
        "geometry": {"x": x_min, "y": y_min, "width": w, "height": h, "angle": 0.0},
    }


def _bbox_diagonal(points: np.ndarray) -> float:
    xs, ys = points[:, 0], points[:, 1]
    return float(np.sqrt((np.max(xs) - np.min(xs)) ** 2 + (np.max(ys) - np.min(ys)) ** 2))
