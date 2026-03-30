import pytest
from app.services.chunk_manager import (
    _stroke_bbox, _should_join, _cluster_strokes, _fingerprint_strokes,
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


class TestShouldJoin:
    def test_overlapping_bboxes(self):
        assert _should_join((10, 100, 30, 110), (20, 100, 40, 110)) is True

    def test_inside_bbox(self):
        # Stroke inside cluster bbox
        assert _should_join((15, 102, 25, 108), (10, 100, 30, 110)) is True

    def test_close_horizontal_same_line(self):
        # Stroke to the right, overlapping vertically (continuing a line)
        assert _should_join((55, 100, 75, 110), (10, 100, 50, 110)) is True

    def test_far_horizontal(self):
        # Too far right — should NOT join
        assert _should_join((200, 100, 220, 110), (10, 100, 50, 110)) is False

    def test_different_line_below(self):
        # Below with no vertical overlap — should NOT join
        assert _should_join((10, 200, 30, 210), (10, 100, 50, 110)) is False

    def test_subscript_close_vertical(self):
        # Slightly below but horizontally overlapping (subscript)
        assert _should_join((20, 112, 30, 125), (10, 100, 50, 110)) is True

    def test_far_below_same_x(self):
        # Way below — should NOT join even at same x
        assert _should_join((10, 300, 30, 310), (10, 100, 50, 110)) is False


class TestClusterStrokes:
    def test_single_stroke(self):
        strokes = [_make_stroke((10, 30), (100, 110))]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1
        assert clusters[0].stroke_indices == [0]

    def test_same_line_strokes_cluster(self):
        # Two strokes on the same line, close together
        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((35, 55), (100, 110)),
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1

    def test_different_lines_separate(self):
        # Two strokes on different lines
        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((10, 30), (300, 310)),
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 2

    def test_continuing_line_right(self):
        # Strokes extending a line to the right
        strokes = [
            _make_stroke((10, 50), (100, 115)),
            _make_stroke((55, 95), (100, 115)),
            _make_stroke((100, 140), (100, 115)),
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1

    def test_reading_order_sort(self):
        strokes = [
            _make_stroke((10, 30), (300, 310)),  # bottom
            _make_stroke((10, 30), (100, 110)),  # top
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 2
        assert clusters[0].bbox[1] < clusters[1].bbox[1]

    def test_bridge_stroke_merges(self):
        # Two clusters that get bridged by a third stroke
        strokes = [
            _make_stroke((10, 30), (100, 110)),
            _make_stroke((70, 90), (100, 110)),  # far right, same line
            _make_stroke((35, 65), (100, 110)),  # bridges the gap
        ]
        clusters = _cluster_strokes(strokes)
        assert len(clusters) == 1


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
        assert call_count == 0
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
            _make_stroke((35, 55), (100, 110)),
            _make_stroke((10, 30), (300, 310)),
        ]

        _, chunks1 = await transcribe_with_chunks(strokes, "u", "d", "Q1a", None, mock_transcribe)
        assert call_count == 2

        call_count = 0
        strokes_after = [strokes[1], strokes[2]]
        _, chunks2 = await transcribe_with_chunks(strokes_after, "u", "d", "Q1a", chunks1, mock_transcribe)
        assert call_count == 1

    @pytest.mark.asyncio
    async def test_empty(self):
        async def mock(s): return ""
        latex, chunks = await transcribe_with_chunks([], "u", "d", "Q1a", None, mock)
        assert latex == ""
        assert chunks == []

    @pytest.mark.asyncio
    async def test_add_stroke_new_line(self):
        """Adding a stroke on a new line creates a new cluster, doesn't dirty old one."""
        call_count = 0
        async def mock_transcribe(strokes):
            nonlocal call_count
            call_count += 1
            return f"latex_{call_count}"

        strokes = [_make_stroke((10, 30), (100, 110))]
        _, chunks1 = await transcribe_with_chunks(strokes, "u", "d", "Q1a", None, mock_transcribe)
        assert call_count == 1

        # Add stroke on a different line
        call_count = 0
        strokes2 = strokes + [_make_stroke((10, 30), (300, 310))]
        _, chunks2 = await transcribe_with_chunks(strokes2, "u", "d", "Q1a", chunks1, mock_transcribe)
        assert call_count == 1  # only the new cluster transcribed
