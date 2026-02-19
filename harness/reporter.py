"""Console output and JSON report generation."""

import json
from collections import Counter
from datetime import datetime
from pathlib import Path

from harness.evaluator import StepEvaluation
from harness.simulator import ScenarioResult, StepResult


def print_header(mode: str, evaluator_model: str, scenario_count: int) -> None:
    print(f"\n=== Reef Tutor Evaluation ===")
    print(f"Mode: {mode} | Evaluator: {evaluator_model} | Scenarios: {scenario_count}")
    print()


def print_step_result(
    step: StepResult,
    evaluation: StepEvaluation | None,
    step_index: int,
) -> None:
    """Print a single step's result."""
    if evaluation is None:
        # No evaluation — just show raw result
        msg_preview = step.message[:60] if step.message else ""
        print(f"  Step {step_index} ({step.id}): {step.action} — \"{msg_preview}\"")
        return

    status = "PASS" if evaluation.passed else "FAIL"
    msg_preview = step.message[:60] if step.action == "speak" and step.message else ""
    msg_part = f" \"{msg_preview}\"" if msg_preview else ""
    score_part = f" — score {evaluation.weighted_average:.1f}"

    print(f"  Step {step_index} ({step.id}): {status} — {step.action}{msg_part}{score_part}")

    if not evaluation.passed:
        for reason in evaluation.failure_reasons:
            print(f"    !! {reason}")


def print_scenario_result(
    index: int,
    total: int,
    scenario_result: ScenarioResult,
    evaluations: list[StepEvaluation | None],
    scenario_filepath: str = "",
) -> None:
    """Print a full scenario result."""
    # Extract scenario file stem for display
    name = scenario_result.scenario_name
    stem = Path(scenario_filepath).stem if scenario_filepath else ""
    header = f"[{index}/{total}] {stem}" if stem else f"[{index}/{total}]"
    print(f"{header} — {name}")

    if scenario_result.error:
        print(f"  ERROR: {scenario_result.error}")
        print(f"  SCENARIO ERROR")
        print()
        return

    for i, (step_result, evaluation) in enumerate(
        zip(scenario_result.step_results, evaluations), 1
    ):
        print_step_result(step_result, evaluation, i)

    # Scenario pass/fail
    has_evals = any(e is not None for e in evaluations)
    if has_evals:
        all_passed = all(e.passed for e in evaluations if e is not None)
        avg_score = _avg_score(evaluations)
        status = "PASS" if all_passed else "FAIL"
        print(f"  SCENARIO {status} (avg {avg_score:.2f})")
    else:
        print(f"  SCENARIO COMPLETE (no evaluation)")
    print()


def print_summary(
    scenario_results: list[ScenarioResult],
    all_evaluations: list[list[StepEvaluation | None]],
    filepaths: list[str],
) -> None:
    """Print the final summary."""
    total = len(scenario_results)
    passed = 0
    failed_names: list[str] = []
    all_scores: list[float] = []
    issue_counter: Counter = Counter()

    for sr, evals, fp in zip(scenario_results, all_evaluations, filepaths):
        if sr.error:
            failed_names.append(Path(fp).stem if fp else sr.scenario_name)
            continue

        has_evals = any(e is not None for e in evals)
        if not has_evals:
            passed += 1
            continue

        scenario_passed = all(e.passed for e in evals if e is not None)
        if scenario_passed:
            passed += 1
        else:
            failed_names.append(Path(fp).stem if fp else sr.scenario_name)

        for ev in evals:
            if ev is not None:
                all_scores.append(ev.weighted_average)
                for reason in ev.failure_reasons:
                    issue_counter[reason] += 1

    avg = sum(all_scores) / len(all_scores) if all_scores else 0.0

    print("=== Summary ===")
    failed_count = total - passed
    print(f"Passed: {passed}/{total} | Failed: {', '.join(failed_names) or 'none'}")
    print(f"Average score: {avg:.2f}/5.00")

    if issue_counter:
        print("Top issues:")
        for i, (issue, count) in enumerate(issue_counter.most_common(5), 1):
            print(f"  {i}. {issue} ({count} occurrence{'s' if count > 1 else ''})")

    print()


def _avg_score(evaluations: list[StepEvaluation | None]) -> float:
    scores = [e.weighted_average for e in evaluations if e is not None]
    return sum(scores) / len(scores) if scores else 0.0


def save_json_report(
    scenario_results: list[ScenarioResult],
    all_evaluations: list[list[StepEvaluation | None]],
    mode: str,
    evaluator_model: str,
) -> Path:
    """Save a JSON report and return the path."""
    reports_dir = Path(__file__).parent / "reports"
    reports_dir.mkdir(exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    report_path = reports_dir / f"{timestamp}.json"

    report = {
        "timestamp": timestamp,
        "mode": mode,
        "evaluator_model": evaluator_model,
        "scenarios": [],
    }

    for sr, evals in zip(scenario_results, all_evaluations):
        scenario_data = {
            "name": sr.scenario_name,
            "session_id": sr.session_id,
            "error": sr.error,
            "steps": [],
        }

        for step_result, evaluation in zip(sr.step_results, evals):
            step_data = {
                "step_id": step_result.step_id,
                "action": step_result.action,
                "message": step_result.message,
                "expected_action": step_result.expected_action,
                "transcription": step_result.transcription,
            }

            if evaluation is not None:
                step_data["evaluation"] = {
                    "weighted_average": evaluation.weighted_average,
                    "passed": evaluation.passed,
                    "failure_reasons": evaluation.failure_reasons,
                    "dimensions": {
                        d.name: {
                            "score": d.score,
                            "weight": d.weight,
                            "evidence": d.evidence,
                            "suggestion": d.suggestion,
                        }
                        for d in evaluation.dimensions
                    },
                }

            scenario_data["steps"].append(step_data)

        report["scenarios"].append(scenario_data)

    report_path.write_text(json.dumps(report, indent=2))
    print(f"Report saved to {report_path}")
    return report_path
