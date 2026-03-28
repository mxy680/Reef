#!/usr/bin/env python3
"""Inject LaTeX as handwriting strokes onto a connected iPad canvas.

The iPad must have the simulation WebSocket open (tap the play button).
This script sends LaTeX → server converts to strokes → pushes via WebSocket → iPad renders.

Usage:
    python scripts/inject_strokes.py "3x + 5"
    python scripts/inject_strokes.py "f'(x) = 6x + 5" --y 200
    python scripts/inject_strokes.py "\frac{y^2}{2} = x^2 + C" --server https://api.studyreef.com
"""

import argparse
import os
import sys

import httpx


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


def get_token(env: dict[str, str]) -> str:
    resp = httpx.post(
        f"{env['SUPABASE_URL']}/auth/v1/token?grant_type=password",
        headers={"apikey": env["SUPABASE_ANON_KEY"], "Content-Type": "application/json"},
        json={"email": "sim@studyreef.com", "password": "SimTest123!"},
        timeout=10,
    )
    if resp.status_code != 200:
        print(f"Auth failed: {resp.status_code}")
        sys.exit(1)
    return resp.json()["access_token"]


def main():
    parser = argparse.ArgumentParser(description="Inject LaTeX as strokes onto connected iPad")
    parser.add_argument("latex", nargs="?", help="LaTeX expression to inject (or use --doc-id for interactive)")
    parser.add_argument("--server", default="https://api.studyreef.com", help="API base URL")
    parser.add_argument("--user-id", help="Target user ID (auto-detected from server logs if omitted)")
    parser.add_argument("--doc-id", help="Document ID — shows question + answer key for context")
    parser.add_argument("--x", type=float, default=30.0, help="X origin (default 30)")
    parser.add_argument("--y", type=float, default=150.0, help="Y origin (default 150, below question text)")
    args = parser.parse_args()

    env = _load_env()
    user_id = args.user_id or "a24e261a-313b-450a-88c5-7653e2ece357"

    def send(latex: str, x: float, y: float):
        resp = httpx.post(
            f"{args.server}/ai/simulation/inject",
            headers={"Content-Type": "application/json"},
            json={"latex": latex, "user_id": user_id, "origin_x": x, "origin_y": y},
            timeout=15,
        )
        if resp.status_code == 200:
            print(f"  ✓ Sent {resp.json()['strokes_count']} strokes")
        elif resp.status_code == 404:
            print(f"  ✗ No WebSocket connection. Tap play on iPad first.")
        else:
            print(f"  ✗ Error {resp.status_code}: {resp.text[:200]}")

    # Show document context if --doc-id provided
    if args.doc_id:
        h = {"apikey": env.get("SUPABASE_SERVICE_ROLE_KEY", ""),
             "Authorization": f"Bearer {env.get('SUPABASE_SERVICE_ROLE_KEY', '')}"}
        url = env.get("SUPABASE_URL", "")
        ak_resp = httpx.get(f"{url}/rest/v1/answer_keys?document_id=eq.{args.doc_id}&select=answer_text,question_json",
                            headers=h, timeout=5)
        if ak_resp.status_code == 200 and ak_resp.json():
            import json
            row = ak_resp.json()[0]
            q_json = row.get("question_json", {})
            if isinstance(q_json, str):
                q_json = json.loads(q_json)
            ak = row.get("answer_text", "")
            if isinstance(ak, str):
                ak = json.loads(ak)
            print(f"\n  Document: {args.doc_id}")
            print(f"  Question: {q_json.get('text', '?')[:80]}")
            parts = ak.get("parts", [])
            if parts:
                steps = parts[0].get("steps", [])
                for i, s in enumerate(steps):
                    print(f"  Step {i+1}: {s.get('description', '')[:60]}")
                    print(f"    Work: {s.get('work', '')[:60]}")
            print()

    if args.latex:
        print(f"  Injecting: {args.latex}")
        print(f"  Position: ({args.x}, {args.y})")
        send(args.latex, args.x, args.y)
    else:
        # Interactive mode
        print(f"  Interactive mode. Type LaTeX to inject. /quit to exit.")
        print(f"  Server: {args.server}  User: {user_id}")
        y = args.y
        while True:
            try:
                latex = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if not latex or latex == "/quit":
                break
            print(f"  Injecting at y={y:.0f}...")
            send(latex, args.x, y)
            y += 50  # move down for next line


if __name__ == "__main__":
    main()
