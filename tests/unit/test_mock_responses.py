"""Unit tests for lib.mock_responses.get_mock_embedding."""

import math

from lib.mock_responses import get_mock_embedding


class TestGetMockEmbedding:
    def test_default_params(self):
        result = get_mock_embedding()
        assert len(result) == 1
        assert len(result[0]) == 384

    def test_custom_count_and_dims(self):
        result = get_mock_embedding(count=3, dimensions=128)
        assert len(result) == 3
        for vec in result:
            assert len(vec) == 128

    def test_l2_normalized(self):
        result = get_mock_embedding(count=5, dimensions=384)
        for vec in result:
            norm = math.sqrt(sum(x * x for x in vec))
            assert 0.99 < norm < 1.01

    def test_different_each_call(self):
        a = get_mock_embedding()
        b = get_mock_embedding()
        assert a != b

    def test_zero_count(self):
        result = get_mock_embedding(count=0)
        assert result == []
