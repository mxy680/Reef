from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routers import health, ws


@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"Reef Server starting on {settings.host}:{settings.port}")
    yield
    print("Reef Server shutting down")


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
app.include_router(ws.router)
