"""Spatial clustering for chunked transcription."""

import asyncio
import hashlib
import json
import logging
import math
from dataclasses import dataclass
from typing import Awaitable, Callable

log = logging.getLogger(__name__)

DISTANCE_THRESHOLD = 50.0  # points (~0.5 inch)


def _stroke_bbox(stroke: dict) -> tuple[float, float, float, float]:
    """Return (min_x, min_y, max_x, max_y) for a stroke."""
    xs, ys = stroke.get("x", []), stroke.get("y", [])
    if not xs or not ys:
        return (0, 0, 0, 0)
    return (min(xs), min(ys), max(xs), max(ys))


def _bbox_distance(a: tuple, b: tuple) -> float:
    """Minimum distance between two axis-aligned bounding boxes. 0 if overlapping."""
    gap_x = max(0, a[0] - b[2], b[0] - a[2])
    gap_y = max(0, a[1] - b[3], b[1] - a[3])
    return math.sqrt(gap_x * gap_x + gap_y * gap_y)


def _union_bbox(a: tuple, b: tuple) -> tuple:
    return (min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]))


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


def _cluster_strokes(all_strokes: list[dict]) -> list[Cluster]:
    """Group strokes into spatial clusters based on bounding box proximity."""
    clusters: list[Cluster] = []

    for i, stroke in enumerate(all_strokes):
        bbox = _stroke_bbox(stroke)
        if bbox == (0, 0, 0, 0):
            continue

        # Find nearest cluster
        best_cluster = None
        best_dist = float("inf")
        for cluster in clusters:
            d = _bbox_distance(bbox, cluster.bbox)
            if d < best_dist:
                best_dist = d
                best_cluster = cluster

        if best_cluster is not None and best_dist <= DISTANCE_THRESHOLD:
            best_cluster.add_stroke(i, bbox)
        else:
            clusters.append(Cluster(stroke_indices=[i], bbox=bbox))

    # Merge pass: merge clusters that are now within threshold
    merged = True
    while merged:
        merged = False
        i = 0
        while i < len(clusters):
            j = i + 1
            while j < len(clusters):
                if _bbox_distance(clusters[i].bbox, clusters[j].bbox) <= DISTANCE_THRESHOLD:
                    # Merge j into i
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
