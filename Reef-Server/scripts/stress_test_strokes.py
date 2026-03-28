#!/usr/bin/env python3
"""Stroke stress test — sends increasing stroke counts through Mathpix → tutor pipeline.

Generates synthetic handwriting strokes for mathematical expressions, sends them
through /ai/transcribe-strokes (real Mathpix), writes the transcription to
student_work, and calls /ai/tutor-evaluate. Logs latency, accuracy, and breaking points.

Usage:
    python scripts/stress_test_strokes.py --server https://api.studyreef.com --token <jwt>
    python scripts/stress_test_strokes.py --server https://api.studyreef.com --token <jwt> --max-strokes 100
"""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
import time
import uuid

import httpx

# ---------------------------------------------------------------------------
# Env loading
# ---------------------------------------------------------------------------

def _load_env() -> dict[str, str]:
    env_path = os.path.expanduser("~/.config/reef/server.env")
    env: dict[str, str] = {}
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()
    return env


ENV = _load_env()

# ---------------------------------------------------------------------------
# Stroke generators — produce (x[], y[]) pairs that Mathpix can recognize
# ---------------------------------------------------------------------------

def _stroke_digit(digit: int, offset_x: float = 0, offset_y: float = 0, size: float = 40) -> dict:
    """Generate a single-stroke path for a digit 0-9."""
    points = 30
    xs, ys = [], []

    if digit == 0:
        for i in range(points):
            t = 2 * math.pi * i / (points - 1)
            xs.append(offset_x + size * 0.4 * math.cos(t))
            ys.append(offset_y + size * 0.5 * math.sin(t))
    elif digit == 1:
        for i in range(points):
            t = i / (points - 1)
            xs.append(offset_x + size * 0.1 * (1 - t))
            ys.append(offset_y - size * 0.5 + size * t)
    elif digit == 2:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.4:
                a = math.pi * (1 - t / 0.4)
                xs.append(offset_x + size * 0.3 * math.cos(a))
                ys.append(offset_y - size * 0.3 + size * 0.3 * math.sin(a))
            else:
                p = (t - 0.4) / 0.6
                xs.append(offset_x + size * 0.3 - size * 0.6 * p)
                ys.append(offset_y + size * 0.2 * p)
    elif digit == 3:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.5:
                a = math.pi * (1 - 2 * t)
                xs.append(offset_x + size * 0.25 * math.cos(a))
                ys.append(offset_y - size * 0.25 + size * 0.2 * math.sin(a))
            else:
                a = math.pi * (1 - 2 * (t - 0.5))
                xs.append(offset_x + size * 0.25 * math.cos(a))
                ys.append(offset_y + size * 0.05 + size * 0.2 * math.sin(a))
    elif digit == 4:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.4:
                p = t / 0.4
                xs.append(offset_x - size * 0.2 * (1 - p))
                ys.append(offset_y - size * 0.4 + size * 0.5 * p)
            elif t < 0.6:
                p = (t - 0.4) / 0.2
                xs.append(offset_x - size * 0.2 + size * 0.5 * p)
                ys.append(offset_y + size * 0.1)
            else:
                p = (t - 0.6) / 0.4
                xs.append(offset_x + size * 0.2)
                ys.append(offset_y - size * 0.4 + size * 0.8 * p)
    elif digit == 5:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.3:
                p = t / 0.3
                xs.append(offset_x + size * 0.3 - size * 0.5 * p)
                ys.append(offset_y - size * 0.4)
            elif t < 0.5:
                p = (t - 0.3) / 0.2
                xs.append(offset_x - size * 0.2)
                ys.append(offset_y - size * 0.4 + size * 0.4 * p)
            else:
                a = math.pi * (0.5 + (t - 0.5) / 0.5)
                xs.append(offset_x + size * 0.2 * math.cos(a))
                ys.append(offset_y + size * 0.15 + size * 0.2 * math.sin(a))
    elif digit == 6:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.4:
                p = t / 0.4
                xs.append(offset_x + size * 0.2 * math.cos(math.pi * 0.5 * (1 - p)))
                ys.append(offset_y - size * 0.4 + size * 0.5 * p)
            else:
                a = 2 * math.pi * (t - 0.4) / 0.6
                xs.append(offset_x + size * 0.2 * math.cos(a))
                ys.append(offset_y + size * 0.15 + size * 0.2 * math.sin(a))
    elif digit == 7:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.3:
                p = t / 0.3
                xs.append(offset_x - size * 0.25 + size * 0.5 * p)
                ys.append(offset_y - size * 0.4)
            else:
                p = (t - 0.3) / 0.7
                xs.append(offset_x + size * 0.25 - size * 0.3 * p)
                ys.append(offset_y - size * 0.4 + size * 0.8 * p)
    elif digit == 8:
        for i in range(points):
            t = 2 * math.pi * i / (points - 1)
            xs.append(offset_x + size * 0.2 * math.cos(t))
            ys.append(offset_y + size * 0.15 * math.sin(2 * t))
    elif digit == 9:
        for i in range(points):
            t = i / (points - 1)
            if t < 0.6:
                a = 2 * math.pi * t / 0.6
                xs.append(offset_x + size * 0.2 * math.cos(a))
                ys.append(offset_y - size * 0.15 + size * 0.2 * math.sin(a))
            else:
                p = (t - 0.6) / 0.4
                xs.append(offset_x + size * 0.2)
                ys.append(offset_y + size * 0.05 + size * 0.35 * p)

    return {"x": xs, "y": ys}


def _stroke_plus(offset_x: float, offset_y: float, size: float = 40) -> list[dict]:
    """Plus sign — two strokes (horizontal + vertical)."""
    pts = 15
    h_xs = [offset_x - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    h_ys = [offset_y] * pts
    v_xs = [offset_x] * pts
    v_ys = [offset_y - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    return [{"x": h_xs, "y": h_ys}, {"x": v_xs, "y": v_ys}]


def _stroke_equals(offset_x: float, offset_y: float, size: float = 40) -> list[dict]:
    """Equals sign — two horizontal strokes."""
    pts = 15
    gap = size * 0.15
    top_xs = [offset_x - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    top_ys = [offset_y - gap] * pts
    bot_xs = list(top_xs)
    bot_ys = [offset_y + gap] * pts
    return [{"x": top_xs, "y": top_ys}, {"x": bot_xs, "y": bot_ys}]


def _stroke_x_var(offset_x: float, offset_y: float, size: float = 40) -> list[dict]:
    """Letter x — two crossing strokes."""
    pts = 15
    s1_xs = [offset_x - size * 0.2 + size * 0.4 * i / (pts - 1) for i in range(pts)]
    s1_ys = [offset_y - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    s2_xs = [offset_x + size * 0.2 - size * 0.4 * i / (pts - 1) for i in range(pts)]
    s2_ys = [offset_y - size * 0.25 + size * 0.5 * i / (pts - 1) for i in range(pts)]
    return [{"x": s1_xs, "y": s1_ys}, {"x": s2_xs, "y": s2_ys}]


def _stroke_minus(offset_x: float, offset_y: float, size: float = 40) -> list[dict]:
    """Minus sign — one horizontal stroke."""
    pts = 15
    xs = [offset_x - size * 0.3 + size * 0.6 * i / (pts - 1) for i in range(pts)]
    ys = [offset_y] * pts
    return [{"x": xs, "y": ys}]


def generate_expression_strokes(num_terms: int) -> list[dict]:
    """Generate strokes for a polynomial: 3x + 5x + 2x + ... with `num_terms` terms.

    Returns a list of stroke dicts, each with 'x' and 'y' arrays.
    More terms = more strokes = bigger stress test.
    """
    strokes: list[dict] = []
    cursor_x = 50.0
    spacing = 100.0

    for i in range(num_terms):
        coeff = (i * 3 + 2) % 10  # varying coefficients
        # Coefficient digit
        strokes.append(_stroke_digit(coeff, offset_x=cursor_x, offset_y=100))
        cursor_x += 30
        # Variable x
        strokes.extend(_stroke_x_var(cursor_x, 100))
        cursor_x += 40

        # Plus or equals before next term (skip after last)
        if i < num_terms - 1:
            strokes.extend(_stroke_plus(cursor_x, 100))
            cursor_x += spacing * 0.5
        elif i == num_terms - 1:
            # Add = 0 at the end
            strokes.extend(_stroke_equals(cursor_x, 100))
            cursor_x += 40
            strokes.append(_stroke_digit(0, offset_x=cursor_x, offset_y=100))

    return strokes


# ---------------------------------------------------------------------------
# API helpers
# ---------------------------------------------------------------------------

def get_session(server: str, token: str) -> tuple[str, str]:
    """Acquire a Mathpix strokes session."""
    resp = httpx.post(
        f"{server}/ai/strokes-session",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["app_token"], data["strokes_session_id"]


def transcribe_strokes(
    server: str, token: str, strokes: list[dict],
    app_token: str | None = None, session_id: str | None = None,
) -> tuple[str, float]:
    """Send strokes to /ai/transcribe-strokes. Returns (latex, latency_ms)."""
    body: dict = {"strokes": strokes}
    if app_token and session_id:
        body["app_token"] = app_token
        body["session_id"] = session_id

    start = time.monotonic()
    resp = httpx.post(
        f"{server}/ai/transcribe-strokes",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json=body,
        timeout=30,
    )
    latency = (time.monotonic() - start) * 1000

    if resp.status_code != 200:
        return f"ERROR:{resp.status_code}", latency

    data = resp.json()
    return data.get("latex", data.get("raw_latex", "")), latency


def eval_tutor(
    server: str, token: str, doc_id: str, question_number: int,
    part_label: str, step_index: int,
) -> tuple[dict, float]:
    """Call /ai/tutor-evaluate. Returns (response_dict, latency_ms)."""
    body = {
        "document_id": doc_id,
        "question_number": question_number,
        "part_label": part_label,
        "step_index": step_index,
        "student_latex": "",  # server reads from student_work table
        "figure_urls": [],
    }
    start = time.monotonic()
    resp = httpx.post(
        f"{server}/ai/tutor-evaluate",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json=body,
        timeout=60,
    )
    latency = (time.monotonic() - start) * 1000

    if resp.status_code != 200:
        return {"error": resp.status_code, "detail": resp.text[:200]}, latency

    return resp.json(), latency


# ---------------------------------------------------------------------------
# Supabase helpers
# ---------------------------------------------------------------------------

def supabase_headers() -> dict[str, str]:
    key = ENV.get("SUPABASE_SERVICE_ROLE_KEY", "")
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def supabase_url() -> str:
    return ENV.get("SUPABASE_URL", "")


def setup_stress_doc(user_id: str) -> str:
    """Create a minimal document + answer key for the stress test."""
    doc_id = str(uuid.uuid4())
    url = supabase_url()
    h = supabase_headers()

    # Document
    httpx.post(f"{url}/rest/v1/documents", json={
        "id": doc_id, "user_id": user_id, "filename": "stress-test.pdf",
        "status": "completed", "page_count": 1, "problem_count": 1,
        "question_pages": [[0, 0]],
    }, headers=h, timeout=5)

    # Answer key with a simple step
    ak = {
        "question_number": 1,
        "steps": [],
        "final_answer": "0",
        "parts": [{
            "label": "a",
            "steps": [{
                "description": "Simplify the expression",
                "explanation": "Combine like terms",
                "work": "0",
                "reinforcement": "Simplified.",
                "tutor_speech": "Simplify.",
                "concepts": ["simplification"],
            }],
            "final_answer": "0",
            "parts": [],
        }],
    }
    httpx.post(f"{url}/rest/v1/answer_keys", json={
        "document_id": doc_id,
        "question_number": 1,
        "answer_text": json.dumps(ak),
        "question_json": json.dumps({"number": 1, "text": "Simplify", "parts": [{"label": "a", "text": "", "parts": []}]}),
        "model": "stress-test",
        "input_tokens": 0,
        "output_tokens": 0,
    }, headers=h, timeout=5)

    return doc_id


def write_student_work(doc_id: str, user_id: str, latex: str) -> None:
    """Upsert transcribed LaTeX to student_work table."""
    url = supabase_url()
    h = supabase_headers()
    h["Prefer"] = "resolution=merge-duplicates"
    httpx.post(f"{url}/rest/v1/student_work", json={
        "user_id": user_id,
        "document_id": doc_id,
        "question_label": "Q1a",
        "latex_display": latex,
        "latex_raw": latex,
    }, headers=h, timeout=5)


def cleanup_doc(doc_id: str) -> None:
    """Delete stress test document and related records."""
    url = supabase_url()
    h = supabase_headers()
    for table in ["student_work", "chat_history", "answer_keys"]:
        httpx.delete(f"{url}/rest/v1/{table}?document_id=eq.{doc_id}", headers=h, timeout=5)
    httpx.delete(f"{url}/rest/v1/documents?id=eq.{doc_id}", headers=h, timeout=5)


# ---------------------------------------------------------------------------
# Main stress test
# ---------------------------------------------------------------------------

def run_stress_test(server: str, token: str, user_id: str, max_strokes: int, run_tutor: bool) -> None:
    print("\n  Stroke Stress Test")
    print(f"  Server: {server}")
    print(f"  Max strokes: {max_strokes}")
    print(f"  Tutor eval: {'yes' if run_tutor else 'no'}")

    # Get Mathpix session
    print("\n  Acquiring Mathpix session...")
    app_token, session_id = get_session(server, token)
    print(f"  Session: {session_id[:12]}...")

    # Setup document for tutor eval
    doc_id = None
    if run_tutor:
        print("  Creating stress test document...")
        doc_id = setup_stress_doc(user_id)
        print(f"  Document: {doc_id}")

    # Test rounds: increasing stroke counts
    rounds = [1, 2, 5, 10, 15, 20, 30, 50, 75, 100]
    rounds = [r for r in rounds if r <= max_strokes]

    results: list[dict] = []

    print(f"\n  {'Strokes':>8} {'Points':>8} {'Mathpix ms':>11} {'LaTeX':>40} {'Tutor ms':>10} {'Status':>10}")
    print("  " + "─" * 95)

    accumulated_latex = ""

    for num_terms in rounds:
        # Generate strokes for N terms: each term ≈ 4 strokes (digit + x + operator)
        strokes = generate_expression_strokes(num_terms)
        stroke_count = len(strokes)
        point_count = sum(len(s["x"]) for s in strokes)

        # Cap at 100 strokes (server limit)
        if stroke_count > 100:
            strokes = strokes[:100]
            stroke_count = 100
            point_count = sum(len(s["x"]) for s in strokes)

        # Transcribe
        latex, mathpix_ms = transcribe_strokes(
            server, token, strokes, app_token=app_token, session_id=session_id
        )

        tutor_ms_str = "—"
        tutor_status = "—"

        if run_tutor and doc_id and not latex.startswith("ERROR"):
            accumulated_latex = latex  # replace (not accumulate) for stress test
            write_student_work(doc_id, user_id, accumulated_latex)
            eval_resp, tutor_ms = eval_tutor(server, token, doc_id, 1, "a", 0)
            tutor_ms_str = f"{tutor_ms:.0f}"
            tutor_status = eval_resp.get("status", eval_resp.get("error", "?"))

        latex_display = latex[:38] + ".." if len(latex) > 40 else latex
        print(f"  {stroke_count:>8} {point_count:>8} {mathpix_ms:>10.0f} {latex_display:>40} {tutor_ms_str:>10} {tutor_status:>10}")

        results.append({
            "strokes": stroke_count,
            "points": point_count,
            "mathpix_ms": round(mathpix_ms),
            "latex": latex,
            "tutor_ms": tutor_ms_str,
            "tutor_status": tutor_status,
        })

        # Stop if Mathpix failed
        if latex.startswith("ERROR"):
            print(f"\n  Mathpix failed at {stroke_count} strokes. Stopping.")
            break

    # Cleanup
    if doc_id:
        print(f"\n  Cleaning up document {doc_id}...")
        cleanup_doc(doc_id)

    # Summary
    print("\n  Summary")
    print("  " + "─" * 40)
    successful = [r for r in results if not r["latex"].startswith("ERROR")]
    if successful:
        max_ok = max(r["strokes"] for r in successful)
        avg_mathpix = sum(r["mathpix_ms"] for r in successful) / len(successful)
        print(f"  Max successful strokes: {max_ok}")
        print(f"  Avg Mathpix latency:    {avg_mathpix:.0f}ms")
        if any(r["tutor_ms"] != "—" for r in successful):
            tutor_times = [float(r["tutor_ms"]) for r in successful if r["tutor_ms"] != "—"]
            if tutor_times:
                print(f"  Avg tutor latency:      {sum(tutor_times)/len(tutor_times):.0f}ms")
    failed = [r for r in results if r["latex"].startswith("ERROR")]
    if failed:
        print(f"  First failure at:       {failed[0]['strokes']} strokes")
    print()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Stroke stress test for Mathpix + tutor pipeline")
    parser.add_argument("--server", default="https://api.studyreef.com")
    parser.add_argument("--token", help="Supabase JWT token")
    parser.add_argument("--max-strokes", type=int, default=100, help="Max strokes to test (default 100)")
    parser.add_argument("--no-tutor", action="store_true", help="Skip tutor eval, only test Mathpix")
    args = parser.parse_args()

    if not args.token:
        # Try to get token from env
        anon_key = ENV.get("SUPABASE_ANON_KEY", "")
        supa_url = ENV.get("SUPABASE_URL", "")
        if anon_key and supa_url:
            print("  No --token provided, signing in as sim@studyreef.com...")
            resp = httpx.post(
                f"{supa_url}/auth/v1/token?grant_type=password",
                headers={"apikey": anon_key, "Content-Type": "application/json"},
                json={"email": "sim@studyreef.com", "password": "SimTest123!"},
                timeout=10,
            )
            if resp.status_code == 200:
                data = resp.json()
                args.token = data["access_token"]
                user_id = data["user"]["id"]
            else:
                print(f"  Auth failed: {resp.status_code}")
                sys.exit(1)
        else:
            print("  No --token and no env vars. Provide --token.")
            sys.exit(1)
    else:
        # Decode user_id from token
        import base64
        payload = args.token.split(".")[1]
        payload += "=" * (4 - len(payload) % 4)
        user_id = json.loads(base64.b64decode(payload))["sub"]

    run_stress_test(args.server, args.token, user_id, args.max_strokes, not args.no_tutor)


if __name__ == "__main__":
    main()
