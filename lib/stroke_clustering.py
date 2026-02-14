"""Core DBSCAN stroke clustering logic.

Uses bounding-box gap distance: two strokes are "close" if their
bounding boxes overlap or are within `eps` pixels of each other.
"""

import asyncio
import json
from dataclasses import dataclass

import numpy as np
from sklearn.cluster import DBSCAN
from sklearn.metrics import pairwise_distances

from lib.database import get_pool
from lib.models.clustering import ClusterInfo, ClusterResponse


@dataclass
class StrokeEntry:
    """A single stroke with its bounding box."""
    log_id: int
    index: int
    min_x: float
    min_y: float
    max_x: float
    max_y: float

    @property
    def centroid_x(self) -> float:
        return (self.min_x + self.max_x) / 2

    @property
    def centroid_y(self) -> float:
        return (self.min_y + self.max_y) / 2


def extract_stroke_entries(rows: list[dict]) -> list[StrokeEntry]:
    """Parse stroke_logs rows into per-stroke entries with bounding boxes."""
    entries: list[StrokeEntry] = []
    for row in rows:
        log_id = row["id"]
        strokes_json = row["strokes"]
        strokes = strokes_json if isinstance(strokes_json, list) else json.loads(strokes_json)

        for idx, stroke in enumerate(strokes):
            points = stroke.get("points", [])
            if not points:
                continue

            xs = [p["x"] for p in points]
            ys = [p["y"] for p in points]
            entries.append(StrokeEntry(
                log_id=log_id,
                index=idx,
                min_x=min(xs), min_y=min(ys),
                max_x=max(xs), max_y=max(ys),
            ))
    return entries


def bbox_gap_distance(entries: list[StrokeEntry]) -> np.ndarray:
    """Compute pairwise bounding-box gap distance matrix.

    Distance = 0 if bboxes overlap, otherwise min edge-to-edge gap.
    """
    n = len(entries)
    dist = np.zeros((n, n))
    for i in range(n):
        a = entries[i]
        for j in range(i + 1, n):
            b = entries[j]
            # Gap on each axis (negative means overlap)
            gap_x = max(0, max(a.min_x, b.min_x) - min(a.max_x, b.max_x))
            gap_y = max(0, max(a.min_y, b.min_y) - min(a.max_y, b.max_y))
            # Euclidean gap distance (0 if overlapping on both axes)
            d = (gap_x ** 2 + (gap_y * 3) ** 2) ** 0.5
            dist[i, j] = d
            dist[j, i] = d
    return dist


def run_dbscan(
    entries: list[StrokeEntry],
    eps: float = 20.0,
    min_samples: int = 1,
) -> tuple[np.ndarray, np.ndarray, list[ClusterInfo]]:
    """Run DBSCAN using bounding-box gap distance."""
    dist_matrix = bbox_gap_distance(entries)
    labels = DBSCAN(eps=eps, min_samples=min_samples, metric="precomputed").fit_predict(dist_matrix)

    centroids = np.array([[e.centroid_x, e.centroid_y] for e in entries])

    cluster_infos: list[ClusterInfo] = []
    for label in sorted(set(labels)):
        if label == -1:
            continue

        mask = labels == label
        cluster_entries = [e for e, m in zip(entries, mask) if m]
        cluster_centroids = centroids[mask]
        cluster_infos.append(ClusterInfo(
            cluster_label=int(label),
            stroke_count=int(mask.sum()),
            centroid=[
                float(cluster_centroids[:, 0].mean()),
                float(cluster_centroids[:, 1].mean()),
            ],
            bounding_box=[
                float(min(e.min_x for e in cluster_entries)),
                float(min(e.min_y for e in cluster_entries)),
                float(max(e.max_x for e in cluster_entries)),
                float(max(e.max_y for e in cluster_entries)),
            ],
        ))

    return centroids, labels, cluster_infos


async def update_cluster_labels(session_id: str, page: int, eps: float = 20.0, min_samples: int = 1):
    """Re-run DBSCAN on all draw strokes for a session+page and update cluster_labels column."""
    pool = get_pool()
    if not pool:
        return

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, strokes
            FROM stroke_logs
            WHERE session_id = $1 AND page = $2 AND event_type = 'draw'
            ORDER BY received_at
            """,
            session_id, page,
        )

    if not rows:
        return

    entries = extract_stroke_entries([dict(r) for r in rows])
    if not entries:
        return

    for e in entries:
        print(f"[cluster] stroke log={e.log_id} idx={e.index} bbox=({e.min_x:.0f},{e.min_y:.0f})-({e.max_x:.0f},{e.max_y:.0f})")

    _, labels, cluster_infos = await asyncio.to_thread(run_dbscan, entries, eps, min_samples)
    print(f"[cluster] eps={eps} bbox-gap → {len(cluster_infos)} clusters, labels={[int(l) for l in labels]}")

    # Group labels by log_id
    labels_by_log: dict[int, list[int]] = {}
    for i, entry in enumerate(entries):
        labels_by_log.setdefault(entry.log_id, []).append(int(labels[i]))

    async with pool.acquire() as conn:
        await conn.executemany(
            "UPDATE stroke_logs SET cluster_labels = $1::jsonb WHERE id = $2",
            [(json.dumps(lbls), log_id) for log_id, lbls in labels_by_log.items()],
        )


async def cluster_strokes(
    session_id: str,
    page: int,
    eps: float = 20.0,
    min_samples: int = 1,
) -> ClusterResponse:
    pool = get_pool()
    if not pool:
        raise RuntimeError("Database not configured")

    async with pool.acquire() as conn:
        rows = await conn.fetch(
            """
            SELECT id, strokes
            FROM stroke_logs
            WHERE session_id = $1 AND page = $2
            ORDER BY received_at
            """,
            session_id,
            page,
        )

    if not rows:
        return ClusterResponse(
            session_id=session_id, page=page,
            num_strokes=0, num_clusters=0, noise_strokes=0, clusters=[],
        )

    entries = extract_stroke_entries([dict(r) for r in rows])
    if not entries:
        return ClusterResponse(
            session_id=session_id, page=page,
            num_strokes=0, num_clusters=0, noise_strokes=0, clusters=[],
        )

    centroids, labels, cluster_infos = await asyncio.to_thread(
        run_dbscan, entries, eps, min_samples
    )

    # Store results to database
    async with pool.acquire() as conn:
        async with conn.transaction():
            await conn.execute(
                "DELETE FROM cluster_classes WHERE session_id = $1 AND page = $2",
                session_id, page,
            )
            await conn.execute(
                "DELETE FROM clusters WHERE session_id = $1 AND page = $2",
                session_id, page,
            )

            await conn.executemany(
                """
                INSERT INTO cluster_classes
                    (session_id, page, stroke_log_id, stroke_index, cluster_label, centroid_x, centroid_y)
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                """,
                [
                    (
                        session_id, page,
                        entry.log_id, entry.index,
                        int(labels[i]),
                        entry.centroid_x, entry.centroid_y,
                    )
                    for i, entry in enumerate(entries)
                ],
            )

            for info in cluster_infos:
                await conn.execute(
                    """
                    INSERT INTO clusters
                        (session_id, page, cluster_label, stroke_count,
                         centroid_x, centroid_y, bbox_x1, bbox_y1, bbox_x2, bbox_y2)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                    """,
                    session_id, page,
                    info.cluster_label, info.stroke_count,
                    info.centroid[0], info.centroid[1],
                    info.bounding_box[0], info.bounding_box[1],
                    info.bounding_box[2], info.bounding_box[3],
                )

    noise_count = int((labels == -1).sum())

    return ClusterResponse(
        session_id=session_id, page=page,
        num_strokes=len(entries),
        num_clusters=len(cluster_infos),
        noise_strokes=noise_count,
        clusters=cluster_infos,
    )
