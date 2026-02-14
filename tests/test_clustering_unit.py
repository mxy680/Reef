"""Unit tests for pure stroke clustering computation (no database)."""

import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lib.stroke_clustering import StrokeEntry, extract_stroke_entries, run_dbscan


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_stroke(x: float, y: float) -> dict:
    """Create a single-point stroke at (x, y)."""
    return {"points": [{"x": x, "y": y}]}


def _make_line_stroke(points: list[tuple[float, float]]) -> dict:
    """Create a multi-point stroke from a list of (x, y) tuples."""
    return {"points": [{"x": x, "y": y} for x, y in points]}


def _entries_at(coords: list[tuple[float, float]]) -> list[StrokeEntry]:
    """Shortcut: build StrokeEntry list from (x, y) pairs."""
    return [
        StrokeEntry(log_id=1, index=i, centroid_x=x, centroid_y=y)
        for i, (x, y) in enumerate(coords)
    ]


# ---------------------------------------------------------------------------
# extract_stroke_entries
# ---------------------------------------------------------------------------

class TestExtractStrokeEntries:

    def test_single_point_stroke(self):
        rows = [{"id": 1, "strokes": [_make_stroke(100.0, 200.0)]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 1
        assert entries[0].centroid_x == 100.0
        assert entries[0].centroid_y == 200.0
        assert entries[0].log_id == 1
        assert entries[0].index == 0

    def test_multi_point_centroid(self):
        stroke = _make_line_stroke([(0.0, 0.0), (10.0, 0.0), (10.0, 10.0), (0.0, 10.0)])
        rows = [{"id": 1, "strokes": [stroke]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 1
        assert entries[0].centroid_x == pytest.approx(5.0)
        assert entries[0].centroid_y == pytest.approx(5.0)

    def test_multiple_strokes_per_row(self):
        rows = [{"id": 1, "strokes": [_make_stroke(10, 20), _make_stroke(30, 40)]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 2
        assert entries[0].index == 0
        assert entries[1].index == 1

    def test_multiple_rows(self):
        rows = [
            {"id": 1, "strokes": [_make_stroke(10, 20)]},
            {"id": 2, "strokes": [_make_stroke(30, 40)]},
        ]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 2
        assert entries[0].log_id == 1
        assert entries[1].log_id == 2

    def test_empty_points_skipped(self):
        rows = [{"id": 1, "strokes": [{"points": []}, _make_stroke(5, 5)]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 1
        assert entries[0].index == 1  # the empty one at index 0 was skipped

    def test_no_points_key_skipped(self):
        rows = [{"id": 1, "strokes": [{}]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 0

    def test_empty_rows(self):
        assert extract_stroke_entries([]) == []

    def test_json_string_strokes(self):
        """strokes column might come as a JSON string instead of parsed list."""
        import json
        rows = [{"id": 1, "strokes": json.dumps([_make_stroke(7.0, 8.0)])}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 1
        assert entries[0].centroid_x == 7.0


# ---------------------------------------------------------------------------
# run_dbscan — geometry tests
# ---------------------------------------------------------------------------

class TestRunDbscan:

    def test_two_tight_clusters(self):
        """Two groups of points far apart should form two clusters."""
        # Cluster A around (100, 100), Cluster B around (1000, 1000)
        entries = _entries_at([
            (100, 100), (110, 105), (95, 110),   # cluster A
            (1000, 1000), (1010, 1005), (995, 1010),  # cluster B
        ])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 2
        assert infos[0].stroke_count == 3
        assert infos[1].stroke_count == 3
        assert (labels == -1).sum() == 0  # no noise

    def test_single_cluster(self):
        """All points close together should form one cluster."""
        entries = _entries_at([(100, 100), (120, 110), (130, 90), (105, 115)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 1
        assert infos[0].stroke_count == 4

    def test_all_noise(self):
        """Points all far apart should all be noise."""
        entries = _entries_at([(0, 0), (500, 500), (1000, 0), (500, 1000)])
        _, labels, infos = run_dbscan(entries, eps=50, min_samples=2)

        assert len(infos) == 0
        assert (labels == -1).sum() == 4

    def test_single_stroke_is_noise(self):
        """A single stroke can't form a cluster with min_samples=2."""
        entries = _entries_at([(100, 100)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 0
        assert labels[0] == -1

    def test_noise_plus_cluster(self):
        """Two nearby + one distant point: cluster of 2, noise of 1."""
        entries = _entries_at([(100, 100), (110, 100), (900, 900)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 1
        assert infos[0].stroke_count == 2
        assert (labels == -1).sum() == 1

    def test_eps_boundary(self):
        """Two points exactly at eps distance should still cluster."""
        # Distance between (0, 0) and (150, 0) = 150.0 = eps
        entries = _entries_at([(0, 0), (150, 0)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 1
        assert infos[0].stroke_count == 2

    def test_eps_just_beyond(self):
        """Two points just beyond eps should not cluster."""
        entries = _entries_at([(0, 0), (151, 0)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 0

    def test_cluster_centroid_accuracy(self):
        """Cluster centroid should be mean of member centroids."""
        entries = _entries_at([(100, 200), (200, 300)])
        # Distance = sqrt(100^2 + 100^2) ≈ 141, well within eps=150
        _, _, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 1
        assert infos[0].centroid[0] == pytest.approx(150.0)
        assert infos[0].centroid[1] == pytest.approx(250.0)

    def test_bounding_box_accuracy(self):
        """Bounding box should span min/max of member centroids."""
        entries = _entries_at([(50, 100), (200, 300), (150, 200)])
        _, _, infos = run_dbscan(entries, eps=250, min_samples=2)

        assert len(infos) == 1
        bbox = infos[0].bounding_box
        assert bbox[0] == pytest.approx(50.0)   # x1
        assert bbox[1] == pytest.approx(100.0)  # y1
        assert bbox[2] == pytest.approx(200.0)  # x2
        assert bbox[3] == pytest.approx(300.0)  # y2

    def test_min_samples_respected(self):
        """min_samples=3 should require 3 neighbors to form a cluster."""
        entries = _entries_at([(100, 100), (110, 100)])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=3)

        # Only 2 points, need 3 — both become noise
        assert len(infos) == 0
        assert (labels == -1).sum() == 2

    def test_cluster_labels_sequential(self):
        """Cluster labels should be 0, 1, 2... in order."""
        entries = _entries_at([
            (0, 0), (10, 0),           # cluster 0
            (500, 500), (510, 500),    # cluster 1
            (1000, 0), (1010, 0),      # cluster 2
        ])
        _, _, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 3
        assert [i.cluster_label for i in infos] == [0, 1, 2]

    def test_realistic_canvas_scenario(self):
        """Simulate realistic strokes: two problem areas on a 1224x1584 canvas."""
        # Problem 1: strokes around (300, 400)
        # Problem 2: strokes around (300, 1200)
        entries = _entries_at([
            (280, 380), (310, 420), (290, 400), (320, 390), (300, 410),
            (280, 1180), (310, 1220), (290, 1200), (320, 1190), (300, 1210),
        ])
        _, labels, infos = run_dbscan(entries, eps=150, min_samples=2)

        assert len(infos) == 2
        assert infos[0].stroke_count == 5
        assert infos[1].stroke_count == 5
        assert (labels == -1).sum() == 0
