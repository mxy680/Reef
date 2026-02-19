"""Integration tests for /ai/embed?mode=prod — production embedding endpoint."""
from unittest.mock import MagicMock, PropertyMock, patch


class TestEmbedProd:
    def _mock_service(self, num_texts=1):
        mock_svc = MagicMock()
        mock_svc.embed.return_value = [[0.1] * 384] * num_texts
        type(mock_svc).model_name = PropertyMock(return_value="all-MiniLM-L6-v2")
        type(mock_svc).dimensions = PropertyMock(return_value=384)
        return mock_svc

    @patch("api.index.get_embedding_service")
    def test_response_shape(self, mock_get_svc, client):
        mock_get_svc.return_value = self._mock_service(1)
        resp = client.post("/ai/embed?mode=prod", json={"texts": ["hello"]})
        assert resp.status_code == 200
        data = resp.json()
        assert data["mode"] == "prod"
        assert data["model"] == "all-MiniLM-L6-v2"
        assert len(data["embeddings"]) == 1

    @patch("api.index.get_embedding_service")
    def test_correct_dimensions_and_count(self, mock_get_svc, client):
        mock_get_svc.return_value = self._mock_service(2)
        resp = client.post("/ai/embed?mode=prod", json={"texts": ["hello", "world"]})
        data = resp.json()
        assert data["dimensions"] == 384
        assert data["count"] == 2
        assert len(data["embeddings"]) == 2
        assert len(data["embeddings"][0]) == 384

    @patch("api.index.get_embedding_service")
    def test_normalization_flag(self, mock_get_svc, client):
        mock_svc = self._mock_service(1)
        mock_get_svc.return_value = mock_svc
        client.post("/ai/embed?mode=prod", json={"texts": ["test"], "normalize": False})
        mock_svc.embed.assert_called_once_with(["test"], normalize=False)
