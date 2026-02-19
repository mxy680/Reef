"""Integration tests for /ai/embed?mode=prod — production embedding endpoint."""
import json

import responses

import lib.embedding_client
from tests.helpers import make_embed_response

MODAL_EMBED_URL = "https://fake-modal-embed.example.com/embed"


@responses.activate
def test_response_shape(client, monkeypatch):
    monkeypatch.setattr("lib.embedding_client.MODAL_EMBED_URL", MODAL_EMBED_URL)
    lib.embedding_client._embedding_service = None
    responses.add(responses.POST, MODAL_EMBED_URL, json=make_embed_response(1), status=200)

    resp = client.post("/ai/embed?mode=prod", json={"texts": ["hello"]})

    assert resp.status_code == 200
    data = resp.json()
    assert data["mode"] == "prod"
    assert data["model"] == "all-MiniLM-L6-v2"
    assert len(data["embeddings"]) == 1


@responses.activate
def test_correct_dimensions_and_count(client, monkeypatch):
    monkeypatch.setattr("lib.embedding_client.MODAL_EMBED_URL", MODAL_EMBED_URL)
    lib.embedding_client._embedding_service = None
    responses.add(responses.POST, MODAL_EMBED_URL, json=make_embed_response(2), status=200)

    resp = client.post("/ai/embed?mode=prod", json={"texts": ["hello", "world"]})

    data = resp.json()
    assert data["dimensions"] == 384
    assert data["count"] == 2
    assert len(data["embeddings"]) == 2
    assert len(data["embeddings"][0]) == 384


@responses.activate
def test_normalization_flag(client, monkeypatch):
    monkeypatch.setattr("lib.embedding_client.MODAL_EMBED_URL", MODAL_EMBED_URL)
    lib.embedding_client._embedding_service = None
    responses.add(responses.POST, MODAL_EMBED_URL, json=make_embed_response(1), status=200)

    client.post("/ai/embed?mode=prod", json={"texts": ["test"], "normalize": False})

    body = json.loads(responses.calls[0].request.body)
    assert body["normalize"] is False
