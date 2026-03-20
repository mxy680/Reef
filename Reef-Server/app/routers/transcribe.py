import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.auth import get_current_user, AuthenticatedUser
from app.config import settings
from app.services.mathpix import MathpixClient

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai", tags=["ai"])


class TranscribeRequest(BaseModel):
    image_base64: str


class TranscribeResponse(BaseModel):
    latex: str


@router.post("/transcribe-handwriting", response_model=TranscribeResponse)
async def transcribe_handwriting(
    req: TranscribeRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> TranscribeResponse:
    try:
        client = MathpixClient(settings.mathpix_app_id, settings.mathpix_app_key)
        latex = await client.transcribe_image(req.image_base64)
        return TranscribeResponse(latex=latex)
    except Exception as e:
        log.error(f"Transcription failed for user {user.id}: {e}")
        raise HTTPException(status_code=502, detail=f"Transcription failed: {str(e)}")
