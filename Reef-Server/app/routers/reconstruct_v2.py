"""POST /ai/v2/reconstruct-document — Mathpix-based document processing pipeline.

Replaces the Surya + LLM extraction approach with Mathpix OCR for more
accurate math recognition and structured output.
"""

import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.services.cancellation import (
    cancel as cancel_document,
    cleanup as cancel_cleanup,
    is_cancelled,
    register as cancel_register,
)
from app.services.progress import update_document_status, update_progress
from app.services.storage import download_document_pdf, upload_document_pdf

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/ai/v2", tags=["reconstruct-v2"])


class ReconstructRequest(BaseModel):
    document_id: str


@router.post("/reconstruct-document", status_code=202)
async def reconstruct_document(
    body: ReconstructRequest,
    background_tasks: BackgroundTasks,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Kick off the Mathpix-based reconstruction pipeline as a background task."""
    document_id = body.document_id

    cancel_register(document_id)

    background_tasks.add_task(
        _run_pipeline,
        document_id=document_id,
        user_id=user.id,
    )

    return JSONResponse(
        {"status": "processing", "document_id": document_id},
        status_code=202,
    )


@router.delete("/reconstruct-document/{document_id}")
async def cancel_reconstruction(
    document_id: str,
    user: AuthenticatedUser = Depends(get_current_user),
):
    """Cancel a running v2 pipeline."""
    cancel_document(document_id)
    return {"status": "cancelled", "document_id": document_id}


async def _run_pipeline(*, document_id: str, user_id: str) -> None:
    """Mathpix-based reconstruction pipeline.

    Stages (to be implemented):
    1. Download PDF from Supabase storage
    2. Send to Mathpix for OCR + math recognition
    3. Parse Mathpix structured output into Questions
    4. Compile LaTeX for each question
    5. Merge PDFs and upload result
    6. Generate answer keys
    """
    try:
        await update_document_status(document_id, status="processing")
        await update_progress(document_id, "Starting Mathpix pipeline...")

        # Stage 1: Download source PDF
        pdf_bytes = await download_document_pdf(user_id, document_id)
        if not pdf_bytes:
            raise RuntimeError("Could not download source PDF")

        await update_progress(document_id, "PDF downloaded, sending to Mathpix...")

        # TODO: Stage 2 — Mathpix OCR
        # TODO: Stage 3 — Parse into Questions
        # TODO: Stage 4 — Compile LaTeX
        # TODO: Stage 5 — Merge + upload
        # TODO: Stage 6 — Answer keys

        raise NotImplementedError("Mathpix pipeline stages not yet implemented")

    except NotImplementedError:
        await update_document_status(
            document_id,
            status="failed",
            error_message="Mathpix pipeline not yet implemented",
        )
    except asyncio.CancelledError:
        await update_document_status(
            document_id,
            status="failed",
            error_message="Processing was cancelled",
        )
    except Exception as e:
        logger.exception(f"v2 pipeline failed for {document_id}: {e}")
        await update_document_status(
            document_id,
            status="failed",
            error_message=str(e)[:500],
        )
    finally:
        cancel_cleanup(document_id)


# Required for CancelledError
import asyncio
