"""Mathpix strokes API — find the actual breaking point.

Escalates sustained rate from 20 to 100 req/s, then tests
realistic "transcribe every stroke" patterns.

Usage: export $(grep -v '^#' .env | xargs) && uv run python scripts/mathpix_stress_test_v2.py
"""

import asyncio
import os
import time

import httpx

MATHPIX_BASE = "https://api.mathpix.com"


def _get_credentials():
    app_id = os.environ.get("MATHPIX_APP_ID", "").strip('"')
    app_key = os.environ.get("MATHPIX_APP_KEY", "").strip('"')
    if not app_id or not app_key:
        raise RuntimeError("MATHPIX_APP_ID and MATHPIX_APP_KEY not set")
    return app_id, app_key


async def create_session():
    app_id, app_key = _get_credentials()
    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{MATHPIX_BASE}/v3/app-tokens",
            headers={"app_id": app_id, "app_key": app_key, "Content-Type": "application/json"},
            json={"include_strokes_session_id": True},
        )
        resp.raise_for_status()
        data = resp.json()
    return data["strokes_session_id"], data["app_token"]


def make_strokes(n_strokes: int):
    """Generate n strokes that look like handwritten math (x + 1 = 2 ish)."""
    # Simple: horizontal lines at different Y, simulating writing lines
    xs = []
    ys = []
    for i in range(n_strokes):
        xs.append([50.0 + j * 10 for j in range(5)])
        ys.append([100.0 + i * 40] * 5)
    return {"strokes": {"x": xs, "y": ys}}


def make_realistic_strokes(progress: float):
    """Simulate a student writing 'x + 1 = 2' progressively.

    progress: 0.0 to 1.0 — how much of the expression is written.
    """
    # Full expression has ~8 strokes
    full_strokes_x = [
        # 'x' - two diagonal strokes
        [50, 60, 70, 80], [80, 70, 60, 50],
        # '+' - horizontal and vertical
        [110, 120, 130, 140], [125, 125, 125, 125],
        # '1' - vertical stroke
        [170, 170, 170, 170],
        # '=' - two horizontal lines
        [200, 210, 220, 230], [200, 210, 220, 230],
        # '2' - approximate
        [260, 270, 280, 280, 270, 260],
    ]
    full_strokes_y = [
        [100, 120, 140, 160], [140, 120, 140, 160],
        [130, 130, 130, 130], [110, 120, 130, 150],
        [100, 120, 140, 160],
        [120, 120, 120, 120], [140, 140, 140, 140],
        [100, 100, 100, 120, 140, 140],
    ]
    n = max(1, int(len(full_strokes_x) * progress))
    return {"strokes": {"x": full_strokes_x[:n], "y": full_strokes_y[:n]}}


async def send_strokes(client: httpx.AsyncClient, app_token: str, session_id: str,
                       strokes: dict, request_id: int) -> dict:
    t_start = time.perf_counter()
    try:
        resp = await client.post(
            f"{MATHPIX_BASE}/v3/strokes",
            headers={"app_token": app_token, "Content-Type": "application/json"},
            json={"strokes_session_id": session_id, "strokes": strokes},
            timeout=30.0,
        )
        t_end = time.perf_counter()
        status = resp.status_code
        if status == 200:
            data = resp.json()
            latex = data.get("latex_styled", "") or data.get("text", "")
            confidence = data.get("confidence", 0)
        else:
            latex = f"HTTP {status}: {resp.text[:200]}"
            confidence = 0
            data = {}
    except Exception as e:
        t_end = time.perf_counter()
        status = -1
        latex = str(e)[:100]
        confidence = 0
        data = {}

    return {
        "request_id": request_id,
        "status": status,
        "latency_ms": (t_end - t_start) * 1000,
        "latex": latex[:80],
        "confidence": confidence,
        "error": data.get("error", ""),
        "t_sent": t_start,
        "t_received": t_end,
    }


async def test_sustained_rate(app_token: str, session_id: str, rps: float, duration_s: float):
    n = int(rps * duration_s)
    interval = 1.0 / rps
    print(f"\n--- Sustained {rps} req/s for {duration_s}s ({n} total) ---")

    async with httpx.AsyncClient() as client:
        strokes = make_strokes(3)

        async def fire(i, delay):
            await asyncio.sleep(delay)
            return await send_strokes(client, app_token, session_id, strokes, i)

        tasks = [fire(i, i * interval) for i in range(n)]
        t_start = time.perf_counter()
        results = await asyncio.gather(*tasks)
        t_total = time.perf_counter() - t_start

    successes = [r for r in results if r["status"] == 200]
    failures = [r for r in results if r["status"] != 200]
    latencies = sorted([r["latency_ms"] for r in successes])

    print(f"  Duration: {t_total:.1f}s, Success: {len(successes)}/{n}")
    if failures:
        status_counts = {}
        for f in failures:
            status_counts[f["status"]] = status_counts.get(f["status"], 0) + 1
        print(f"  Failures: {status_counts}")
        for f in failures[:5]:
            print(f"    #{f['request_id']}: {f['latex'][:100]}")
    if latencies:
        p50 = latencies[len(latencies) // 2]
        p90 = latencies[int(len(latencies) * 0.9)]
        p99 = latencies[min(int(len(latencies) * 0.99), len(latencies) - 1)]
        print(f"  Latency: p50={p50:.0f}ms, p90={p90:.0f}ms, p99={p99:.0f}ms, max={latencies[-1]:.0f}ms")
    return results


async def test_realistic_drawing_simulation(app_token: str, session_id: str):
    """Simulate a student drawing and transcribing after every stroke."""
    print("\n=== REALISTIC: Transcribe after every stroke (8 strokes, 300ms apart) ===")
    async with httpx.AsyncClient() as client:
        results = []
        for i in range(8):
            progress = (i + 1) / 8.0
            strokes = make_realistic_strokes(progress)
            r = await send_strokes(client, app_token, session_id, strokes, i)
            results.append(r)
            print(f"  stroke {i+1}/8: {r['latency_ms']:5.0f}ms  latex={r['latex'][:50]}")
            # Simulate ~300ms between pen lifts
            await asyncio.sleep(0.3)

    latencies = [r["latency_ms"] for r in results]
    print(f"  Avg: {sum(latencies)/len(latencies):.0f}ms")


async def test_fire_and_forget_latest_wins(app_token: str, session_id: str):
    """Fire overlapping requests, only care about the latest result.

    Simulates: transcribe on every stroke, but only use the most recent
    completed response. This is the 'always-warm transcription' pattern.
    """
    print("\n=== FIRE-AND-FORGET: 20 overlapping requests, latest-wins ===")
    async with httpx.AsyncClient() as client:
        results = []
        tasks = []

        for i in range(20):
            progress = min(1.0, (i + 1) / 20.0)
            strokes = make_realistic_strokes(progress)
            task = asyncio.create_task(
                send_strokes(client, app_token, session_id, strokes, i)
            )
            tasks.append((i, task))
            # 50ms between fires (simulating fast drawing)
            await asyncio.sleep(0.05)

        # Wait for all to complete
        for i, task in tasks:
            r = await task
            results.append(r)

    # Sort by completion time
    results.sort(key=lambda r: r["t_received"])

    print("  Completion order (by receive time):")
    for r in results:
        sent_offset = (r["t_sent"] - results[0]["t_sent"]) * 1000
        recv_offset = (r["t_received"] - results[0]["t_received"]) * 1000
        print(f"    req#{r['request_id']:2d}: sent=+{sent_offset:5.0f}ms, "
              f"recv=+{recv_offset:5.0f}ms, lat={r['latency_ms']:5.0f}ms, "
              f"latex={r['latex'][:30]}")

    # The "latest wins" result
    latest_sent = max(results, key=lambda r: r["request_id"])
    first_done = min(results, key=lambda r: r["t_received"])
    print(f"\n  Latest request (#{latest_sent['request_id']}): "
          f"completed in {latest_sent['latency_ms']:.0f}ms")
    print(f"  First to complete (#{first_done['request_id']}): "
          f"completed in {first_done['latency_ms']:.0f}ms")

    # What if we just used the first response that completed after the last send?
    last_send_time = max(r["t_sent"] for r in results)
    valid = [r for r in results if r["t_received"] >= last_send_time]
    if valid:
        best = min(valid, key=lambda r: r["t_received"])
        wait_after_last = (best["t_received"] - last_send_time) * 1000
        print(f"  First valid after last send (#{best['request_id']}): "
              f"wait={wait_after_last:.0f}ms, latex={best['latex'][:40]}")


async def test_concurrent_escalation_extreme(app_token: str, session_id: str):
    """Push concurrent requests to extreme levels."""
    print("\n=== CONCURRENT ESCALATION: Finding the ceiling ===")
    for n in [50, 75, 100, 150, 200]:
        async with httpx.AsyncClient() as client:
            strokes = make_strokes(3)
            tasks = [send_strokes(client, app_token, session_id, strokes, i) for i in range(n)]
            t_start = time.perf_counter()
            results = await asyncio.gather(*tasks)
            t_total = (time.perf_counter() - t_start) * 1000

        successes = len([r for r in results if r["status"] == 200])
        latencies = sorted([r["latency_ms"] for r in results if r["status"] == 200])
        avg = sum(latencies) / len(latencies) if latencies else 0
        p99 = latencies[int(len(latencies) * 0.99)] if len(latencies) > 1 else (latencies[0] if latencies else 0)
        errors = [r for r in results if r["status"] != 200]
        err_str = ""
        if errors:
            err_codes = set(r["status"] for r in errors)
            err_str = f"  errors: {err_codes}"
            # Print first error detail
            print(f"    First error: {errors[0]['latex'][:100]}")
        print(f"  n={n:4d}: {successes}/{n} ok, avg={avg:5.0f}ms, p99={p99:5.0f}ms, wall={t_total:6.0f}ms{err_str}")

        if successes < n * 0.8:
            print(f"  >>> Ceiling around n={n}")
            break

        await asyncio.sleep(2.0)


async def main():
    print("Creating Mathpix session...")
    session_id, app_token = await create_session()
    print(f"Session: {session_id[:20]}...")

    # Part 1: Find the breaking point
    print("\n" + "=" * 60)
    print("PART 1: FINDING THE BREAKING POINT")
    print("=" * 60)

    for rps in [20, 30, 50, 75, 100]:
        results = await test_sustained_rate(app_token, session_id, rps=rps, duration_s=5.0)
        failures = [r for r in results if r["status"] != 200]
        if len(failures) > len(results) * 0.2:
            print(f"\n>>> Rate limit hit around {rps} req/s")
            break
        await asyncio.sleep(3.0)

    await test_concurrent_escalation_extreme(app_token, session_id)

    # Part 2: Realistic exploitation patterns
    print("\n" + "=" * 60)
    print("PART 2: EXPLOITATION PATTERNS")
    print("=" * 60)

    # Fresh session for realistic tests
    session_id2, app_token2 = await create_session()

    await test_realistic_drawing_simulation(app_token2, session_id2)
    await asyncio.sleep(1.0)
    await test_fire_and_forget_latest_wins(app_token2, session_id2)

    print("\n=== DONE ===")


if __name__ == "__main__":
    asyncio.run(main())
