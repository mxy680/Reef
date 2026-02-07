"""
Reef Server - Modal deployment with GPU acceleration.

Architecture:
- Single GPU container for ML inference
- Handles embeddings and PDF extraction

Deploy with: modal deploy modal_app.py
Test locally with: modal serve modal_app.py
"""

import modal

# Define the Modal app
app = modal.App("reef-server")

# Download models at build time
def download_models():
    import os
    os.environ["XDG_CACHE_HOME"] = "/cache"
    os.environ["HF_HOME"] = "/cache/huggingface"
    os.environ["TORCH_HOME"] = "/cache/torch"

    # Download sentence-transformers model
    print("[Build] Downloading sentence-transformers model...")
    from sentence_transformers import SentenceTransformer
    SentenceTransformer("all-MiniLM-L6-v2")

    print("[Build] All models downloaded!")

# Image with dependencies
unified_image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        # FastAPI dependencies
        "fastapi>=0.109.0",
        "httpx>=0.26.0",
        "python-dotenv>=1.0.0",
        "uvicorn>=0.27.0",
        # Embedding dependencies
        "sentence-transformers>=2.2.0",
        "torch",
        # Other
        "pydantic>=2.0.0",
        "numpy",
    )
    .run_function(download_models)
)


@app.cls(
    image=unified_image,
    gpu="T4",
    secrets=[modal.Secret.from_name("reef-secrets")],
    timeout=600,
    scaledown_window=60,
)
class ReefServer:
    """GPU-accelerated server."""

    @modal.enter()
    def setup(self):
        """Load models on container startup."""
        import os
        os.environ["XDG_CACHE_HOME"] = "/cache"
        os.environ["HF_HOME"] = "/cache/huggingface"
        os.environ["TORCH_HOME"] = "/cache/torch"

        print("[ReefServer] Loading embedding model...")
        from sentence_transformers import SentenceTransformer
        self.embedding_model = SentenceTransformer("all-MiniLM-L6-v2")

        print("[ReefServer] Ready!")

    @modal.asgi_app()
    def web_app(self):
        """FastAPI application."""
        from fastapi import FastAPI, HTTPException, Query
        from fastapi.middleware.cors import CORSMiddleware
        from pydantic import BaseModel

        class EmbedRequest(BaseModel):
            texts: str | list[str]
            normalize: bool = True

        class EmbedResponse(BaseModel):
            embeddings: list[list[float]]
            model: str
            dimensions: int
            count: int
            mode: str

        class ExtractQuestionsRequest(BaseModel):
            pdf_base64: str
            note_id: str

        class ExtractQuestionsResponse(BaseModel):
            note_id: str
            message: str

        server = self

        api = FastAPI(
            title="Reef Server",
            description="GPU-accelerated embedding and PDF extraction service",
            version="1.0.0"
        )

        api.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

        @api.get("/health")
        async def health_check():
            return {"status": "healthy", "service": "reef-server-modal", "version": "1.0.0"}

        @api.post("/ai/embed", response_model=EmbedResponse)
        async def ai_embed(request_body: EmbedRequest, mode: str = Query(default="prod")):
            texts = request_body.texts if isinstance(request_body.texts, list) else [request_body.texts]

            if mode == "mock":
                import random
                embeddings = [[random.random() for _ in range(384)] for _ in texts]
                return EmbedResponse(
                    embeddings=embeddings, model="all-MiniLM-L6-v2",
                    dimensions=384, count=len(texts), mode="mock"
                )

            embeddings = server.embedding_model.encode(
                texts, normalize_embeddings=request_body.normalize, convert_to_numpy=True
            ).tolist()

            return EmbedResponse(
                embeddings=embeddings, model="all-MiniLM-L6-v2",
                dimensions=384, count=len(texts), mode="prod"
            )

        @api.post("/ai/extract-questions", response_model=ExtractQuestionsResponse)
        async def ai_extract_questions(request_body: ExtractQuestionsRequest):
            """
            Extract questions from a PDF document.

            TODO: Implement extraction pipeline.
            """
            return ExtractQuestionsResponse(
                note_id=request_body.note_id,
                message="PDF received. Extraction pipeline not yet implemented."
            )

        return api
