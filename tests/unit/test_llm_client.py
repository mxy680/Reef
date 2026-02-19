"""Unit tests for lib/llm_client.py — LLMClient.generate and generate_stream."""
import base64
from unittest.mock import MagicMock, patch

from lib.llm_client import LLMClient


def _make_client(mock_openai, mock_async_openai):
    """Instantiate LLMClient with fake credentials under active mocks."""
    return LLMClient(api_key="fake")


class TestGenerate:
    def test_text_only_prompt(self):
        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "response"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            result = client.generate("hello")

        assert result == "response"

    def test_with_images(self):
        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "ok"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            client.generate("describe", images=[b"fake_jpg"])

            call_kwargs = mock_instance.chat.completions.create.call_args[1]
            messages = call_kwargs["messages"]
            user_content = messages[-1]["content"]

        expected_b64 = base64.b64encode(b"fake_jpg").decode()
        image_block = {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{expected_b64}"}}
        assert image_block in user_content

    def test_with_response_schema(self):
        schema = {"type": "object", "properties": {"a": {"type": "string"}}}

        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "{}"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            client.generate("go", response_schema=schema)

            call_kwargs = mock_instance.chat.completions.create.call_args[1]

        assert "response_format" in call_kwargs
        fmt = call_kwargs["response_format"]
        assert fmt["type"] == "json_schema"
        assert "json_schema" in fmt
        assert fmt["json_schema"]["name"] == "response"
        assert fmt["json_schema"]["strict"] is True

    def test_system_message(self):
        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "ok"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            client.generate("hello", system_message="be helpful")

            call_kwargs = mock_instance.chat.completions.create.call_args[1]
            messages = call_kwargs["messages"]

        assert messages[0] == {"role": "system", "content": "be helpful"}

    def test_temperature_passed(self):
        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "ok"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            client.generate("hello", temperature=0.5)

            call_kwargs = mock_instance.chat.completions.create.call_args[1]

        assert call_kwargs["temperature"] == 0.5

    def test_returns_content(self):
        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_response = MagicMock()
            mock_response.choices[0].message.content = "the answer"
            mock_instance.chat.completions.create.return_value = mock_response

            client = LLMClient(api_key="fake")
            result = client.generate("question")

        assert result == "the answer"


class TestGenerateStream:
    def _make_chunk(self, content):
        chunk = MagicMock()
        delta = MagicMock()
        delta.content = content
        choice = MagicMock()
        choice.delta = delta
        chunk.choices = [choice]
        return chunk

    def test_yields_text_chunks(self):
        chunks = [self._make_chunk("a"), self._make_chunk("b"), self._make_chunk("c")]

        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_instance.chat.completions.create.return_value = iter(chunks)

            client = LLMClient(api_key="fake")
            result = list(client.generate_stream("hi"))

        assert result == ["a", "b", "c"]

    def test_skips_none_content(self):
        chunks = [self._make_chunk("hello"), self._make_chunk(None), self._make_chunk("world")]

        with patch("lib.llm_client.OpenAI") as mock_openai, \
             patch("lib.llm_client.AsyncOpenAI"):
            mock_instance = mock_openai.return_value
            mock_instance.chat.completions.create.return_value = iter(chunks)

            client = LLMClient(api_key="fake")
            result = list(client.generate_stream("hi"))

        assert result == ["hello", "world"]
