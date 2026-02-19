"""Parse and validate YAML test scenarios."""

from dataclasses import dataclass, field
from pathlib import Path

import yaml


@dataclass
class AnswerKeyEntry:
    part_label: str | None
    answer: str


@dataclass
class Problem:
    document_name: str
    question_number: int
    label: str
    text: str
    parts: list[dict] = field(default_factory=list)
    answer_key: list[AnswerKeyEntry] = field(default_factory=list)


@dataclass
class StepExpect:
    action: str  # "silent", "speak", or "either"
    constraints: list[str] = field(default_factory=list)
    if_speak: dict = field(default_factory=dict)


@dataclass
class Step:
    id: str
    transcription: str
    expect: StepExpect


@dataclass
class Scenario:
    name: str
    subject: str
    problem: Problem
    steps: list[Step]
    filepath: str = ""


def _parse_expect(raw: dict) -> StepExpect:
    action = raw.get("action", "silent")
    constraints = raw.get("constraints", [])
    if_speak = raw.get("if_speak", {})
    return StepExpect(action=action, constraints=constraints, if_speak=if_speak)


def _parse_problem(raw: dict) -> Problem:
    ak_entries = []
    for entry in raw.get("answer_key", []):
        ak_entries.append(
            AnswerKeyEntry(
                part_label=entry.get("part_label"),
                answer=entry.get("answer", ""),
            )
        )
    return Problem(
        document_name=raw["document_name"],
        question_number=raw["question_number"],
        label=raw.get("label", ""),
        text=raw.get("text", ""),
        parts=raw.get("parts", []),
        answer_key=ak_entries,
    )


def _parse_step(raw: dict) -> Step:
    return Step(
        id=raw["id"],
        transcription=raw["transcription"],
        expect=_parse_expect(raw.get("expect", {})),
    )


def load_scenario(path: Path) -> Scenario:
    """Load a single scenario from a YAML file."""
    with open(path) as f:
        data = yaml.safe_load(f)

    return Scenario(
        name=data["name"],
        subject=data.get("subject", "math"),
        problem=_parse_problem(data["problem"]),
        steps=[_parse_step(s) for s in data["steps"]],
        filepath=str(path),
    )


def load_all_scenarios(directory: Path | None = None) -> list[Scenario]:
    """Load all YAML scenarios from the scenarios directory."""
    if directory is None:
        directory = Path(__file__).parent / "scenarios"

    scenarios = []
    for path in sorted(directory.glob("*.yaml")):
        scenarios.append(load_scenario(path))
    return scenarios


def load_scenario_by_name(name: str, directory: Path | None = None) -> Scenario | None:
    """Load a specific scenario by filename stem (without .yaml)."""
    if directory is None:
        directory = Path(__file__).parent / "scenarios"

    path = directory / f"{name}.yaml"
    if path.exists():
        return load_scenario(path)

    # Try partial match
    for p in directory.glob("*.yaml"):
        if name in p.stem:
            return load_scenario(p)

    return None
