import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import health, reconstruct, reconstruct_v2, transcribe, ws
from app.services.cancellation import get_in_flight_ids
from app.services.progress import update_document_status

logger = logging.getLogger(__name__)


async def _recover_stale_documents():
    """Mark documents stuck in 'processing' as 'failed' on startup.

    Any document still 'processing' at boot is an orphan from a previous
    server instance that crashed or was killed before shutdown could run.
    """
    if not settings.supabase_url or not settings.supabase_service_role_key:
        return
    try:
        url = (
            f"{settings.supabase_url}/rest/v1/documents"
            f"?status=eq.processing&select=id"
        )
        headers = {
            "apikey": settings.supabase_service_role_key,
            "Authorization": f"Bearer {settings.supabase_service_role_key}",
        }
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=headers, timeout=10)
            resp.raise_for_status()
            stuck_docs = resp.json()

        if not stuck_docs:
            logger.info("Startup recovery: no stale documents found")
            return

        logger.warning(f"Startup recovery: found {len(stuck_docs)} stale document(s)")
        for doc in stuck_docs:
            doc_id = doc["id"]
            await update_document_status(
                doc_id,
                status="failed",
                error_message="Server restarted — document was not fully processed",
                status_message=None,
            )
            logger.info(f"Startup recovery: marked {doc_id} as failed")
    except Exception as e:
        logger.error(f"Startup recovery failed: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Reef Server starting on {settings.host}:{settings.port}")
    await _recover_stale_documents()
    yield

    # Graceful shutdown: mark in-flight documents as failed
    in_flight = get_in_flight_ids()
    if in_flight:
        logger.warning(f"Shutting down with {len(in_flight)} in-flight document(s): {in_flight}")
        for doc_id in in_flight:
            try:
                await update_document_status(
                    doc_id,
                    status="failed",
                    error_message="Server restarted during processing",
                    status_message=None,
                )
            except Exception as e:
                logger.error(f"Failed to mark {doc_id} as failed on shutdown: {e}")
    logger.info("Reef Server shut down")


app = FastAPI(
    title="Reef Server",
    version="0.1.0",
    lifespan=lifespan,
    docs_url="/docs" if settings.debug else None,
    redoc_url=None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://studyreef.com",
        "https://www.studyreef.com",
        "http://localhost:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(reconstruct.router)
app.include_router(reconstruct_v2.router)
app.include_router(transcribe.router)
app.include_router(ws.router)
