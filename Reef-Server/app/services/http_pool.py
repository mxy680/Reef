"""Shared httpx.AsyncClient for connection pooling."""
import httpx

_client: httpx.AsyncClient | None = None


def init_pool(client: httpx.AsyncClient) -> None:
    global _client
    _client = client


def get_client() -> httpx.AsyncClient:
    if _client is None:
        raise RuntimeError("HTTP pool not initialized — call init_pool() first")
    return _client
