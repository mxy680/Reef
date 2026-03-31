import asyncio
import logging
from contextlib import asynccontextmanager
import httpx
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import health
from app.routers import reconstruct_v2
from app.routers import fit_shape
from app.routers import bug_report
from app.routers import transcribe_audio
from app.routers import tutor_evaluate
from app.routers import demo_problem
from app.routers import generate_question
from app.config import settings
from app.services.cancellation import get_in_flight_ids
from app.services.http_pool import init_pool
from app.services.progress import update_document_status

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
log = logging.getLogger(__name__)

# Strong references to background tasks (prevent GC)
_background_tasks: set[asyncio.Task] = set()


async def _recover_stale_documents():
    """Mark any documents stuck in 'processing' as failed on startup."""
    try:
        import httpx
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{settings.supabase_url}/rest/v1/documents",
                params={"status": "eq.processing", "select": "id"},
                headers={
                    "apikey": settings.supabase_service_role_key,
                    "Authorization": f"Bearer {settings.supabase_service_role_key}",
                },
                timeout=10,
            )
            if resp.status_code == 200:
                stale = resp.json()
                for doc in stale:
                    await update_document_status(
                        doc["id"],
                        status="failed",
                        error_message="Server restarted — document was not fully processed. Please retry.",
                    )
                if stale:
                    log.warning("Recovered %d stale documents", len(stale))
    except Exception as e:
        log.warning("Stale document recovery failed: %s", e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info("Reef server starting")
    await _recover_stale_documents()
    app.state.http = httpx.AsyncClient(
        timeout=httpx.Timeout(30.0, connect=5.0),
        limits=httpx.Limits(max_connections=100, max_keepalive_connections=20),
    )
    init_pool(app.state.http)
    yield
    log.info("Reef server shutting down")
    await app.state.http.aclose()
    # Mark in-flight documents as failed
    for doc_id in get_in_flight_ids():
        try:
            await update_document_status(
                doc_id,
                status="failed",
                error_message="Server shutting down — document was not fully processed. Please retry.",
            )
        except Exception:
            pass


# TODO: Add slowapi rate limiting before production launch
app = FastAPI(title="Reef Server", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://studyreef.com", "https://www.studyreef.com", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(bug_report.router)
app.include_router(reconstruct_v2.router)
app.include_router(fit_shape.router)
app.include_router(transcribe_audio.router)
app.include_router(tutor_evaluate.router)
app.include_router(demo_problem.router)
app.include_router(generate_question.router)
