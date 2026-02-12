"""
WebSocket endpoint for real-time stroke clustering using DBSCAN.

iOS streams stroke bounding boxes per page; server returns cluster
assignments with dirty flags for incremental transcription.
"""

import hashlib
import json

import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from sklearn.cluster import DBSCAN

router = APIRouter()

# Anisotropic margins (points) — must match the values the iOS app expects.
H_MARGIN = 60.0  # generous horizontal so words on the same line merge
V_MARGIN = 12.0   # strict vertical so separate lines stay apart


def _rect_distance_matrix(rects: np.ndarray) -> np.ndarray:
    """Compute pairwise anisotropic edge-gap distances for N rects.

    Parameters
    ----------
    rects : ndarray of shape (N, 4)
        Each row is (x, y, w, h).

    Returns
    -------
    ndarray of shape (N, N) — symmetric distance matrix.
    """
    n = len(rects)
    if n == 0:
        return np.empty((0, 0))

    x1 = rects[:, 0]
    y1 = rects[:, 1]
    x2 = x1 + rects[:, 2]
    y2 = y1 + rects[:, 3]

    # Pairwise edge gaps (0 when overlapping)
    dx = np.maximum(0, np.maximum(x1[:, None] - x2[None, :],
                                   x2[None, :] - x1[:, None] - rects[:, 2][:, None] - rects[:, 2][None, :] + (x2[:, None] - x1[:, None])))
    # Simpler: gap = max(0, max(a.minX - b.maxX, b.minX - a.maxX))
    dx = np.maximum(0, np.maximum(x1[:, None] - x2[None, :],
                                   x1[None, :] - x2[:, None]))
    dy = np.maximum(0, np.maximum(y1[:, None] - y2[None, :],
                                   y1[None, :] - y2[:, None]))

    nx = dx / H_MARGIN
    ny = dy / V_MARGIN
    return np.sqrt(nx * nx + ny * ny)


def _cluster_strokes(rects: list[dict]) -> list[dict]:
    """Run DBSCAN on stroke bounding boxes and return cluster descriptors.

    Each input rect is ``{"x": float, "y": float, "w": float, "h": float}``.

    Returns a list of cluster dicts::

        {"id": str, "bbox": {"x","y","w","h"}, "stroke_indices": [int,...]}
    """
    if not rects:
        return []

    arr = np.array([[r["x"], r["y"], r["w"], r["h"]] for r in rects],
                   dtype=np.float64)
    dist = _rect_distance_matrix(arr)

    labels = DBSCAN(eps=1.0, min_samples=1, metric="precomputed").fit_predict(dist)

    clusters_map: dict[int, list[int]] = {}
    for idx, label in enumerate(labels):
        clusters_map.setdefault(label, []).append(idx)

    results: list[dict] = []
    for label, indices in sorted(clusters_map.items()):
        subset = arr[indices]
        min_x = float(subset[:, 0].min())
        min_y = float(subset[:, 1].min())
        max_x = float((subset[:, 0] + subset[:, 2]).max())
        max_y = float((subset[:, 1] + subset[:, 3]).max())

        # Deterministic ID from sorted stroke tuples
        key_tuples = sorted(tuple(arr[i].tolist()) for i in indices)
        raw = json.dumps(key_tuples, separators=(",", ":")).encode()
        cluster_id = hashlib.sha256(raw).hexdigest()[:8]

        results.append({
            "id": cluster_id,
            "bbox": {
                "x": min_x,
                "y": min_y,
                "w": max_x - min_x,
                "h": max_y - min_y,
            },
            "stroke_count": len(indices),
            "stroke_indices": indices,
        })

    return results


@router.websocket("/ws/cluster")
async def cluster_websocket(ws: WebSocket):
    await ws.accept()

    # Per-connection state: page -> {cluster_id: frozenset of stroke indices}
    previous_state: dict[int, dict[str, frozenset]] = {}

    try:
        while True:
            raw = await ws.receive_text()
            msg = json.loads(raw)

            if msg.get("type") != "stroke_bounds":
                continue

            page = msg.get("page", 1)
            strokes = msg.get("strokes", [])

            clusters = _cluster_strokes(strokes)

            # Compute dirty flags by diffing against previous state
            prev = previous_state.get(page, {})
            new_state: dict[str, frozenset] = {}
            response_clusters: list[dict] = []

            for c in clusters:
                cid = c["id"]
                member_set = frozenset(c["stroke_indices"])
                new_state[cid] = member_set
                dirty = (cid not in prev) or (prev[cid] != member_set)
                response_clusters.append({
                    "id": cid,
                    "bbox": c["bbox"],
                    "stroke_count": c["stroke_count"],
                    "dirty": dirty,
                })

            previous_state[page] = new_state

            await ws.send_text(json.dumps({
                "type": "clusters",
                "page": page,
                "clusters": response_clusters,
            }))

    except WebSocketDisconnect:
        pass
    except Exception as e:
        print(f"[cluster_ws] error: {e}")
        try:
            await ws.close(code=1011, reason=str(e)[:120])
        except Exception:
            pass
