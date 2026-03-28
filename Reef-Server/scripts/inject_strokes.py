#!/usr/bin/env python3
"""Inject LaTeX as handwriting strokes onto a connected iPad canvas.

Writes stroke data directly to Supabase `simulation_strokes` table.
The iPad subscribes to realtime changes and renders strokes automatically.

Usage:
    python scripts/inject_strokes.py "3x + 5"
    python scripts/inject_strokes.py "f'(x) = 6x + 5" --y 200
    python scripts/inject_strokes.py --doc-id <id>   # interactive mode with question context
"""

import argparse
import json
import os
import sys

import httpx

_here = os.path.dirname(os.path.abspath(__file__))
_server_root = os.path.dirname(_here)
if _server_root not in sys.path:
    sys.path.insert(0, _server_root)

from app.services.latex2strokes import latex_to_strokes


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
DEFAULT_USER_ID = "a24e261a-313b-450a-88c5-7653e2ece357"


def supabase_headers() -> dict[str, str]:
    key = ENV.get("SUPABASE_SERVICE_ROLE_KEY", "")
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


def send_strokes(latex: str, user_id: str, doc_id: str, question_label: str,
                  origin_x: float, origin_y: float) -> bool:
    """Convert LaTeX to strokes and insert into simulation_strokes table."""
    strokes = latex_to_strokes(latex, origin_x=origin_x, origin_y=origin_y, jitter=False)
    url = ENV.get("SUPABASE_URL", "")

    resp = httpx.post(
        f"{url}/rest/v1/simulation_strokes",
        headers=supabase_headers(),
        json={
            "user_id": user_id,
            "document_id": doc_id,
            "question_label": question_label,
            "strokes": strokes,
            "latex": latex,
            "origin_x": origin_x,
            "origin_y": origin_y,
        },
        timeout=5,
    )

    if resp.status_code in (200, 201):
        print(f"  ✓ Sent {len(strokes)} strokes: {latex[:50]}")
        return True
    else:
        print(f"  ✗ Supabase error {resp.status_code}: {resp.text[:200]}")
        return False


def show_doc_context(doc_id: str) -> tuple[str, list[dict]]:
    """Fetch and display question + answer key for a document. Returns (question_label, steps)."""
    url = ENV.get("SUPABASE_URL", "")
    resp = httpx.get(
        f"{url}/rest/v1/answer_keys?document_id=eq.{doc_id}&select=answer_text,question_json",
        headers=supabase_headers(), timeout=5,
    )
    if resp.status_code != 200 or not resp.json():
        print(f"  No answer key found for {doc_id}")
        return "Q1a", []

    row = resp.json()[0]
    q_json = row.get("question_json", {})
    if isinstance(q_json, str):
        q_json = json.loads(q_json)
    ak = row.get("answer_text", "")
    if isinstance(ak, str):
        ak = json.loads(ak)

    q_num = q_json.get("number", ak.get("question_number", 1))
    parts = ak.get("parts", [])
    part_label = parts[0].get("label", "a") if parts else ""
    question_label = f"Q{q_num}{part_label}"
    steps = parts[0].get("steps", []) if parts else ak.get("steps", [])

    print(f"\n  Document: {doc_id}")
    print(f"  Question: {q_json.get('text', '?')[:80]}")
    print(f"  Label: {question_label}  Steps: {len(steps)}")
    for i, s in enumerate(steps):
        print(f"    Step {i+1}: {s.get('description', '')[:55]}")
        print(f"      Work: {s.get('work', '')[:55]}")
    print()

    return question_label, steps


def main():
    parser = argparse.ArgumentParser(description="Inject LaTeX as strokes onto connected iPad")
    parser.add_argument("latex", nargs="?", help="LaTeX expression to inject")
    parser.add_argument("--user-id", default=DEFAULT_USER_ID, help="Target user ID")
    parser.add_argument("--doc-id", default="", help="Document ID for context + realtime targeting")
    parser.add_argument("--question-label", default="Q1a", help="Question label (default Q1a)")
    parser.add_argument("--x", type=float, default=30.0, help="X origin")
    parser.add_argument("--y", type=float, default=150.0, help="Y origin")
    args = parser.parse_args()

    question_label = args.question_label
    steps: list[dict] = []

    if args.doc_id:
        question_label, steps = show_doc_context(args.doc_id)

    if args.latex:
        print(f"  Injecting: {args.latex}")
        send_strokes(args.latex, args.user_id, args.doc_id, question_label, args.x, args.y)
    else:
        # Interactive mode
        print(f"  Interactive mode. Type LaTeX to inject. /quit to exit.")
        print(f"  User: {args.user_id}  Doc: {args.doc_id or '(none)'}  Label: {question_label}")
        y = args.y
        while True:
            try:
                latex = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if not latex or latex == "/quit":
                break
            if latex.startswith("/correct") and steps:
                # Auto-inject correct work for current step
                parts = latex.split()
                step_num = int(parts[1]) - 1 if len(parts) > 1 else 0
                if 0 <= step_num < len(steps):
                    latex = steps[step_num].get("work", "")
                    print(f"  [correct] Step {step_num+1}: {latex[:50]}")
                else:
                    print(f"  [error] Step {parts[1]} not found")
                    continue
            print(f"  Injecting at y={y:.0f}...")
            send_strokes(latex, args.user_id, args.doc_id, question_label, args.x, y)
            y += 50


if __name__ == "__main__":
    main()
