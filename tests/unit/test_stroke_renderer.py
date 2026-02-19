"""Unit tests for lib.stroke_renderer.render_strokes."""

from io import BytesIO

from PIL import Image

from lib.stroke_renderer import render_strokes


class TestRenderStrokes:
    def test_empty_strokes_blank_png(self):
        data = render_strokes([])
        img = Image.open(BytesIO(data))
        assert img.size == (512, 128)
        assert img.format == "PNG"

    def test_single_stroke_valid_png(self):
        strokes = [{"points": [{"x": 0, "y": 0}, {"x": 100, "y": 100}]}]
        data = render_strokes(strokes)
        assert data[:4] == b"\x89PNG"

    def test_width_always_512(self):
        strokes = [{"points": [{"x": 0, "y": 0}, {"x": 500, "y": 200}]}]
        data = render_strokes(strokes)
        img = Image.open(BytesIO(data))
        assert img.size[0] == 512

    def test_height_min_128(self):
        strokes = [{"points": [{"x": 0, "y": 0}, {"x": 10, "y": 1}]}]
        data = render_strokes(strokes)
        img = Image.open(BytesIO(data))
        assert img.size[1] >= 128

    def test_single_point_stroke_no_crash(self):
        strokes = [{"points": [{"x": 50, "y": 50}]}]
        data = render_strokes(strokes)
        img = Image.open(BytesIO(data))
        assert img.size[0] == 512
