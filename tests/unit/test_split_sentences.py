"""Tests for api/tts_stream.py -> _split_sentences()."""

from api.tts_stream import _split_sentences


class TestSplitSentences:
    def test_single_sentence_no_trailing_punct(self):
        assert _split_sentences("hello world") == ["hello world"]

    def test_two_sentences(self):
        assert _split_sentences("Hello. World?") == ["Hello.", "World?"]

    def test_empty_string(self):
        assert _split_sentences("") == []

    def test_mixed_delimiters(self):
        result = _split_sentences("Yes! Really? Sure.")
        assert result == ["Yes!", "Really?", "Sure."]

    def test_no_split_punct_at_end(self):
        # Punctuation at end of string with no following text should not split
        assert _split_sentences("Hello world.") == ["Hello world."]

    def test_whitespace_only(self):
        assert _split_sentences("   ") == []

    def test_multiple_spaces_between(self):
        result = _split_sentences("First.  Second.")
        assert result == ["First.", "Second."]
