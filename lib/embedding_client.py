"""
HTTP client for Modal-hosted MiniLM embeddings.

Drop-in replacement for lib/embedding.py — same EmbeddingService interface,
but delegates to the Modal CPU endpoint instead of running locally.
No torch/sentence-transformers dependencies needed.
"""

import os
from typing import Union

import requests

MODAL_EMBED_URL = os.environ.get("MODAL_EMBED_URL", "")

_embedding_service = None


class EmbeddingService:
    """Service for generating text embeddings via Modal endpoint."""

    MODEL_NAME = "all-MiniLM-L6-v2"
    DIMENSIONS = 384

    def embed(
        self,
        texts: Union[str, list[str]],
        normalize: bool = True,
    ) -> list[list[float]]:
        """Generate embeddings by calling the Modal endpoint."""
        if isinstance(texts, str):
            texts = [texts]

        resp = requests.post(
            MODAL_EMBED_URL,
            json={"texts": texts, "normalize": normalize},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()["embeddings"]

    @property
    def model_name(self) -> str:
        return self.MODEL_NAME

    @property
    def dimensions(self) -> int:
        return self.DIMENSIONS


def get_embedding_service() -> EmbeddingService:
    """Get the global embedding service singleton."""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service
