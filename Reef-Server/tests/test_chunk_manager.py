import asyncio
import pytest
from app.services.chunk_manager import (
    _stroke_bbox, _bbox_distance, _cluster_strokes, _fingerprint_strokes,
    transcribe_with_chunks,
)


def _make_stroke(x_range, y_range, n=10):
    """Helper: create a stroke with n points spanning given ranges."""
    xs = [x_range[0] + i * (x_range[1] - x_range[0]) / max(n-1, 1) for i in range(n)]
    ys = [y_range[0] + i * (y_range[1] - y_range[0]) / max(n-1, 1) for i in range(n)]
    return {"x": xs, "y": ys}


class TestStrokeBbox:
    def test_simple(self):
        s = {"x": [10.0, 20.0, 30.0], "y": [100.0, 110.0, 105.0]}
        assert _stroke_bbox(s) == (10.0, 100.0, 30.0, 110.0)

    def test_empty(self):
        assert _stroke_bbox({"x": [], "y": []}) == (0, 0, 0, 0)


class TestBboxDistance:
    def test_overlapping(self):
        assert _bbox_distance((0, 0, 100, 100), (50, 50, 150, 150)) == 0

    def test_separated_horizontal(self):
        d = _bbox_distance((0, 0, 10, 10), (60, 0, 70, 10))
        assert abs(d - 50.0) < 0.01

    def test_separated_diagonal(self):
        d = _bbox_distance((0, 0, 10, 10), (40, 40, 50, 50))
        expected = (30**2 + 30**2) ** 0.5
        assert abs(d - expected) < 0.01


class TestClusterStrokes:
    def test_single_stroke(self):
        strokes = [_make_stroke((10, 30), (100, 110))]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1
        assert clusters[0].stroke_indices == [0]

    def test_nearby_strokes_same_cluster(self):
        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((35, 55), (100, 110)),  # within 50pt
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1

    def test_distant_strokes_separate_clusters(self):
        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((10, 30), (300, 310)),  # far away vertically
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 2

    def test_bridge_stroke_merges(self):
        strokes = [
            _make_stroke((10, 30), (100, 110)),   # cluster A
            _make_stroke((10, 30), (200, 210)),   # cluster B (far from A)
            _make_stroke((10, 30), (140, 170)),   # bridges A and B (within 50 of both)
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1  # all merged

    def test_reading_order_sort(self):
        strokes = [
            _make_stroke((10, 30), (300, 310)),  # bottom
            _make_stroke((10, 30), (100, 110)),  # top
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 2
        # Top cluster first
        assert clusters[0].bbox[1] < clusters[1].bbox[1]


class TestTranscribeWithChunks:
    @pytest.mark.asyncio
    async def test_caching(self):
        call_count = 0
        async def mock_transcribe(strokes):
            nonlocal call_count
            call_count += 1
            return f"latex_{call_count}"

        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((10, 30), (300, 310)),
        ]

        # First call: both clusters dirty
        latex1, chunks1 = await transcribe_with_chunks(strokes, "u", "d", "Q1a", None, mock_transcribe)
        assert call_count == 2
        assert "latex_1" in latex1
        assert "latex_2" in latex1

        # Second call with same strokes: both cached
        call_count = 0
        latex2, chunks2 = await transcribe_with_chunks(strokes, "u", "d", "Q1a", chunks1, mock_transcribe)
        assert call_count == 0  # no Mathpix calls!
        assert latex2 == latex1

    @pytest.mark.asyncio
    async def test_erase_only_dirties_one(self):
        call_count = 0
        async def mock_transcribe(strokes):
            nonlocal call_count
            call_count += 1
            return f"latex_{call_count}"

        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((35, 55), (100, 110)),  # same cluster as above
            _make_stroke((10, 30), (300, 310)),  # different cluster
        ]

        _, chunks1 = await transcribe_with_chunks(strokes, "u", "d", "Q1a", None, mock_transcribe)
        assert call_count == 2  # 2 clusters

        # Erase one stroke from first cluster
        call_count = 0
        strokes_after = [strokes[1], strokes[2]]  # removed strokes[0]
        _, chunks2 = await transcribe_with_chunks(strokes_after, "u", "d", "Q1a", chunks1, mock_transcribe)
        assert call_count == 1  # only the modified cluster re-transcribed

    @pytest.mark.asyncio
    async def test_empty(self):
        async def mock(s): return ""
        latex, chunks = await transcribe_with_chunks([], "u", "d", "Q1a", None, mock)
        assert latex == ""
        assert chunks == []
