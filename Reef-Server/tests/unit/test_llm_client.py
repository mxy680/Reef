"""Unit tests for lib/llm_client.py — LLMClient.generate and generate_stream."""

import base64
import json

import httpx
import respx

from lib.llm_client import LLMClient
from tests.helpers import make_chat_completion, make_sse_stream

COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions"


class TestGenerate:
    @respx.mock
    def test_text_only_prompt(self):
        route = respx.post(COMPLETIONS_URL).mock(
            return_value=httpx.Response(200, json=make_chat_completion("response"))
        )

        client = LLMClient(api_key="fake")
        client.generate("hello")

        body = json.loads(route.calls[0].request.content)
        messages = body["messages"]
        assert len(messages) == 1
        assert messages[0]["role"] == "user"
        assert messages[0]["content"][0] == {"type": "text", "text": "hello"}

    @respx.mock
    def test_with_images(self):
        route = respx.post(COMPLETIONS_URL).mock(return_value=httpx.Response(200, json=make_chat_completion("ok")))

        client = LLMClient(api_key="fake")
        client.generate("describe", images=[b"fake_jpg"])

        body = json.loads(route.calls[0].request.content)
        messages = body["messages"]
        user_content = messages[-1]["content"]

        expected_b64 = base64.b64encode(b"fake_jpg").decode()
        image_block = {
            "type": "image_url",
            "image_url": {"url": f"data:image/jpeg;base64,{expected_b64}"},
        }
        assert image_block in user_content

    @respx.mock
    def test_with_response_schema(self):
        schema = {"type": "object", "properties": {"a": {"type": "string"}}}

        route = respx.post(COMPLETIONS_URL).mock(return_value=httpx.Response(200, json=make_chat_completion("{}")))

        client = LLMClient(api_key="fake")
        client.generate("go", response_schema=schema)

        body = json.loads(route.calls[0].request.content)
        assert "response_format" in body
        fmt = body["response_format"]
        assert fmt["type"] == "json_schema"
        assert "json_schema" in fmt
        assert fmt["json_schema"]["name"] == "response"
        assert fmt["json_schema"]["strict"] is True

    @respx.mock
    def test_system_message(self):
        route = respx.post(COMPLETIONS_URL).mock(return_value=httpx.Response(200, json=make_chat_completion("ok")))

        client = LLMClient(api_key="fake")
        client.generate("hello", system_message="be helpful")

        body = json.loads(route.calls[0].request.content)
        messages = body["messages"]
        assert messages[0] == {"role": "system", "content": "be helpful"}

    @respx.mock
    def test_temperature_passed(self):
        route = respx.post(COMPLETIONS_URL).mock(return_value=httpx.Response(200, json=make_chat_completion("ok")))

        client = LLMClient(api_key="fake")
        client.generate("hello", temperature=0.5)

        body = json.loads(route.calls[0].request.content)
        assert body["temperature"] == 0.5

    @respx.mock
    def test_returns_content(self):
        respx.post(COMPLETIONS_URL).mock(return_value=httpx.Response(200, json=make_chat_completion("the answer")))

        client = LLMClient(api_key="fake")
        result = client.generate("question")

        assert result == "the answer"


class TestGenerateStream:
    @respx.mock
    def test_yields_text_chunks(self):
        respx.post(COMPLETIONS_URL).mock(
            return_value=httpx.Response(
                200,
                content=make_sse_stream(["a", "b", "c"]),
                headers={"content-type": "text/event-stream"},
            )
        )

        client = LLMClient(api_key="fake")
        result = list(client.generate_stream("hi"))

        assert result == ["a", "b", "c"]

    @respx.mock
    def test_skips_none_content(self):
        respx.post(COMPLETIONS_URL).mock(
            return_value=httpx.Response(
                200,
                content=make_sse_stream(["hello", None, "world"]),
                headers={"content-type": "text/event-stream"},
            )
        )

        client = LLMClient(api_key="fake")
        result = list(client.generate_stream("hi"))

        assert result == ["hello", "world"]
