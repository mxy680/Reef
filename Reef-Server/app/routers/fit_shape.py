import logging
import math
from fastapi import APIRouter
from pydantic import BaseModel
import numpy as np
import cv2

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class FitShapeRequest(BaseModel):
    points: list[list[float]]
    closed: bool = False


class FitShapeResponse(BaseModel):
    shape: str  # "line", "rectangle", "circle", "triangle", "arrow", "none"
    confidence: float
    geometry: dict


@router.post("/fit-shape", response_model=FitShapeResponse)
async def fit_shape(req: FitShapeRequest) -> FitShapeResponse:
    pts = req.points
    if len(pts) < 3:
        return FitShapeResponse(shape="none", confidence=0.0, geometry={})

    result = detect_shape(pts, req.closed)
    return result


def detect_shape(pts: list[list[float]], closed: bool) -> FitShapeResponse:
    # Convert to numpy float32 array of shape (N, 1, 2) for OpenCV
    arr = np.array(pts, dtype=np.float32).reshape(-1, 1, 2)

    perimeter = cv2.arcLength(arr, closed)

    # Auto-detect closed: if last point is near first relative to perimeter
    if not closed and perimeter > 0:
        first = np.array(pts[0])
        last = np.array(pts[-1])
        gap = float(np.linalg.norm(last - first))
        if gap < 0.1 * perimeter:
            closed = True

    if not closed:
        return _detect_open_shape(pts, arr, perimeter)
    else:
        return _detect_closed_shape(pts, arr, perimeter)


# ---------------------------------------------------------------------------
# Open-stroke detection
# ---------------------------------------------------------------------------

def _detect_open_shape(
    pts: list[list[float]],
    arr: np.ndarray,
    perimeter: float,
) -> FitShapeResponse:
    # Check LINE via least-squares residuals
    points_2d = arr.reshape(-1, 2)
    line_result = _try_line(points_2d, perimeter)
    if line_result is not None:
        return line_result

    # Check ARROW
    arrow_result = _try_arrow(pts, points_2d, perimeter)
    if arrow_result is not None:
        return arrow_result

    return FitShapeResponse(shape="none", confidence=0.0, geometry={})


def _try_line(points_2d: np.ndarray, perimeter: float) -> FitShapeResponse | None:
    """Fit a line via least squares; accept if max perpendicular deviation < 8% of length."""
    start = points_2d[0]
    end = points_2d[-1]
    length = float(np.linalg.norm(end - start))
    if length < 1e-6:
        return None

    direction = (end - start) / length
    normal = np.array([-direction[1], direction[0]])

    offsets = points_2d - start
    perpendicular = np.abs(offsets @ normal)
    max_dev = float(perpendicular.max())

    threshold = 0.08
    if max_dev / length < threshold:
        confidence = float(np.clip(1.0 - (max_dev / length) / threshold, 0.0, 1.0))
        return FitShapeResponse(
            shape="line",
            confidence=confidence,
            geometry={
                "start": [float(start[0]), float(start[1])],
                "end": [float(end[0]), float(end[1])],
            },
        )
    return None


def _try_arrow(
    pts: list[list[float]],
    points_2d: np.ndarray,
    perimeter: float,
) -> FitShapeResponse | None:
    """Detect arrow: main body is a line, last 20-30% has a sharp angle change."""
    n = len(points_2d)
    split_idx = int(n * 0.75)  # first 75% is the shaft
    if split_idx < 3:
        return None

    shaft = points_2d[:split_idx]
    shaft_start = shaft[0]
    shaft_end = shaft[-1]
    shaft_length = float(np.linalg.norm(shaft_end - shaft_start))
    if shaft_length < 1e-6:
        return None

    shaft_dir = (shaft_end - shaft_start) / shaft_length
    shaft_normal = np.array([-shaft_dir[1], shaft_dir[0]])
    shaft_offsets = shaft - shaft_start
    shaft_perp = np.abs(shaft_offsets @ shaft_normal)

    if shaft_perp.max() / shaft_length >= 0.08:
        return None  # shaft is not a line

    # Check tail for sharp angle change
    tail = points_2d[split_idx:]
    if len(tail) < 2:
        return None

    tail_vec = tail[-1] - shaft_end
    tail_len = float(np.linalg.norm(tail_vec))
    if tail_len < 1e-6:
        return None

    tail_dir = tail_vec / tail_len
    cos_angle = float(np.clip(np.dot(shaft_dir, tail_dir), -1.0, 1.0))
    angle_deg = math.degrees(math.acos(abs(cos_angle)))

    if angle_deg > 20:  # tail diverges from shaft direction — likely arrowhead
        confidence = float(np.clip(1.0 - (shaft_perp.max() / shaft_length) / 0.08, 0.0, 1.0))
        return FitShapeResponse(
            shape="arrow",
            confidence=confidence,
            geometry={
                "start": [float(shaft_start[0]), float(shaft_start[1])],
                "end": [float(shaft_end[0]), float(shaft_end[1])],
            },
        )
    return None


# ---------------------------------------------------------------------------
# Closed-stroke detection
# ---------------------------------------------------------------------------

def _detect_closed_shape(
    pts: list[list[float]],
    arr: np.ndarray,
    perimeter: float,
) -> FitShapeResponse:
    # Simplify polygon
    epsilon = 0.03 * perimeter
    approx = cv2.approxPolyDP(arr, epsilon, True)
    n_verts = len(approx)

    if n_verts == 3:
        return _fit_triangle(pts, arr, approx)
    elif n_verts == 4:
        return _fit_rectangle(pts, arr, approx)
    else:
        # Try circle/ellipse
        points_2d = arr.reshape(-1, 2)
        if len(points_2d) >= 5:
            circle_result = _try_circle(points_2d)
            if circle_result is not None:
                return circle_result

    return FitShapeResponse(shape="none", confidence=0.0, geometry={})


def _fit_triangle(
    pts: list[list[float]],
    arr: np.ndarray,
    approx: np.ndarray,
) -> FitShapeResponse:
    verts = approx.reshape(-1, 2)
    contour_area = float(cv2.contourArea(arr))
    triangle_area = float(cv2.contourArea(approx))
    if triangle_area < 1e-6:
        return FitShapeResponse(shape="none", confidence=0.0, geometry={})

    confidence = float(np.clip(contour_area / triangle_area, 0.0, 1.0))
    # Invert if contour larger than simplified (rounding)
    if confidence > 1.0:
        confidence = float(np.clip(triangle_area / contour_area, 0.0, 1.0))

    if confidence < 0.6:
        return FitShapeResponse(shape="none", confidence=0.0, geometry={})

    vertices = [[float(v[0]), float(v[1])] for v in verts]
    return FitShapeResponse(
        shape="triangle",
        confidence=confidence,
        geometry={"vertices": vertices},
    )


def _fit_rectangle(
    pts: list[list[float]],
    arr: np.ndarray,
    approx: np.ndarray,
) -> FitShapeResponse:
    contour_area = float(cv2.contourArea(arr))
    rect = cv2.minAreaRect(arr)
    (cx, cy), (w, h), angle_deg = rect
    rect_area = w * h
    if rect_area < 1e-6:
        return FitShapeResponse(shape="none", confidence=0.0, geometry={})

    confidence = float(np.clip(contour_area / rect_area, 0.0, 1.0))
    if confidence < 0.6:
        return FitShapeResponse(shape="none", confidence=0.0, geometry={})

    # Convert angle to radians and compute top-left corner
    angle_rad = math.radians(float(angle_deg))
    # Top-left relative to center, before rotation
    half_w = w / 2.0
    half_h = h / 2.0
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    top_left_x = float(cx) - half_w * cos_a + half_h * sin_a
    top_left_y = float(cy) - half_w * sin_a - half_h * cos_a

    return FitShapeResponse(
        shape="rectangle",
        confidence=confidence,
        geometry={
            "x": top_left_x,
            "y": top_left_y,
            "width": float(w),
            "height": float(h),
            "angle": angle_rad,
        },
    )


def _try_circle(points_2d: np.ndarray) -> FitShapeResponse | None:
    """Fit an ellipse; if points lie close to its boundary, classify as circle/ellipse.

    Uses the coefficient of variation (std/mean) of raw radial distances to reject
    scatter patterns that happen to fit an ellipse but are not stroked on its boundary.
    """
    arr_fit = points_2d.reshape(-1, 1, 2).astype(np.float32)
    try:
        ellipse = cv2.fitEllipse(arr_fit)
    except cv2.error:
        return None

    (cx, cy), (major, minor), angle_deg = ellipse
    if major < 1e-6:
        return None

    radius_x = major / 2.0
    radius_y = minor / 2.0
    mean_radius = (radius_x + radius_y) / 2.0
    cx_f = float(cx)
    cy_f = float(cy)

    # Compute raw radial distances; stroked circles have low CV, filled scribbles have high CV
    raw_radii = np.sqrt(
        (points_2d[:, 0] - cx_f) ** 2 + (points_2d[:, 1] - cy_f) ** 2
    )
    radii_cv = float(np.std(raw_radii) / np.mean(raw_radii)) if float(np.mean(raw_radii)) > 1e-6 else 1.0
    # Real circle strokes have CV near 0; random scatter typically > 0.15
    if radii_cv > 0.15:
        return None

    # Measure mean distance from fitted ellipse boundary
    cos_a = math.cos(math.radians(float(angle_deg)))
    sin_a = math.sin(math.radians(float(angle_deg)))

    deviations: list[float] = []
    for pt in points_2d:
        dx = float(pt[0]) - cx_f
        dy = float(pt[1]) - cy_f
        # Rotate to ellipse-aligned axes
        rx = dx * cos_a + dy * sin_a
        ry = -dx * sin_a + dy * cos_a
        # Ellipse distance approximation: point on ellipse at same angle
        theta = math.atan2(ry / radius_y, rx / radius_x) if radius_x > 0 and radius_y > 0 else 0.0
        ex = radius_x * math.cos(theta)
        ey = radius_y * math.sin(theta)
        dev = math.sqrt((rx - ex) ** 2 + (ry - ey) ** 2)
        deviations.append(dev)

    mean_dev = float(np.mean(deviations)) if deviations else float("inf")
    if mean_radius < 1e-6:
        return None

    confidence = float(np.clip(1.0 - mean_dev / mean_radius, 0.0, 1.0))
    if confidence < 0.6:
        return None

    return FitShapeResponse(
        shape="circle",
        confidence=confidence,
        geometry={
            "center": [cx_f, cy_f],
            "radius_x": float(radius_x),
            "radius_y": float(radius_y),
        },
    )
