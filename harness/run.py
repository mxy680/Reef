"""CLI entry point for the tutor evaluation harness.

Usage:
    cd Reef-Server && uv run python -m harness.run
    uv run python -m harness.run --scenario math_sign_error
    uv run python -m harness.run --mode pipeline
    uv run python -m harness.run --no-eval
    uv run python -m harness.run -v
"""

import argparse
import asyncio
import sys

from harness.config import get_evaluator_model
from harness.db import create_pool
from harness.evaluator import evaluate_step
from harness.reporter import (
    print_header,
    print_scenario_result,
    print_summary,
    save_json_report,
)
from harness.scenario_loader import Scenario, load_all_scenarios, load_scenario_by_name
from harness.simulator import ScenarioResult, run_direct, run_pipeline


async def run_harness(args: argparse.Namespace) -> int:
    """Main harness execution loop. Returns exit code (0 = all pass, 1 = failures)."""
    # Load scenarios
    if args.scenario:
        scenario = load_scenario_by_name(args.scenario)
        if scenario is None:
            print(f"Error: scenario '{args.scenario}' not found")
            return 1
        scenarios = [scenario]
    else:
        scenarios = load_all_scenarios()

    if not scenarios:
        print("No scenarios found in harness/scenarios/")
        return 1

    mode = args.mode
    evaluator_model = get_evaluator_model()
    skip_eval = args.no_eval
    verbose = args.verbose

    print_header(mode, evaluator_model if not skip_eval else "skipped", len(scenarios))

    # Create DB pool
    pool = await create_pool()

    try:
        all_scenario_results: list[ScenarioResult] = []
        all_evaluations: list[list] = []
        filepaths: list[str] = []

        for i, scenario in enumerate(scenarios, 1):
            # Run scenario
            if mode == "direct":
                sr = await run_direct(scenario, pool, verbose=verbose)
            else:
                sr = await run_pipeline(scenario, pool, verbose=verbose)

            all_scenario_results.append(sr)
            filepaths.append(scenario.filepath)

            # Evaluate steps
            step_evals = []
            if not skip_eval and sr.error is None:
                # Build answer key and problem text strings for evaluator
                problem_text = scenario.problem.text
                answer_key_str = "; ".join(
                    f"{ak.part_label or 'Main'}: {ak.answer}"
                    for ak in scenario.problem.answer_key
                )

                # Build tutor history incrementally
                tutor_history_parts: list[str] = []
                for step_result in sr.step_results:
                    history_str = (
                        " | ".join(tutor_history_parts) if tutor_history_parts else "none"
                    )

                    evaluation = await evaluate_step(
                        step_result,
                        problem_text=problem_text,
                        answer_key=answer_key_str,
                        tutor_history=history_str,
                    )
                    step_evals.append(evaluation)

                    # Add this step to history for next step's evaluation
                    tutor_history_parts.append(
                        f"[{step_result.action}] {step_result.message or ''}"
                    )
            else:
                step_evals = [None] * len(sr.step_results)

            all_evaluations.append(step_evals)

            # Print scenario result
            print_scenario_result(
                i, len(scenarios), sr, step_evals, scenario.filepath
            )

        # Summary
        print_summary(all_scenario_results, all_evaluations, filepaths)

        # Save JSON report
        if not skip_eval:
            save_json_report(
                all_scenario_results, all_evaluations, mode, evaluator_model
            )

        # Determine exit code
        has_failures = False
        for sr, evals in zip(all_scenario_results, all_evaluations):
            if sr.error:
                has_failures = True
            elif any(e is not None and not e.passed for e in evals):
                has_failures = True

        return 1 if has_failures else 0

    finally:
        await pool.close()


def main():
    parser = argparse.ArgumentParser(
        description="Reef Tutor Evaluation Harness",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--scenario",
        type=str,
        default=None,
        help="Run a specific scenario by name (filename stem without .yaml)",
    )
    parser.add_argument(
        "--mode",
        type=str,
        choices=["direct", "pipeline"],
        default="direct",
        help="Execution mode (default: direct)",
    )
    parser.add_argument(
        "--no-eval",
        action="store_true",
        help="Skip LLM evaluation (just capture reasoning output)",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Show full context and evaluator reasoning",
    )

    args = parser.parse_args()
    exit_code = asyncio.run(run_harness(args))
    sys.exit(exit_code)


if __name__ == "__main__":
    main()
