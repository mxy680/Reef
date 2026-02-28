"""Unit tests for lib.region_extractor._collect_expected_labels."""

from lib.region_extractor import _collect_expected_labels


class TestCollectExpectedLabels:
    def test_flat(self):
        parts = [{"label": "a"}, {"label": "b"}]
        assert _collect_expected_labels(parts) == ["a", "b"]

    def test_nested(self):
        parts = [
            {"label": "a", "parts": [{"label": "i"}, {"label": "ii"}]},
            {"label": "b"},
        ]
        assert _collect_expected_labels(parts) == ["a", "a.i", "a.ii", "b"]

    def test_deep_nesting(self):
        parts = [
            {
                "label": "a",
                "parts": [
                    {
                        "label": "i",
                        "parts": [{"label": "1"}],
                    }
                ],
            }
        ]
        assert _collect_expected_labels(parts) == ["a", "a.i", "a.i.1"]

    def test_empty(self):
        assert _collect_expected_labels([]) == []

    def test_with_prefix(self):
        parts = [{"label": "a"}, {"label": "b"}]
        assert _collect_expected_labels(parts, prefix="x") == ["x.a", "x.b"]
