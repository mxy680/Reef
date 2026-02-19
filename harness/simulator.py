"""Execute scenarios against the tutor — direct mode and pipeline mode."""

import json
import uuid
from dataclasses import dataclass, field

import asyncpg
import httpx

from harness.config import get_server_url
from harness.db import (
    cleanup_document,
    cleanup_session,
    insert_answer_key,
    insert_document,
    insert_question,
    upsert_transcription,
)
from harness.scenario_loader import Scenario, Step


@dataclass
class StepResult:
    step_id: str
    action: str
    message: str
    transcription: str
    expected_action: str
    constraints: list[str] = field(default_factory=list)
    if_speak: dict = field(default_factory=dict)


@dataclass
class ScenarioResult:
    scenario_name: str
    session_id: str
    step_results: list[StepResult] = field(default_factory=list)
    error: str | None = None


async def run_direct(
    scenario: Scenario,
    pool: asyncpg.Pool,
    verbose: bool = False,
) -> ScenarioResult:
    """Run a scenario in direct mode — bypass Mathpix, insert transcriptions directly."""
    session_id = f"harness_{uuid.uuid4().hex[:12]}"
    server_url = get_server_url()
    result = ScenarioResult(scenario_name=scenario.name, session_id=session_id)

    document_id = None
    try:
        # 1. DB setup: insert document, question, answer keys
        document_id = await insert_document(pool, scenario.problem.document_name)
        question_id = await insert_question(
            pool,
            document_id=document_id,
            number=scenario.problem.question_number,
            label=scenario.problem.label,
            text=scenario.problem.text,
            parts=json.dumps(scenario.problem.parts),
        )
        for ak in scenario.problem.answer_key:
            await insert_answer_key(pool, question_id, ak.part_label, ak.answer)

        # 2. Register session via HTTP (populates server's _active_sessions)
        async with httpx.AsyncClient(base_url=server_url, timeout=10.0) as client:
            resp = await client.post(
                "/api/strokes/connect",
                json={
                    "session_id": session_id,
                    "document_name": scenario.problem.document_name,
                    "question_number": scenario.problem.question_number,
                },
            )
            resp.raise_for_status()

            # 3. Execute each step
            for step in scenario.steps:
                step_result = await _run_direct_step(
                    pool, client, session_id, step, verbose
                )
                result.step_results.append(step_result)

    except Exception as e:
        result.error = str(e)
    finally:
        # 4. Cleanup
        await cleanup_session(pool, session_id)
        if document_id is not None:
            await cleanup_document(pool, document_id)

    return result


async def _run_direct_step(
    pool: asyncpg.Pool,
    client: httpx.AsyncClient,
    session_id: str,
    step: Step,
    verbose: bool,
) -> StepResult:
    """Execute a single direct-mode step."""
    # a. UPSERT page transcription
    await upsert_transcription(pool, session_id, page=1, text=step.transcription)

    # b. Trigger reasoning via harness endpoint
    resp = await client.post(
        "/api/harness/trigger-reasoning",
        params={"session_id": session_id, "page": 1},
    )
    resp.raise_for_status()
    data = resp.json()

    action = data.get("action", "silent")
    message = data.get("message", "")

    if verbose:
        print(f"    [{step.id}] action={action}, message={message[:100]}")

    return StepResult(
        step_id=step.id,
        action=action,
        message=message,
        transcription=step.transcription,
        expected_action=step.expect.action,
        constraints=step.expect.constraints,
        if_speak=step.expect.if_speak,
    )


async def run_pipeline(
    scenario: Scenario,
    pool: asyncpg.Pool,
    verbose: bool = False,
) -> ScenarioResult:
    """Run a scenario in pipeline mode — POST strokes, wait for reasoning."""
    session_id = f"harness_{uuid.uuid4().hex[:12]}"
    server_url = get_server_url()
    result = ScenarioResult(scenario_name=scenario.name, session_id=session_id)

    document_id = None
    try:
        # 1. DB setup (same as direct mode)
        document_id = await insert_document(pool, scenario.problem.document_name)
        question_id = await insert_question(
            pool,
            document_id=document_id,
            number=scenario.problem.question_number,
            label=scenario.problem.label,
            text=scenario.problem.text,
            parts=json.dumps(scenario.problem.parts),
        )
        for ak in scenario.problem.answer_key:
            await insert_answer_key(pool, question_id, ak.part_label, ak.answer)

        # 2. Register session
        async with httpx.AsyncClient(base_url=server_url, timeout=30.0) as client:
            resp = await client.post(
                "/api/strokes/connect",
                json={
                    "session_id": session_id,
                    "document_name": scenario.problem.document_name,
                    "question_number": scenario.problem.question_number,
                },
            )
            resp.raise_for_status()

            # 3. Execute each step
            for step in scenario.steps:
                step_result = await _run_pipeline_step(
                    pool, client, session_id, step, verbose
                )
                result.step_results.append(step_result)

    except Exception as e:
        result.error = str(e)
    finally:
        await cleanup_session(pool, session_id)
        if document_id is not None:
            await cleanup_document(pool, document_id)

    return result


async def _run_pipeline_step(
    pool: asyncpg.Pool,
    client: httpx.AsyncClient,
    session_id: str,
    step: Step,
    verbose: bool,
) -> StepResult:
    """Execute a single pipeline-mode step — POST strokes and poll for reasoning."""
    import asyncio

    # Get current reasoning log count so we can detect the new one
    from harness.db import get_reasoning_logs

    existing_logs = await get_reasoning_logs(pool, session_id)
    existing_count = len(existing_logs)

    # POST strokes (minimal stroke data to trigger the pipeline)
    # The transcription will come from Mathpix processing these strokes
    resp = await client.post(
        "/api/strokes",
        json={
            "session_id": session_id,
            "page": 1,
            "strokes": [{"points": [{"x": 0, "y": 0}]}],
            "event_type": "draw",
        },
    )
    resp.raise_for_status()

    # Poll for new reasoning log entry (timeout 15s)
    action = "silent"
    message = ""
    for _ in range(30):
        await asyncio.sleep(0.5)
        logs = await get_reasoning_logs(pool, session_id)
        if len(logs) > existing_count:
            newest = logs[-1]
            action = newest["action"]
            message = newest.get("message", "")
            break
    else:
        if verbose:
            print(f"    [{step.id}] TIMEOUT waiting for reasoning")

    if verbose:
        print(f"    [{step.id}] action={action}, message={message[:100]}")

    return StepResult(
        step_id=step.id,
        action=action,
        message=message,
        transcription=step.transcription,
        expected_action=step.expect.action,
        constraints=step.expect.constraints,
        if_speak=step.expect.if_speak,
    )
