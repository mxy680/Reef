"""
Modal serverless CPU endpoint for MiniLM text embeddings.

Deploy: modal deploy modal/embeddings.py
Test:   curl -X POST <url> -d '{"texts":["hello world"]}'
"""

import modal

app = modal.App("reef-embeddings")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("torch", extra_index_url="https://download.pytorch.org/whl/cpu")
    .pip_install("sentence-transformers>=3.0.0", "fastapi[standard]")
    .run_commands(
        # Pre-download the model into the image
        "python -c \"from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2'); print('Model cached')\""
    )
)


@app.cls(
    image=image,
    scaledown_window=300,
)
@modal.concurrent(max_inputs=4)
class Embeddings:
    @modal.enter()
    def load_model(self):
        from sentence_transformers import SentenceTransformer

        self.model = SentenceTransformer("all-MiniLM-L6-v2")
        print("MiniLM embedding model loaded")

    @modal.fastapi_endpoint(method="POST")
    def embed(self, request: dict):
        """Generate embeddings for a list of texts."""
        texts = request.get("texts", [])
        normalize = request.get("normalize", True)

        if not texts:
            return {"error": "No texts provided"}

        if isinstance(texts, str):
            texts = [texts]

        embeddings = self.model.encode(
            texts,
            normalize_embeddings=normalize,
            convert_to_numpy=True,
        )

        return {
            "embeddings": embeddings.tolist(),
            "model": "all-MiniLM-L6-v2",
            "dimensions": 384,
            "count": len(texts),
        }
