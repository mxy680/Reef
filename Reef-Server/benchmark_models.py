#!/usr/bin/env python3
"""Benchmark reasoning models for Reef tutoring.

Runs the same test cases from the 2026-02-19 benchmark against new model
candidates. Uses the simulation API endpoints so the server handles context
building, response parsing, etc. — identical to production.

Prerequisites:
  - Reef-Server running locally on port 8000 (ENVIRONMENT=development)
  - DATABASE_URL set (needs questions + answer_keys tables)
  - OPENROUTER_API_KEY set

Usage:
  uv run python benchmark_models.py [--models MODEL1,MODEL2,...] [--runs N]
"""

import argparse
import json
import statistics
import sys
import time
from pathlib import Path

import httpx

BASE = "http://localhost:8000"
TIMEOUT = 120.0  # seconds per call (some models are slow)

# ── Models to benchmark ──────────────────────────────────────────────
DEFAULT_MODELS = [
    # Current
    "qwen/qwen3-vl-235b-a22b-instruct",
    # Closed-source contenders
    "anthropic/claude-sonnet-4",
    "google/gemini-2.5-pro-preview",
    "google/gemini-2.5-flash-preview",
    "openai/o4-mini",
    # Open-source contenders
    "qwen/qwen-vl-max",
]

# ── Test cases ────────────────────────────────────────────────────────
# Each test case simulates a student writing something, then checks
# whether the model correctly speaks or stays silent.
#
# Format:
#   problem_text, answer_key, parts — define the problem context
#   steps — list of (transcription, expected_action, description)
#     expected_action:
#       "speak_catch"        — must speak to flag an error
#       "silent_or_accept"   — must stay silent (correct work, no trigger)
#       "speak_yes"          — must confirm correct answer (student asked)
#       "speak_yes_or_guide" — must speak (confirm or guide)

TEST_CASES = [
    {
        "label": "P4.1 Thevenin",
        "problem_text": (
            "For the circuit shown, find the Thevenin equivalent circuit "
            "with respect to terminals a-b. The circuit has a 20V source, "
            "R1 = 4kΩ, R2 = 6kΩ, R3 = 12kΩ. "
            "(a) Find V_th. (b) Find R_th. (c) Find R_L for I = 0.5 mA."
        ),
        "answer_key": [
            {"part_label": "a", "answer": "V_th = 12V (voltage division: 20 * 6k/(4k+6k))"},
            {"part_label": "b", "answer": "R_th = 2.4kΩ + 12kΩ = 14.4kΩ (R1||R2 + R3)"},
            {"part_label": "c", "answer": "R_L = V_th/I - R_th = 12/0.0005 - 14400 = 9.6kΩ"},
        ],
        "parts": [
            {"label": "a", "text": "Find V_th"},
            {"label": "b", "text": "Find R_th"},
            {"label": "c", "text": "Find R_L for I = 0.5 mA"},
        ],
        "steps": [
            {
                "transcription": "V_th = 20V",
                "expected": "speak_catch",
                "description": "Wrong V_th: used full source instead of voltage division",
            },
            {
                "transcription": "V_th = 12V\nR_th = 4kΩ + 6kΩ = 10kΩ\nR_L = 12/0.0005 - 10000 = 14kΩ\nBut R_L comes out negative if we use different R_th...",
                "expected": "speak_catch",
                "description": "Correct V_th but R_th wrong (series instead of parallel+series)",
            },
            {
                "transcription": "V_th = 12V (by voltage division)\nR_th = R1||R2 + R3 = 2.4kΩ + 12kΩ = 14.4kΩ\nR_L = V_th/I - R_th = 12/0.0005 - 14400 = 9600Ω = 9.6kΩ",
                "expected": "silent_or_accept",
                "description": "Correct answer — should stay silent",
            },
            {
                "transcription": "V_th = 12V\nR_th = 14.4kΩ\nR_L = 9.6kΩ",
                "expected": "speak_yes",
                "description": "Student asks 'is this right?' with correct answer",
                "ask": "Is my answer right?",
            },
        ],
    },
    {
        "label": "P4.2 Norton",
        "problem_text": (
            "Find the Norton equivalent circuit for the network with a "
            "dependent voltage source 2Vx, R1 = 2Ω, R2 = 4Ω, R3 = 8Ω. "
            "Find I_N and R_N with respect to terminals a-b."
        ),
        "answer_key": [
            {"part_label": "a", "answer": "I_N = short-circuit current at a-b. With dependent source, use mesh analysis. I_N = 1.5A"},
            {"part_label": "b", "answer": "R_N = V_oc / I_sc. Cannot use simple series/parallel because of dependent source. R_N = 4Ω"},
        ],
        "parts": [
            {"label": "a", "text": "Find I_N"},
            {"label": "b", "text": "Find R_N"},
        ],
        "steps": [
            {
                "transcription": "I_N = V_s / (R1 + R2 + R3) = 10 / (2+4+8) = 0.714A",
                "expected": "speak_catch",
                "description": "Wrong: treated all resistors as series, ignored dependent source",
            },
            {
                "transcription": "For I_N, short a-b. Mesh analysis with dependent source 2Vx.\nKVL: -10 + 2I_1 + 2Vx + 4(I_1-I_2) = 0\nVx = 4(I_1 - I_2)\nSolving...",
                "expected": "silent_or_accept",
                "description": "Correct approach using mesh analysis — still working",
            },
            {
                "transcription": "I_N = 1.5A, R_N = R_th = 4Ω",
                "expected": "speak_yes_or_guide",
                "description": "Student asks for confirmation/guidance",
                "ask": "Is this right so far?",
            },
        ],
    },
    {
        "label": "P4.3 Max Power",
        "problem_text": (
            "For the circuit with V_s = 24V, R1 = 6Ω, R2 = 3Ω, R3 = 12Ω: "
            "(a) Find R_L for maximum power transfer. "
            "(b) Find the maximum power delivered to R_L."
        ),
        "answer_key": [
            {"part_label": "a", "answer": "R_L = R_th = R1||R2 + R3 = 2Ω + 12Ω = 14Ω"},
            {"part_label": "b", "answer": "P_max = V_th^2 / (4*R_th) = (8)^2 / (4*14) = 64/56 = 1.143W"},
        ],
        "parts": [
            {"label": "a", "text": "Find R_L for maximum power transfer"},
            {"label": "b", "text": "Find maximum power delivered to R_L"},
        ],
        "steps": [
            {
                "transcription": "R_th = R1 + R2 + R3 = 6 + 3 + 12 = 21Ω\nR_L = R_th = 21Ω",
                "expected": "speak_catch",
                "description": "Wrong: added all resistors in series instead of parallel combo",
            },
            {
                "transcription": "R_th = R1||R2 + R3 = (6*3)/(6+3) + 12 = 2 + 12 = 14Ω\nR_L = R_th = 14Ω\nV_th = 24 * 3/(6+3) = 8V\nP_max = V_th^2 / (4*R_th) = 64/56 = 1.143W",
                "expected": "silent_or_accept",
                "description": "Correct answer — should stay silent",
            },
            {
                "transcription": "R_L = 14Ω, P_max = 1.143W",
                "expected": "speak_yes",
                "description": "Student asks to verify correct answer",
                "ask": "Did I get this right?",
            },
        ],
    },
    {
        "label": "P4.4 Transistors",
        "problem_text": (
            "For the common-emitter amplifier with R_B = 100kΩ, R_C = 5kΩ, "
            "V_CC = 12V, β = 100: "
            "(a) Find the voltage gain A_v. "
            "(b) Find the current gain A_I."
        ),
        "answer_key": [
            {"part_label": "a", "answer": "A_v = -β*R_C/R_B = -100*5k/100k = -5 [Common mistake: forgetting the negative sign or forgetting β]"},
            {"part_label": "b", "answer": "A_I = β = 100"},
        ],
        "parts": [
            {"label": "a", "text": "Find voltage gain A_v"},
            {"label": "b", "text": "Find current gain A_I"},
        ],
        "steps": [
            {
                "transcription": "A_v = R_C / R_B = 5k/100k = 0.05\nA_I = β = 100",
                "expected": "speak_catch",
                "description": "Missing beta in A_v formula",
            },
            {
                "transcription": "A_v = -β*R_C/R_B = -100*5000/100000 = -5\nA_I = β = 100",
                "expected": "silent_or_accept",
                "description": "Correct answer — should stay silent",
            },
            {
                "transcription": "A_v = -5, A_I = 100",
                "expected": "speak_yes",
                "description": "Student asks to verify",
                "ask": "Is my answer right?",
            },
        ],
    },
]


def grade_step(expected: str, action: str) -> str:
    """Grade a single step result. Returns 'PASS' or 'FAIL'."""
    if expected == "speak_catch":
        return "PASS" if action == "speak" else "FAIL"
    elif expected == "silent_or_accept":
        return "PASS" if action == "silent" else "FAIL"
    elif expected == "speak_yes":
        return "PASS" if action == "speak" else "FAIL"
    elif expected == "speak_yes_or_guide":
        return "PASS" if action == "speak" else "FAIL"
    return "UNKNOWN"


def run_benchmark(client: httpx.Client, model_id: str, run_idx: int, structured: bool = False) -> dict:
    """Run all test cases for a single model. Returns structured results."""
    # Set the model override
    resp = client.post(
        f"{BASE}/api/simulation/set-model",
        json={"model_id": model_id, "structured_output": structured},
        timeout=10,
    )
    if resp.status_code != 200:
        print(f"  [!] Failed to set model: {resp.text}")
        return {"error": f"set-model failed: {resp.status_code}"}

    active_model = resp.json().get("model", model_id)
    print(f"  Model active: {active_model}")

    results = {}

    for tc in TEST_CASES:
        label = tc["label"]
        print(f"  {label}...")
        results[label] = {"steps": [], "passes": 0, "total": 0}

        # Start simulation session
        start_resp = client.post(
            f"{BASE}/api/simulation/start",
            json={
                "problem_text": tc["problem_text"],
                "answer_key": tc["answer_key"],
                "parts": tc["parts"],
                "label": label,
                "question_number": 1,
            },
            timeout=10,
        )
        if start_resp.status_code != 200:
            print(f"    [!] Failed to start: {start_resp.text}")
            results[label]["steps"] = [{"error": "start failed"}] * len(tc["steps"])
            results[label]["total"] = len(tc["steps"])
            continue

        session_id = start_resp.json()["session_id"]

        for i, step in enumerate(tc["steps"]):
            step_result = {
                "description": step["description"],
                "expected": step["expected"],
            }

            try:
                t0 = time.monotonic()

                if "ask" in step:
                    # Write transcription first, then ask
                    client.post(
                        f"{BASE}/api/simulation/write",
                        json={
                            "session_id": session_id,
                            "transcription": step["transcription"],
                        },
                        timeout=TIMEOUT,
                    )
                    resp = client.post(
                        f"{BASE}/api/simulation/ask",
                        json={
                            "session_id": session_id,
                            "question": step["ask"],
                        },
                        timeout=TIMEOUT,
                    )
                else:
                    resp = client.post(
                        f"{BASE}/api/simulation/write",
                        json={
                            "session_id": session_id,
                            "transcription": step["transcription"],
                        },
                        timeout=TIMEOUT,
                    )

                elapsed_ms = int((time.monotonic() - t0) * 1000)

                if resp.status_code != 200:
                    step_result["action"] = "error"
                    step_result["message"] = f"HTTP {resp.status_code}: {resp.text[:200]}"
                    step_result["latency_ms"] = elapsed_ms
                    step_result["grade"] = "FAIL"
                else:
                    data = resp.json()
                    step_result["action"] = data.get("action", "unknown")
                    step_result["message"] = data.get("message", "")[:200]
                    step_result["latency_ms"] = elapsed_ms
                    step_result["grade"] = grade_step(step["expected"], step_result["action"])

            except httpx.TimeoutException:
                step_result["action"] = "timeout"
                step_result["message"] = f"Timed out after {TIMEOUT}s"
                step_result["latency_ms"] = int(TIMEOUT * 1000)
                step_result["grade"] = "FAIL"
            except Exception as e:
                step_result["action"] = "error"
                step_result["message"] = str(e)[:200]
                step_result["latency_ms"] = 0
                step_result["grade"] = "FAIL"

            grade_icon = "✓" if step_result["grade"] == "PASS" else "✗"
            print(f"    Step {i+1}: {grade_icon} {step['description']} ({step_result['latency_ms']}ms)")

            results[label]["steps"].append(step_result)
            results[label]["total"] += 1
            if step_result["grade"] == "PASS":
                results[label]["passes"] += 1

        # Reset session
        client.post(
            f"{BASE}/api/simulation/reset",
            json={"session_id": session_id},
            timeout=10,
        )

        latencies = [s["latency_ms"] for s in results[label]["steps"] if s.get("latency_ms", 0) > 0]
        results[label]["avg_latency"] = int(statistics.mean(latencies)) if latencies else 0

    return results


def summarize(all_results: dict) -> None:
    """Print a summary table."""
    print("\n" + "=" * 80)
    print("BENCHMARK SUMMARY")
    print("=" * 80)

    header = f"{'Model':<45} {'Score':>7} {'Avg Lat':>8} {'p50':>6} {'p95':>6}"
    print(header)
    print("-" * len(header))

    for model_id, runs in all_results.items():
        all_passes = 0
        all_total = 0
        all_latencies = []

        for run in runs:
            if "error" in run:
                continue
            for problem_results in run.values():
                if isinstance(problem_results, dict) and "passes" in problem_results:
                    all_passes += problem_results["passes"]
                    all_total += problem_results["total"]
                    for s in problem_results.get("steps", []):
                        if s.get("latency_ms", 0) > 0 and s.get("grade") != "FAIL":
                            all_latencies.append(s["latency_ms"])

        avg_lat = int(statistics.mean(all_latencies)) if all_latencies else 0
        p50 = int(statistics.median(all_latencies)) if all_latencies else 0
        p95 = int(sorted(all_latencies)[int(len(all_latencies) * 0.95)]) if len(all_latencies) >= 2 else avg_lat

        score_str = f"{all_passes}/{all_total}"
        model_short = model_id.split("/")[-1] if "/" in model_id else model_id
        print(f"{model_short:<45} {score_str:>7} {avg_lat:>7}ms {p50:>5}ms {p95:>5}ms")

    print()


def main():
    parser = argparse.ArgumentParser(description="Benchmark reasoning models for Reef tutoring")
    parser.add_argument(
        "--models",
        type=str,
        default=None,
        help="Comma-separated model IDs (default: built-in list)",
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=1,
        help="Number of runs per model (default: 1)",
    )
    parser.add_argument(
        "--output",
        type=str,
        default=None,
        help="Output JSON file path (default: stdout only)",
    )
    parser.add_argument(
        "--structured",
        action="store_true",
        help="Use structured JSON output instead of punctuation parsing",
    )
    args = parser.parse_args()

    models = args.models.split(",") if args.models else DEFAULT_MODELS

    # Health check
    try:
        r = httpx.get(f"{BASE}/health", timeout=5)
        r.raise_for_status()
    except Exception as e:
        print(f"Server not reachable at {BASE}: {e}")
        print("Start the server first: see CLAUDE.md for instructions")
        sys.exit(1)

    mode_label = "structured JSON" if args.structured else "punctuation"
    print(f"Benchmarking {len(models)} models × {args.runs} run(s) × {sum(len(tc['steps']) for tc in TEST_CASES)} steps")
    print(f"Output mode: {mode_label}")
    print(f"Models: {', '.join(m.split('/')[-1] for m in models)}")
    print()

    all_results: dict[str, list] = {}

    with httpx.Client() as client:
        for model_id in models:
            model_short = model_id.split("/")[-1] if "/" in model_id else model_id
            all_results[model_id] = []

            for run in range(args.runs):
                run_label = f" (run {run+1}/{args.runs})" if args.runs > 1 else ""
                print(f"{'─' * 60}")
                print(f"Model: {model_short}{run_label}")
                print(f"{'─' * 60}")

                results = run_benchmark(client, model_id, run, structured=args.structured)
                all_results[model_id].append(results)
                print()

        # Clear the override when done
        client.post(
            f"{BASE}/api/simulation/set-model",
            json={"model_id": None},
            timeout=10,
        )

    summarize(all_results)

    if args.output:
        out_path = Path(args.output)
        out_path.write_text(json.dumps(all_results, indent=2))
        print(f"Results saved to {out_path}")


if __name__ == "__main__":
    main()
