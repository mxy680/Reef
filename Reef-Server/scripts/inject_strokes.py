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
    parser.add_argument("latex", help="LaTeX expression to inject")
    parser.add_argument("--server", default="https://api.studyreef.com", help="API base URL")
    parser.add_argument("--user-id", help="Target user ID (auto-detected from server logs if omitted)")
    parser.add_argument("--x", type=float, default=50.0, help="X origin (default 50)")
    parser.add_argument("--y", type=float, default=100.0, help="Y origin (default 100)")
    args = parser.parse_args()

    env = _load_env()
    user_id = args.user_id or "a24e261a-313b-450a-88c5-7653e2ece357"  # default: Mark's account

    print(f"  Injecting: {args.latex}")
    print(f"  Server: {args.server}")
    print(f"  User: {user_id}")
    print(f"  Position: ({args.x}, {args.y})")

    resp = httpx.post(
        f"{args.server}/ai/simulation/inject",
        headers={"Content-Type": "application/json"},
        json={"latex": args.latex, "user_id": user_id, "origin_x": args.x, "origin_y": args.y},
        timeout=15,
    )

    if resp.status_code == 200:
        data = resp.json()
        print(f"  ✓ Sent {data['strokes_count']} strokes")
    elif resp.status_code == 404:
        print(f"  ✗ No WebSocket connection. Tap the play button on the iPad first.")
    else:
        print(f"  ✗ Error {resp.status_code}: {resp.text[:200]}")


if __name__ == "__main__":
    main()
