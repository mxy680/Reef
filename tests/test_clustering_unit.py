"""Unit tests for Y-centroid gap stroke clustering (no database)."""

import pytest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from lib.stroke_clustering import StrokeEntry, extract_stroke_entries, cluster_by_centroid_gap


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_stroke(x: float, y: float) -> dict:
    """Create a single-point stroke at (x, y)."""
    return {"points": [{"x": x, "y": y}]}


def _make_line_stroke(points: list[tuple[float, float]]) -> dict:
    """Create a multi-point stroke from a list of (x, y) tuples."""
    return {"points": [{"x": x, "y": y} for x, y in points]}


def _point_entry(x: float, y: float, idx: int = 0) -> StrokeEntry:
    """Single-point stroke entry at (x, y)."""
    return StrokeEntry(log_id=1, index=idx, min_x=x, min_y=y, max_x=x, max_y=y)


def _box_entry(x1: float, y1: float, x2: float, y2: float, idx: int = 0) -> StrokeEntry:
    """Stroke entry with explicit bounding box."""
    return StrokeEntry(log_id=1, index=idx, min_x=x1, min_y=y1, max_x=x2, max_y=y2)


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
        assert entries[0].index == 1

    def test_no_points_key_skipped(self):
        rows = [{"id": 1, "strokes": [{}]}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 0

    def test_empty_rows(self):
        assert extract_stroke_entries([]) == []

    def test_json_string_strokes(self):
        import json
        rows = [{"id": 1, "strokes": json.dumps([_make_stroke(7.0, 8.0)])}]
        entries = extract_stroke_entries(rows)
        assert len(entries) == 1
        assert entries[0].centroid_x == 7.0


# ---------------------------------------------------------------------------
# cluster_by_centroid_gap
# ---------------------------------------------------------------------------

class TestClusterByCentroidGap:

    def test_two_lines(self):
        """Two groups of strokes at different y positions → two clusters."""
        entries = [
            _box_entry(280, 380, 320, 420, idx=0),   # line 1, centroid_y=400
            _box_entry(310, 390, 350, 420, idx=1),   # line 1, centroid_y=405
            _box_entry(340, 380, 380, 410, idx=2),   # line 1, centroid_y=395
            _box_entry(280, 480, 320, 520, idx=3),   # line 2, centroid_y=500
            _box_entry(310, 490, 350, 520, idx=4),   # line 2, centroid_y=505
            _box_entry(340, 480, 380, 510, idx=5),   # line 2, centroid_y=495
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2
        assert infos[0].stroke_count == 3
        assert infos[1].stroke_count == 3

    def test_three_lines(self):
        """Three distinct y-regions → three clusters."""
        entries = [
            _point_entry(100, 100, idx=0),
            _point_entry(120, 105, idx=1),
            _point_entry(100, 200, idx=2),
            _point_entry(120, 205, idx=3),
            _point_entry(100, 300, idx=4),
            _point_entry(120, 305, idx=5),
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 3
        assert all(info.stroke_count == 2 for info in infos)

    def test_single_line(self):
        """All strokes at similar y → one cluster."""
        entries = [
            _point_entry(100, 100, idx=0),
            _point_entry(200, 105, idx=1),
            _point_entry(300, 102, idx=2),
            _point_entry(400, 108, idx=3),
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1
        assert infos[0].stroke_count == 4

    def test_tall_symbol_stays_on_its_line(self):
        """An integral sign spanning y=350-450 has centroid_y=400, stays on line 1."""
        entries = [
            _box_entry(50, 380, 200, 420, idx=0),     # line 1 character, centroid_y=400
            _box_entry(100, 350, 120, 450, idx=1),     # integral ∫, centroid_y=400
            _box_entry(150, 385, 250, 415, idx=2),     # line 1 character, centroid_y=400
            _box_entry(50, 520, 200, 560, idx=3),      # line 2 character, centroid_y=540
            _box_entry(150, 525, 250, 555, idx=4),     # line 2 character, centroid_y=540
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2
        assert labels[0] == 0  # line 1
        assert labels[1] == 0  # integral on line 1
        assert labels[2] == 0  # line 1
        assert labels[3] == 1  # line 2
        assert labels[4] == 1  # line 2

    def test_tall_symbol_bbox_would_bridge_but_centroid_doesnt(self):
        """Bbox of tall stroke overlaps next line's bbox, but centroids are separate."""
        entries = [
            _box_entry(50, 110, 200, 140, idx=0),      # line 1, centroid_y=125
            _box_entry(100, 80, 120, 200, idx=1),       # tall stroke, centroid_y=140
            _box_entry(50, 190, 200, 220, idx=2),       # line 2, centroid_y=205
        ]
        # Bbox overlap: entry 1 (y=80-200) overlaps entry 2 (y=190-220).
        # Centroid gap: 125→140 = 15 (< 20 threshold), 140→205 = 65 (> 20) → 2 clusters.
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2
        assert labels[0] == labels[1]  # entries 0,1 same cluster
        assert labels[2] != labels[0]  # entry 2 different cluster

    def test_subscript_stays_on_line(self):
        """Subscript with ~10px centroid_y offset stays on same line."""
        entries = [
            _point_entry(100, 400, idx=0),    # base character
            _point_entry(200, 400, idx=1),    # base character
            _point_entry(250, 412, idx=2),    # subscript, ~12px lower
            _point_entry(300, 400, idx=3),    # base character
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1

    def test_single_stroke(self):
        """A single stroke forms one cluster."""
        entries = [_point_entry(100, 100)]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1
        assert labels[0] == 0

    def test_empty_input(self):
        """Empty input returns empty output."""
        centroids, labels, infos = cluster_by_centroid_gap([])
        assert len(infos) == 0
        assert len(labels) == 0
        assert centroids.shape == (0, 2)

    def test_two_strokes_same_line(self):
        """Two strokes at similar y → one cluster."""
        entries = [
            _point_entry(100, 400, idx=0),
            _point_entry(200, 405, idx=1),
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1

    def test_two_strokes_different_lines(self):
        """Two strokes far apart in y → two clusters."""
        entries = [
            _point_entry(100, 100, idx=0),
            _point_entry(100, 500, idx=1),
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2

    def test_labels_ordered_top_to_bottom(self):
        """Cluster 0 should be the topmost line."""
        entries = [
            _point_entry(100, 500, idx=0),    # line 2 (bottom)
            _point_entry(100, 100, idx=1),    # line 1 (top)
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2
        assert labels[1] == 0  # top stroke → cluster 0
        assert labels[0] == 1  # bottom stroke → cluster 1

    def test_centroid_accuracy(self):
        """Cluster centroid should be mean of member centroids."""
        entries = [
            _box_entry(0, 0, 100, 100, idx=0),     # centroid (50, 50)
            _box_entry(50, 0, 150, 100, idx=1),     # centroid (100, 50)
        ]
        _, _, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1
        assert infos[0].centroid[0] == pytest.approx(75.0)
        assert infos[0].centroid[1] == pytest.approx(50.0)

    def test_bounding_box_accuracy(self):
        """Cluster bounding box should span all member bboxes."""
        entries = [
            _box_entry(10, 20, 50, 60, idx=0),
            _box_entry(30, 25, 80, 55, idx=1),
        ]
        _, _, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1
        bbox = infos[0].bounding_box
        assert bbox[0] == pytest.approx(10.0)
        assert bbox[1] == pytest.approx(20.0)
        assert bbox[2] == pytest.approx(80.0)
        assert bbox[3] == pytest.approx(60.0)

    def test_threshold_exactly_at(self):
        """Gap exactly at threshold should NOT split (> not >=)."""
        # With 2 strokes, < 3 gaps → threshold = 20
        entries = [
            _point_entry(100, 100, idx=0),
            _point_entry(100, 120, idx=1),    # gap = 20, not > 20
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 1

    def test_threshold_just_above(self):
        """Gap just above threshold should split."""
        # With 2 strokes, < 3 gaps → threshold = 20
        entries = [
            _point_entry(100, 100, idx=0),
            _point_entry(100, 121, idx=1),    # gap = 21 > 20
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2

    def test_adaptive_threshold_with_many_strokes(self):
        """With many strokes, threshold adapts based on gap distribution."""
        # 8 strokes on line 1 (y=100..107), 1 stroke on line 2 (y=200)
        entries = [_point_entry(i * 50, 100 + i, idx=i) for i in range(8)]
        entries.append(_point_entry(100, 200, idx=8))

        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2
        # First 8 on cluster 0, last one on cluster 1
        for i in range(8):
            assert labels[i] == 0
        assert labels[8] == 1

    def test_third_line_doesnt_merge_first_two(self):
        """Adding a third line of strokes must not merge the first two lines."""
        # Line 1: centroids ~295-302
        line1 = [_box_entry(i*30, 290, i*30+20, 310, idx=i) for i in range(9)]
        # Line 2: centroids ~317-337
        line2 = [_box_entry(i*30, 315, i*30+20, 340, idx=9+i) for i in range(10)]
        # Line 3: centroids ~362-367, added later
        line3 = [_box_entry(i*30, 356, i*30+20, 377, idx=19+i) for i in range(4)]

        entries = line1 + line2 + line3
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 3, f"Expected 3 clusters, got {len(infos)}"
        # All line1 strokes in cluster 0
        for i in range(9):
            assert labels[i] == 0, f"Line 1 stroke {i} should be cluster 0"
        # All line2 strokes in cluster 1
        for i in range(9, 19):
            assert labels[i] == 1, f"Line 2 stroke {i} should be cluster 1"
        # All line3 strokes in cluster 2
        for i in range(19, 23):
            assert labels[i] == 2, f"Line 3 stroke {i} should be cluster 2"

    def test_real_ipad_close_lines(self):
        """Real iPad handwriting: two lines only ~12px apart in centroid space.

        Line 1: 14 strokes with centroids around y=292-302
        Line 2: 16 strokes with centroids around y=314-331
        Gap between lines: ~11.8px
        """
        # Stroke bboxes from real session 8BEDD7CA
        entries = [
            # Line 1 (log 154) — upper line, centroids ~292-296
            _box_entry(274, 286, 279, 299, idx=0),   # cy=292.5
            _box_entry(263, 286, 272, 300, idx=1),    # cy=293.0
            _box_entry(254, 293, 260, 295, idx=2),    # cy=294.0
            _box_entry(286, 291, 294, 298, idx=3),    # cy=294.5
            _box_entry(283, 292, 293, 299, idx=4),    # cy=295.5
            # Line 1 (log 150) — centroids ~296-302
            _box_entry(100, 290, 140, 302, idx=5),    # cy=296.0
            _box_entry(150, 295, 170, 300, idx=6),    # cy=297.5
            _box_entry(180, 294, 200, 301, idx=7),    # cy=297.5
            _box_entry(60, 290, 100, 306, idx=8),     # cy=298.0
            _box_entry(40, 297, 60, 299, idx=9),      # cy=298.0
            _box_entry(120, 294, 140, 303, idx=10),   # cy=298.5
            _box_entry(160, 295, 180, 302, idx=11),   # cy=298.5
            _box_entry(200, 295, 220, 302, idx=12),   # cy=298.5
            _box_entry(20, 301, 40, 303, idx=13),     # cy=302.0
            # Line 2 (log 153) — lower line, centroids ~314-331
            _box_entry(233, 311, 238, 316, idx=14),   # cy=313.5
            _box_entry(224, 315, 230, 321, idx=15),   # cy=318.0
            _box_entry(225, 316, 229, 322, idx=16),   # cy=319.0
            _box_entry(242, 315, 248, 331, idx=17),   # cy=323.0
            _box_entry(215, 317, 221, 331, idx=18),   # cy=324.0
            _box_entry(225, 324, 236, 324, idx=19),   # cy=324.0
            _box_entry(229, 329, 235, 334, idx=20),   # cy=331.5
            # Line 2 (log 155) — centroids ~319-323
            _box_entry(305, 313, 319, 325, idx=21),   # cy=319.0
            _box_entry(256, 319, 263, 320, idx=22),   # cy=319.5
            _box_entry(291, 314, 293, 327, idx=23),   # cy=320.5
            _box_entry(288, 320, 298, 322, idx=24),   # cy=321.0
            _box_entry(269, 318, 279, 327, idx=25),   # cy=322.5
            _box_entry(269, 318, 278, 328, idx=26),   # cy=323.0
            # Line 2 (logs 151, 152)
            _box_entry(50, 324, 80, 325, idx=27),     # cy=324.5
            _box_entry(50, 320, 80, 330, idx=28),     # cy=325.0
            _box_entry(50, 329, 80, 330, idx=29),     # cy=329.5
        ]
        _, labels, infos = cluster_by_centroid_gap(entries)

        assert len(infos) == 2, f"Expected 2 clusters, got {len(infos)}"
        # First 14 entries are line 1, next 16 are line 2
        for i in range(14):
            assert labels[i] == 0, f"Entry {i} should be cluster 0 (line 1)"
        for i in range(14, 30):
            assert labels[i] == 1, f"Entry {i} should be cluster 1 (line 2)"
