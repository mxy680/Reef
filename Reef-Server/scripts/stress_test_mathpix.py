"""Stress test Mathpix Strokes API — measure latency vs stroke count.

Generates synthetic handwriting strokes (math-like patterns) and sends
increasing numbers to the API, measuring response time and success rate.

Usage:
    python scripts/stress_test_mathpix.py

Output:
    docs/figs/mathpix_stress_test.png — line chart of latency vs strokes
"""

import asyncio
import json
import math
import os
import sys
import time

import httpx

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.config import settings


async def create_session() -> tuple[str, str]:
    """Create a Mathpix strokes session."""
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/app-tokens",
            headers={"app_key": settings.mathpix_app_key},
            json={"include_strokes_session_id": True, "expires": 300},
        )
    resp.raise_for_status()
    data = resp.json()
    return data["app_token"], data["strokes_session_id"]


def generate_stroke(cx: float, cy: float, char_type: str = "line") -> dict:
    """Generate a single synthetic stroke (x/y coordinate arrays)."""
    points = 20
    xs, ys = [], []

    if char_type == "line":
        # Horizontal line
        for i in range(points):
            t = i / (points - 1)
            xs.append(cx + t * 30)
            ys.append(cy + math.sin(t * 0.5) * 2)  # slight wobble
    elif char_type == "curve":
        # Sine curve (like part of an integral sign)
        for i in range(points):
            t = i / (points - 1)
            xs.append(cx + t * 25)
            ys.append(cy + math.sin(t * math.pi) * 15)
    elif char_type == "circle":
        # Circle-ish (like a zero or O)
        for i in range(points):
            angle = 2 * math.pi * i / (points - 1)
            xs.append(cx + 10 * math.cos(angle))
            ys.append(cy + 10 * math.sin(angle))
    elif char_type == "slash":
        # Diagonal line (like division or fraction bar)
        for i in range(points):
            t = i / (points - 1)
            xs.append(cx + t * 20)
            ys.append(cy - t * 25)

    return {"x": xs, "y": ys}


def generate_strokes(n: int) -> list[dict]:
    """Generate n synthetic strokes arranged in a grid pattern."""
    strokes = []
    types = ["line", "curve", "circle", "slash"]
    cols = max(1, int(math.sqrt(n)))

    for i in range(n):
        row = i // cols
        col = i % cols
        cx = col * 40 + 10
        cy = row * 40 + 10
        char_type = types[i % len(types)]
        strokes.append(generate_stroke(cx, cy, char_type))

    return strokes


async def send_strokes(
    token: str, session_id: str, strokes: list[dict]
) -> tuple[float, int, str]:
    """Send strokes to Mathpix and return (latency_ms, status_code, result_preview)."""
    payload = {
        "strokes": {
            "strokes": {
                "x": [s["x"] for s in strokes],
                "y": [s["y"] for s in strokes],
            }
        },
        "strokes_session_id": session_id,
    }

    headers = {"app_token": token, "Content-Type": "application/json"}

    start = time.monotonic()
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            "https://api.mathpix.com/v3/strokes",
            json=payload,
            headers=headers,
        )
    elapsed_ms = (time.monotonic() - start) * 1000

    result = ""
    if resp.status_code == 200:
        data = resp.json()
        result = data.get("latex", data.get("text", ""))[:80]

    return elapsed_ms, resp.status_code, result


async def main():
    print("Mathpix Strokes API Stress Test")
    print("=" * 60)

    if not settings.mathpix_app_key:
        print("ERROR: MATHPIX_APP_KEY not set")
        return

    # Test parameters
    stroke_counts = [1, 2, 5, 10, 20, 30, 50, 75, 100, 150, 200, 300, 500]
    results = []

    for count in stroke_counts:
        # Fresh session for each test to avoid session state interference
        try:
            token, session_id = await create_session()
        except Exception as e:
            print(f"  Failed to create session: {e}")
            break

        strokes = generate_strokes(count)

        # Run 3 trials and average
        latencies = []
        status = 0
        result_preview = ""
        for trial in range(3):
            try:
                # Fresh session per trial for clean measurement
                if trial > 0:
                    token, session_id = await create_session()
                lat, status, result_preview = await send_strokes(token, session_id, strokes)
                latencies.append(lat)
            except Exception as e:
                print(f"  {count} strokes, trial {trial}: ERROR {e}")
                latencies.append(-1)

        valid = [l for l in latencies if l > 0]
        if valid:
            avg_lat = sum(valid) / len(valid)
            min_lat = min(valid)
            max_lat = max(valid)
        else:
            avg_lat = min_lat = max_lat = -1

        results.append({
            "strokes": count,
            "avg_ms": round(avg_lat, 1),
            "min_ms": round(min_lat, 1),
            "max_ms": round(max_lat, 1),
            "status": status,
            "result": result_preview,
            "failures": len(latencies) - len(valid),
        })

        print(
            f"  {count:>4} strokes | avg {avg_lat:>7.1f}ms | "
            f"min {min_lat:>7.1f}ms | max {max_lat:>7.1f}ms | "
            f"status {status} | failures {len(latencies) - len(valid)}/3"
        )

        # Small delay between tests
        await asyncio.sleep(0.5)

    # Save results as JSON
    results_path = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "docs", "figs", "mathpix_stress_results.json",
    )
    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)

    # Generate chart
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        valid_results = [r for r in results if r["avg_ms"] > 0]
        x = [r["strokes"] for r in valid_results]
        y_avg = [r["avg_ms"] for r in valid_results]
        y_min = [r["min_ms"] for r in valid_results]
        y_max = [r["max_ms"] for r in valid_results]

        fig, ax = plt.subplots(figsize=(10, 6))
        ax.plot(x, y_avg, "o-", color="#4E8A97", linewidth=2, markersize=6, label="Average")
        ax.fill_between(x, y_min, y_max, alpha=0.2, color="#4E8A97", label="Min–Max range")
        ax.set_xlabel("Number of Strokes", fontsize=12)
        ax.set_ylabel("Latency (ms)", fontsize=12)
        ax.set_title("Mathpix Strokes API — Latency vs Stroke Count", fontsize=14, fontweight="bold")
        ax.legend()
        ax.grid(True, alpha=0.3)
        ax.set_xscale("log")

        # Add annotations for key thresholds
        ax.axhline(y=1000, color="orange", linestyle="--", alpha=0.5, label="1s threshold")
        ax.axhline(y=5000, color="red", linestyle="--", alpha=0.5, label="5s threshold")

        chart_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "docs", "figs", "mathpix_stress_test.png",
        )
        fig.savefig(chart_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
        print(f"\nChart saved to {chart_path}")

    except ImportError:
        print("\nmatplotlib not installed — skipping chart generation")
        print("Install with: pip install matplotlib")
        print(f"Raw results saved to {results_path}")


if __name__ == "__main__":
    asyncio.run(main())
