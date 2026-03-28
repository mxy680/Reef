"""POST /ai/simulation/start|continue|stop — visual student simulation endpoints.

Drives a simulated student writing LaTeX strokes step-by-step on the canvas.
Strokes are pushed to the connected iOS client via WebSocket.

Only active when SIMULATION_ENABLED=true.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass, field

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.auth import AuthenticatedUser, get_current_user
from app.config import settings
from app.models.answer_key import QuestionAnswer, Step
from app.services import ws_manager
from app.services.latex2strokes import latex_to_strokes
from app.services.student_llm import generate_student_work

log = logging.getLogger(__name__)

router = APIRouter(prefix="/ai/simulation", tags=["simulation"])

# ---------------------------------------------------------------------------
# In-memory simulation state
# ---------------------------------------------------------------------------

_MAX_RETRIES = 3
_LINE_HEIGHT = 60.0   # vertical gap between work lines (canvas units)
_ORIGIN_X = 50.0
_ORIGIN_Y_START = 100.0


@dataclass
class SimulationState:
    doc_id: str
    question_number: int
    part_label: str | None
    step_index: int
    retry_count: int
    personality: str
    question_text: str
    answer_key_steps: list[Step]
    accumulated_work: list[str] = field(default_factory=list)
    # Tracks cumulative Y so each new line renders below the previous one
    current_y: float = _ORIGIN_Y_START


# user_id -> SimulationState
_simulations: dict[str, SimulationState] = {}

# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class SimulationStartRequest(BaseModel):
    doc_id: str
    question_number: int
    part_label: str | None = None
    personality: str = "mistake_prone"


class SimulationContinueRequest(BaseModel):
    tutor_feedback: str | None = None
    """Feedback from the most recent tutor evaluation (mistake explanation or None)."""


class SimulationStartResponse(BaseModel):
    status: str
    step_index: int
    total_steps: int


class SimulationContinueResponse(BaseModel):
    status: str
    step_index: int
    total_steps: int


class SimulationStopResponse(BaseModel):
    status: str


class InjectStrokesRequest(BaseModel):
    latex: str
    origin_x: float = 50.0
    origin_y: float = 100.0


class InjectStrokesResponse(BaseModel):
    status: str
    strokes_count: int


# ---------------------------------------------------------------------------
# Supabase helpers
# ---------------------------------------------------------------------------


def _supabase_headers() -> dict[str, str]:
    return {
        "apikey": settings.supabase_service_role_key,
        "Authorization": f"Bearer {settings.supabase_service_role_key}",
    }


async def _fetch_answer_key_steps(
    doc_id: str,
    question_number: int,
    part_label: str | None,
    user_id: str,
) -> tuple[list[Step], str]:
    """Fetch steps + question text for the given question/part. Verifies ownership."""
    headers = _supabase_headers()

    async with httpx.AsyncClient(timeout=10) as client:
        # Verify document ownership
        doc_resp = await client.get(
            f"{settings.supabase_url}/rest/v1/documents",
            params={"id": f"eq.{doc_id}", "user_id": f"eq.{user_id}", "select": "id"},
            headers=headers,
        )
        doc_resp.raise_for_status()
        if not doc_resp.json():
            raise HTTPException(status_code=403, detail="Access denied")

        # Fetch answer key
        ak_resp = await client.get(
            f"{settings.supabase_url}/rest/v1/answer_keys",
            params={
                "document_id": f"eq.{doc_id}",
                "question_number": f"eq.{question_number}",
                "select": "answer_text,question_json",
            },
            headers=headers,
        )
        ak_resp.raise_for_status()

    rows = ak_resp.json()
    if not rows:
        raise HTTPException(status_code=404, detail="Answer key not found")

    answer_key = QuestionAnswer.model_validate_json(rows[0]["answer_text"])
    question_json = rows[0].get("question_json") or {}

    # Build question text
    q_text = question_json.get("text", f"Question {question_number}")
    if part_label:
        for part in question_json.get("parts", []):
            if part.get("label") == part_label:
                part_text = part.get("text", "")
                if part_text:
                    q_text = f"{q_text}\nPart ({part_label}): {part_text}"
                break

    # Resolve steps for the given part (mirrors tutor_evaluate._resolve_steps)
    steps = _resolve_steps(answer_key, part_label)
    if not steps:
        raise HTTPException(status_code=404, detail="No steps found for this question/part")

    return steps, q_text


def _resolve_steps(answer_key: QuestionAnswer, part_label: str | None) -> list[Step]:
    """Mirror of tutor_evaluate._resolve_steps for consistency."""
    if part_label is None:
        if answer_key.parts:
            first = answer_key.parts[0]
            if first.steps:
                return first.steps
            if first.parts and first.parts[0].steps:
                return first.parts[0].steps
        return answer_key.steps

    for part in answer_key.parts:
        if part.label == part_label:
            return part.steps
        for sub in part.parts:
            if sub.label == part_label:
                return sub.steps

    return []


# ---------------------------------------------------------------------------
# Stroke generation + WebSocket delivery
# ---------------------------------------------------------------------------


async def _generate_and_send_strokes(
    user_id: str,
    state: SimulationState,
    tutor_feedback: str | None = None,
) -> bool:
    """Generate student work for the current step and send strokes via WebSocket.

    Returns True when all steps are complete (simulation done).
    """
    steps = state.answer_key_steps
    step = steps[state.step_index]

    # Generate student work via LLM (or fall back to answer key after max retries)
    if state.retry_count >= _MAX_RETRIES:
        log.info(
            f"[simulate] Max retries reached for {user_id} step {state.step_index}, "
            "using answer key work"
        )
        latex = step.work
        reasoning = "Used answer key after max retries"
    else:
        try:
            student_response = await generate_student_work(
                question_text=state.question_text,
                step_index=state.step_index,
                total_steps=len(steps),
                step_description=step.description,
                step_expected_work=step.work,
                personality=state.personality,
                tutor_feedback=tutor_feedback,
                previous_work=state.accumulated_work if state.accumulated_work else None,
            )
            latex = student_response.latex
            reasoning = student_response.reasoning
        except Exception as e:
            log.warning(f"[simulate] Student LLM failed for {user_id}: {e}, falling back to answer key")
            latex = step.work
            reasoning = "LLM error — used answer key"

    # Convert LaTeX to strokes, placing at the current Y offset
    strokes = latex_to_strokes(
        latex,
        origin_x=_ORIGIN_X,
        origin_y=state.current_y,
    )

    # Send strokes via WebSocket
    sent = await ws_manager.send_to_user(user_id, {
        "type": "simulation_strokes",
        "strokes": strokes,
        "step_index": state.step_index,
        "latex": latex,
        "reasoning": reasoning,
    })

    if not sent:
        log.warning(f"[simulate] No WebSocket connection for {user_id}")

    # Update accumulated work and Y offset for the next line
    state.accumulated_work.append(latex)
    state.current_y += _LINE_HEIGHT

    return False  # not complete yet; caller advances step_index if tutor confirms


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/start", response_model=SimulationStartResponse)
async def simulation_start(
    body: SimulationStartRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> SimulationStartResponse:
    if not settings.simulation_enabled:
        raise HTTPException(status_code=404, detail="Not found")

    steps, question_text = await _fetch_answer_key_steps(
        body.doc_id, body.question_number, body.part_label, user.id
    )

    state = SimulationState(
        doc_id=body.doc_id,
        question_number=body.question_number,
        part_label=body.part_label,
        step_index=0,
        retry_count=0,
        personality=body.personality,
        question_text=question_text,
        answer_key_steps=steps,
    )
    _simulations[user.id] = state

    log.info(
        f"[simulate] Starting simulation for {user.id}: "
        f"doc={body.doc_id} Q{body.question_number} "
        f"part={body.part_label} steps={len(steps)} personality={body.personality}"
    )

    await _generate_and_send_strokes(user.id, state)

    return SimulationStartResponse(
        status="running",
        step_index=0,
        total_steps=len(steps),
    )


@router.post("/continue", response_model=SimulationContinueResponse)
async def simulation_continue(
    body: SimulationContinueRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> SimulationContinueResponse:
    if not settings.simulation_enabled:
        raise HTTPException(status_code=404, detail="Not found")

    state = _simulations.get(user.id)
    if state is None:
        raise HTTPException(status_code=404, detail="No active simulation")

    steps = state.answer_key_steps

    if body.tutor_feedback:
        # Tutor flagged a mistake — retry the same step with feedback
        state.retry_count += 1
        log.info(
            f"[simulate] Retry {state.retry_count}/{_MAX_RETRIES} for {user.id} "
            f"step {state.step_index} with feedback: {body.tutor_feedback[:80]}"
        )
        await _generate_and_send_strokes(user.id, state, tutor_feedback=body.tutor_feedback)
    else:
        # Tutor confirmed step correct — advance to next step
        state.step_index += 1
        state.retry_count = 0

        if state.step_index >= len(steps):
            # All steps done
            log.info(f"[simulate] Simulation complete for {user.id}")
            await ws_manager.send_to_user(user.id, {"type": "simulation_complete"})
            _simulations.pop(user.id, None)
            return SimulationContinueResponse(
                status="complete",
                step_index=state.step_index,
                total_steps=len(steps),
            )

        log.info(
            f"[simulate] Advancing to step {state.step_index + 1}/{len(steps)} for {user.id}"
        )
        await _generate_and_send_strokes(user.id, state)

    return SimulationContinueResponse(
        status="running",
        step_index=state.step_index,
        total_steps=len(steps),
    )


@router.post("/stop", response_model=SimulationStopResponse)
async def simulation_stop(
    user: AuthenticatedUser = Depends(get_current_user),
) -> SimulationStopResponse:
    if not settings.simulation_enabled:
        raise HTTPException(status_code=404, detail="Not found")

    removed = _simulations.pop(user.id, None)
    if removed:
        log.info(f"[simulate] Stopped simulation for {user.id}")
    else:
        log.info(f"[simulate] Stop called but no active simulation for {user.id}")

    return SimulationStopResponse(status="stopped")


@router.post("/inject", response_model=InjectStrokesResponse)
async def simulation_inject(
    body: InjectStrokesRequest,
    user: AuthenticatedUser = Depends(get_current_user),
) -> InjectStrokesResponse:
    """Inject LaTeX as strokes onto the user's canvas via WebSocket.

    No simulation state needed — just converts LaTeX to strokes and pushes.
    Used by Claude Code to send handwriting to the iPad in real time.
    """
    strokes = latex_to_strokes(
        body.latex,
        origin_x=body.origin_x,
        origin_y=body.origin_y,
        jitter=False,
    )

    sent = await ws_manager.send_to_user(user.id, {
        "type": "simulation_strokes",
        "strokes": strokes,
        "latex": body.latex,
        "step_index": 0,
        "reasoning": "",
    })

    if not sent:
        raise HTTPException(status_code=404, detail="No WebSocket connection. Tap the play button on the iPad first.")

    log.info(f"[inject] Sent {len(strokes)} strokes to {user.id}: {body.latex[:50]}")
    return InjectStrokesResponse(status="sent", strokes_count=len(strokes))
