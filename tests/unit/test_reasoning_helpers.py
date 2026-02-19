"""Unit tests for reasoning helper functions: _get_part_order, _is_later_part."""

from lib.reasoning import _get_part_order, _is_later_part


class TestGetPartOrder:
    def test_flat_parts(self):
        parts = [
            {"label": "a", "text": "Find x"},
            {"label": "b", "text": "Find y"},
            {"label": "c", "text": "Find z"},
        ]
        assert _get_part_order(parts) == ["a", "b", "c"]

    def test_nested_parts(self):
        parts = [
            {"label": "a", "text": "Part a", "parts": [
                {"label": "i", "text": "Sub i"},
                {"label": "ii", "text": "Sub ii"},
            ]},
            {"label": "b", "text": "Part b"},
        ]
        assert _get_part_order(parts) == ["a", "a.i", "a.ii", "b"]

    def test_empty_parts(self):
        assert _get_part_order([]) == []

    def test_missing_label(self):
        parts = [{"text": "no label"}, {"label": "a", "text": "has label"}]
        assert _get_part_order(parts) == ["a"]

    def test_parts_without_subparts_key(self):
        parts = [{"label": "a", "text": "Part a"}, {"label": "b", "text": "Part b"}]
        assert _get_part_order(parts) == ["a", "b"]


class TestIsLaterPart:
    def test_later_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("c", "b", order) is True

    def test_earlier_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("a", "b", order) is False

    def test_same_part(self):
        order = ["a", "b", "c"]
        assert _is_later_part("b", "b", order) is False

    def test_label_not_in_order(self):
        order = ["a", "b"]
        assert _is_later_part("c", "b", order) is False

    def test_active_not_in_order(self):
        order = ["a", "b"]
        assert _is_later_part("a", "c", order) is False

    def test_nested_ordering(self):
        order = ["a", "a.i", "a.ii", "b"]
        assert _is_later_part("b", "a.i", order) is True
        assert _is_later_part("a", "a.ii", order) is False
