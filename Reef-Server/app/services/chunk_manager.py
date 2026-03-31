"""Spatial clustering for chunked transcription."""

import asyncio
import hashlib
import json
import logging
import math
from dataclasses import dataclass
from typing import Awaitable, Callable

log = logging.getLogger(__name__)

BBOX_PAD_X = 50.0   # generous horizontal padding (same line of handwriting)
BBOX_PAD_Y = 5.0    # tight vertical padding (separate lines stay separate)


def _stroke_bbox(stroke: dict) -> tuple[float, float, float, float]:
    """Return (min_x, min_y, max_x, max_y) for a stroke."""
    xs, ys = stroke.get("x", []), stroke.get("y", [])
    if not xs or not ys:
        return (0, 0, 0, 0)
    return (min(xs), min(ys), max(xs), max(ys))


def _union_bbox(a: tuple, b: tuple) -> tuple:
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


def _should_join(stroke: dict, cluster_bbox: tuple) -> bool:
    """A stroke joins a cluster if ANY of its points are inside the cluster's bbox (with asymmetric padding)."""
    min_x = cluster_bbox[0] - BBOX_PAD_X
    min_y = cluster_bbox[1] - BBOX_PAD_Y
    max_x = cluster_bbox[2] + BBOX_PAD_X
    max_y = cluster_bbox[3] + BBOX_PAD_Y

    for x, y in zip(stroke.get("x", []), stroke.get("y", [])):
        if min_x <= x <= max_x and min_y <= y <= max_y:
            return True
    return False


def _fingerprint_strokes(strokes: list[dict]) -> str:
    canonical = json.dumps(
        [{"x": [round(v, 2) for v in s["x"]], "y": [round(v, 2) for v in s["y"]]} for s in strokes],
        sort_keys=True, separators=(",", ":")
    )
    return hashlib.md5(canonical.encode()).hexdigest()[:16]


@dataclass
class Cluster:
    stroke_indices: list[int]
    bbox: tuple[float, float, float, float]

    def add_stroke(self, index: int, stroke_bbox: tuple):
        self.stroke_indices.append(index)
        self.bbox = _union_bbox(self.bbox, stroke_bbox)


def _bboxes_overlap(a: tuple, b: tuple) -> bool:
    """Check if two bboxes overlap (with asymmetric padding)."""
    return not (a[0] - BBOX_PAD_X > b[2] + BBOX_PAD_X or b[0] - BBOX_PAD_X > a[2] + BBOX_PAD_X or
                a[1] - BBOX_PAD_Y > b[3] + BBOX_PAD_Y or b[1] - BBOX_PAD_Y > a[3] + BBOX_PAD_Y)


def _cluster_strokes(all_strokes: list[dict]) -> list[Cluster]:
    """Group strokes into spatial clusters. A stroke joins a cluster only if
    any of its points fall inside the cluster's bounding box."""
    clusters: list[Cluster] = []

    for i, stroke in enumerate(all_strokes):
        bbox = _stroke_bbox(stroke)
        if bbox == (0, 0, 0, 0):
            continue

        # Find a cluster where any point of this stroke is inside its bbox
        best_cluster = None
        for cluster in clusters:
            if _should_join(stroke, cluster.bbox):
                best_cluster = cluster
                break

        if best_cluster is not None:
            best_cluster.add_stroke(i, bbox)
        else:
            clusters.append(Cluster(stroke_indices=[i], bbox=bbox))

    # Merge pass: merge clusters whose bboxes overlap (after expansion from new strokes)
    merged = True
    while merged:
        merged = False
        i = 0
        while i < len(clusters):
            j = i + 1
            while j < len(clusters):
                if _bboxes_overlap(clusters[i].bbox, clusters[j].bbox):
                    clusters[i].stroke_indices.extend(clusters[j].stroke_indices)
                    clusters[i].bbox = _union_bbox(clusters[i].bbox, clusters[j].bbox)
                    clusters.pop(j)
                    merged = True
                else:
                    j += 1
            i += 1

    # Sort clusters in reading order: top-to-bottom, then left-to-right
    clusters.sort(key=lambda c: (c.bbox[1], c.bbox[0]))

    return clusters


async def transcribe_with_chunks(
    all_strokes: list[dict],
    user_id: str,
    document_id: str,
    question_label: str,
    persisted_chunks: list[dict] | None,
    transcribe_fn: Callable[[list[dict]], Awaitable[str]],
) -> tuple[str, list[dict]]:
    """Cluster strokes spatially, fingerprint each cluster, only re-transcribe dirty ones."""
    if not all_strokes:
        return ("", [])

    # Build fingerprint -> latex cache from persisted data
    cache: dict[str, str] = {}
    if persisted_chunks:
        for entry in persisted_chunks:
            fp = entry.get("fingerprint", "")
            latex = entry.get("latex", "")
            if fp and latex:
                cache[fp] = latex

    # Cluster all strokes from scratch
    clusters = _cluster_strokes(all_strokes)

    # Fingerprint each cluster and check cache
    dirty_indices: list[int] = []
    cluster_fps: list[str] = []
    cluster_latex: list[str] = [""] * len(clusters)
    cluster_bboxes: list[tuple] = []

    for idx, cluster in enumerate(clusters):
        strokes = [all_strokes[i] for i in cluster.stroke_indices]
        fp = _fingerprint_strokes(strokes)
        cluster_fps.append(fp)
        cluster_bboxes.append(cluster.bbox)

        if fp in cache:
            cluster_latex[idx] = cache[fp]
        else:
            dirty_indices.append(idx)

    cached_count = len(clusters) - len(dirty_indices)
    log.info(f"[chunks] {question_label}: {len(clusters)} clusters, {cached_count} cached, {len(dirty_indices)} dirty")

    # Transcribe dirty clusters concurrently
    if dirty_indices:
        async def _transcribe_one(idx: int) -> tuple[int, str]:
            strokes = [all_strokes[i] for i in clusters[idx].stroke_indices]
            latex = await transcribe_fn(strokes)
            return (idx, latex)

        results = await asyncio.gather(*[_transcribe_one(i) for i in dirty_indices])
        for idx, latex in results:
            cluster_latex[idx] = latex

    # Build persisted chunks (fingerprint + latex + bbox for debug)
    updated_chunks = []
    for idx, cluster in enumerate(clusters):
        updated_chunks.append({
            "fingerprint": cluster_fps[idx],
            "latex": cluster_latex[idx],
            "bbox": list(cluster_bboxes[idx]),
        })

    # Concatenate in reading order
    final_latex = " ".join(latex for latex in cluster_latex if latex)

    return (final_latex, updated_chunks)


def clear_cache_for_question(user_id: str, document_id: str, question_label: str) -> None:
    """No-op: cache is now persisted in DB, not in-memory."""
    pass
