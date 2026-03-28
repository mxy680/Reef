#!/usr/bin/env python3
"""Validate latex2strokes output by round-tripping through Mathpix.

Usage:
    python scripts/validate_strokes.py "3x + 5" --server https://api.studyreef.com --token <jwt>
    python scripts/validate_strokes.py "\\frac{y^2}{2} = x^2 + C" --plot
    python scripts/validate_strokes.py "f'(x) = 6x + 5" --server http://localhost:8000 --token <jwt>

The --plot flag saves a PNG visualization of the strokes (requires matplotlib).
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

# Ensure Reef-Server root is on sys.path when run from repo root or Reef-Server/
_here = os.path.dirname(os.path.abspath(__file__))
_server_root = os.path.dirname(_here)
if _server_root not in sys.path:
    sys.path.insert(0, _server_root)

import httpx

from app.services.latex2strokes import latex_to_strokes


# ---------------------------------------------------------------------------
# Env loading (same as stress_test_strokes.py)
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
# Mathpix round-trip
# ---------------------------------------------------------------------------

def transcribe_strokes(
    server: str,
    token: str,
    strokes: list[dict],
) -> tuple[str, float]:
    """Send strokes to /ai/transcribe-strokes. Returns (latex, latency_ms)."""
    start = time.monotonic()
    resp = httpx.post(
        f"{server}/ai/transcribe-strokes",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"strokes": strokes},
        timeout=30,
    )
    latency = (time.monotonic() - start) * 1000

    if resp.status_code != 200:
        return f"ERROR:{resp.status_code} {resp.text[:100]}", latency

    data = resp.json()
    return data.get("latex", data.get("raw_latex", "")), latency


# ---------------------------------------------------------------------------
# Visualization
# ---------------------------------------------------------------------------

def plot_strokes(strokes: list[dict], output_path: str, title: str) -> None:
    """Draw stroke data as colored lines and save to PNG."""
    try:
        import matplotlib.pyplot as plt
        import matplotlib.cm as cm
    except ImportError:
        print("  matplotlib not installed. Run: pip install matplotlib")
        return

    fig, ax = plt.subplots(figsize=(12, 4))
    colors = cm.tab20.colors  # type: ignore[attr-defined]

    for idx, stroke in enumerate(strokes):
        xs = stroke["x"]
        ys = [-y for y in stroke["y"]]  # flip y so up = positive
        color = colors[idx % len(colors)]
        ax.plot(xs, ys, color=color, linewidth=2, marker="o", markersize=2)

    ax.set_aspect("equal")
    ax.set_title(title)
    ax.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=150)
    plt.close()
    print(f"  Saved plot: {output_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate latex2strokes by round-tripping through Mathpix"
    )
    parser.add_argument("latex", help="LaTeX expression to test (e.g. '3x + 5')")
    parser.add_argument("--server", default="https://api.studyreef.com", help="Reef server URL")
    parser.add_argument("--token", help="Supabase JWT token")
    parser.add_argument("--plot", action="store_true", help="Save stroke visualization as PNG")
    parser.add_argument("--plot-out", default="strokes.png", help="PNG output path (default: strokes.png)")
    parser.add_argument("--origin-x", type=float, default=50.0)
    parser.add_argument("--origin-y", type=float, default=100.0)
    parser.add_argument("--font-size", type=float, default=40.0)
    parser.add_argument("--no-jitter", action="store_true", help="Disable jitter for exact shapes")
    parser.add_argument("--seed", type=int, default=None, help="Random seed for jitter")
    parser.add_argument("--dump-strokes", action="store_true", help="Print raw stroke JSON")
    args = parser.parse_args()

    # --- Generate strokes ---
    print(f"\n  Input LaTeX:  {args.latex}")
    strokes = latex_to_strokes(
        args.latex,
        origin_x=args.origin_x,
        origin_y=args.origin_y,
        font_size=args.font_size,
        jitter=not args.no_jitter,
        seed=args.seed,
    )
    total_points = sum(len(s["x"]) for s in strokes)
    print(f"  Strokes:      {len(strokes)}")
    print(f"  Total points: {total_points}")

    if args.dump_strokes:
        print("\n  Stroke data:")
        print(json.dumps(strokes, indent=2))

    # --- Plot ---
    if args.plot:
        plot_strokes(strokes, args.plot_out, title=f"LaTeX: {args.latex}")

    # --- Mathpix round-trip ---
    if not args.token:
        # Try to auto-auth
        anon_key = ENV.get("SUPABASE_ANON_KEY", "")
        supa_url = ENV.get("SUPABASE_URL", "")
        if anon_key and supa_url:
            print("\n  No --token provided. Signing in as sim@studyreef.com...")
            resp = httpx.post(
                f"{supa_url}/auth/v1/token?grant_type=password",
                headers={"apikey": anon_key, "Content-Type": "application/json"},
                json={"email": "sim@studyreef.com", "password": "SimTest123!"},
                timeout=10,
            )
            if resp.status_code == 200:
                args.token = resp.json()["access_token"]
            else:
                print(f"  Auth failed: {resp.status_code}. Pass --token to continue.")
                sys.exit(1)
        else:
            print("\n  No --token and no env vars. Skipping Mathpix round-trip.")
            print("  Use --token <jwt> to test Mathpix recognition.")
            sys.exit(0)

    print(f"\n  Sending to Mathpix via {args.server}...")
    latex_out, latency_ms = transcribe_strokes(args.server, args.token, strokes)

    print(f"  Mathpix output: {latex_out}")
    print(f"  Latency:        {latency_ms:.0f}ms")

    # Simple comparison
    input_clean = args.latex.replace(" ", "").replace("\\", "")
    output_clean = latex_out.replace(" ", "").replace("\\", "")
    match = "MATCH" if input_clean.lower() == output_clean.lower() else "DIFFERS"
    print(f"  Comparison:     {match}")
    print()


if __name__ == "__main__":
    main()
