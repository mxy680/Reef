"""LLM-based scoring of tutor responses against a pedagogical rubric."""

import json
from dataclasses import dataclass, field

from lib.llm_client import LLMClient

from harness.config import EVALUATOR_BASE_URL, get_evaluator_api_key, get_evaluator_model
from harness.simulator import StepResult


# Scoring dimensions with weights
DIMENSIONS = [
    ("action_correctness", 3),
    ("pedagogical_approach", 2),
    ("content_accuracy", 2),
    ("no_answer_reveal", 2),
    ("brevity", 1),
    ("voice_readiness", 1),
]

TOTAL_WEIGHT = sum(w for _, w in DIMENSIONS)

EVALUATOR_SYSTEM_PROMPT = """\
You are an expert evaluator of AI tutoring systems. You assess whether a tutor's \
response to a student's work is pedagogically sound.

Score each dimension from 1-5:
1 = Completely wrong / harmful
2 = Poor — significant issues
3 = Acceptable — meets minimum bar
4 = Good — solid pedagogical practice
5 = Excellent — exemplary tutoring

Be rigorous. A score of 5 means truly outstanding performance on that dimension.\
"""

EVALUATOR_PROMPT_TEMPLATE = """\
## Context

Problem: {problem_text}
Answer Key: {answer_key}
Student's Current Work:
{transcription}

Tutor History: {tutor_history}

## Tutor's Response

action: {action}
message: "{message}"

## Expected Behavior

Expected action: {expected_action}
Constraints: {constraints}

## Scoring Dimensions

Score each dimension 1-5:

1. **action_correctness** (weight 3x): Did the tutor correctly decide speak vs. silent? \
If expected is "either", both are acceptable. If expected is "speak" and tutor was silent \
(or vice versa), score 1.

2. **pedagogical_approach** (weight 2x): Does the tutor use graduated intervention? \
Metacognitive prompts > nudges > hints > direct answers. Does it ask questions rather \
than make statements?

3. **content_accuracy** (weight 2x): Is the feedback factually correct for this subject? \
Does it correctly identify the error (if any)?

4. **no_answer_reveal** (weight 2x): Does the tutor avoid giving away the answer? \
Directly stating the answer = score 1. Hinting at the answer method = 3-4. \
Pure metacognitive prompt = 5. If action is "silent", score 5.

5. **brevity** (weight 1x): Is the response 1-2 sentences and conversational? \
If silent, score 5. Verbose responses score lower.

6. **voice_readiness** (weight 1x): Is the text TTS-friendly? No LaTeX, no symbols, \
no fractions written as a/b. If silent, score 5.

For each dimension, provide:
- score (1-5 integer)
- evidence (brief quote or observation justifying the score)
- suggestion (how to improve, or empty string if score >= 4)\
"""

EVALUATOR_RESPONSE_SCHEMA = {
    "type": "object",
    "properties": {
        "scores": {
            "type": "object",
            "properties": {
                dim: {
                    "type": "object",
                    "properties": {
                        "score": {"type": "integer"},
                        "evidence": {"type": "string"},
                        "suggestion": {"type": "string"},
                    },
                }
                for dim, _ in DIMENSIONS
            },
        },
    },
}


@dataclass
class DimensionScore:
    name: str
    weight: int
    score: int
    evidence: str
    suggestion: str


@dataclass
class StepEvaluation:
    step_id: str
    action: str
    message: str
    expected_action: str
    dimensions: list[DimensionScore] = field(default_factory=list)
    weighted_average: float = 0.0
    passed: bool = False
    failure_reasons: list[str] = field(default_factory=list)


def _get_evaluator_client() -> LLMClient:
    return LLMClient(
        api_key=get_evaluator_api_key(),
        model=get_evaluator_model(),
        base_url=EVALUATOR_BASE_URL,
    )


async def evaluate_step(
    step_result: StepResult,
    problem_text: str,
    answer_key: str,
    tutor_history: str,
) -> StepEvaluation:
    """Evaluate a single step's tutor response using the LLM evaluator."""
    import asyncio

    client = _get_evaluator_client()

    prompt = EVALUATOR_PROMPT_TEMPLATE.format(
        problem_text=problem_text,
        answer_key=answer_key,
        transcription=step_result.transcription,
        tutor_history=tutor_history,
        action=step_result.action,
        message=step_result.message,
        expected_action=step_result.expected_action,
        constraints=", ".join(step_result.constraints) or "none",
    )

    raw = await asyncio.to_thread(
        client.generate,
        prompt=prompt,
        response_schema=EVALUATOR_RESPONSE_SCHEMA,
        system_message=EVALUATOR_SYSTEM_PROMPT,
        temperature=0.2,
    )

    data = json.loads(raw)
    scores_data = data.get("scores", {})

    dimensions: list[DimensionScore] = []
    for dim_name, weight in DIMENSIONS:
        dim_data = scores_data.get(dim_name, {})
        dimensions.append(
            DimensionScore(
                name=dim_name,
                weight=weight,
                score=dim_data.get("score", 1),
                evidence=dim_data.get("evidence", ""),
                suggestion=dim_data.get("suggestion", ""),
            )
        )

    # Calculate weighted average
    weighted_sum = sum(d.score * d.weight for d in dimensions)
    weighted_avg = weighted_sum / TOTAL_WEIGHT if TOTAL_WEIGHT > 0 else 0.0

    # Determine pass/fail
    failure_reasons: list[str] = []

    # Check action correctness
    expected = step_result.expected_action
    actual = step_result.action
    if expected not in ("either",):
        if expected != actual:
            failure_reasons.append(
                f"Action mismatch: expected {expected}, got {actual}"
            )

    # Check no dimension scores 1
    for d in dimensions:
        if d.score == 1:
            failure_reasons.append(f"{d.name}: 1 — {d.evidence}")

    # Check weighted average >= 3.5
    if weighted_avg < 3.5:
        failure_reasons.append(f"Weighted average {weighted_avg:.2f} < 3.5")

    passed = len(failure_reasons) == 0

    return StepEvaluation(
        step_id=step_result.step_id,
        action=step_result.action,
        message=step_result.message,
        expected_action=step_result.expected_action,
        dimensions=dimensions,
        weighted_average=weighted_avg,
        passed=passed,
        failure_reasons=failure_reasons,
    )
