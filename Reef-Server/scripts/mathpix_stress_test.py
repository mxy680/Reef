"""Brute-force test Mathpix strokes API to find practical limits.

Tests:
1. Sequential rapid-fire: how fast can we send back-to-back requests?
2. Concurrent burst: fire N requests simultaneously, see what happens
3. Latency under load: does response time degrade with frequency?
4. Ordering: do responses come back in send order?
5. Rate limit detection: at what point does Mathpix reject/throttle?

Usage: export $(grep -v '^#' .env | xargs) && uv run python scripts/mathpix_stress_test.py
"""

import asyncio
import json
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
    """Generate n simple strokes (horizontal lines at different Y positions)."""
    xs = []
    ys = []
    for i in range(n_strokes):
        # Each stroke is a short horizontal line
        xs.append([50.0 + j * 10 for j in range(5)])
        ys.append([100.0 + i * 40] * 5)
    return {"strokes": {"x": xs, "y": ys}}


async def send_strokes(client: httpx.AsyncClient, app_token: str, session_id: str,
                       strokes: dict, request_id: int) -> dict:
    """Send strokes and return timing + result info."""
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
            latex = f"HTTP {status}: {resp.text[:100]}"
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
        "latex": latex[:60],
        "confidence": confidence,
        "error": data.get("error", ""),
    }


async def test_sequential_rapid_fire(app_token: str, session_id: str):
    """Send requests one after another as fast as possible."""
    print("\n=== TEST 1: Sequential Rapid-Fire (20 requests) ===")
    async with httpx.AsyncClient() as client:
        results = []
        for i in range(20):
            # Incrementally add strokes (simulating drawing)
            strokes = make_strokes(i + 1)
            r = await send_strokes(client, app_token, session_id, strokes, i)
            results.append(r)
            print(f"  #{i:2d}: {r['latency_ms']:6.0f}ms  status={r['status']}  latex={r['latex'][:40]}")

    latencies = [r["latency_ms"] for r in results if r["status"] == 200]
    if latencies:
        print(f"\n  Summary: min={min(latencies):.0f}ms, avg={sum(latencies)/len(latencies):.0f}ms, "
              f"max={max(latencies):.0f}ms, success={len(latencies)}/20")
    return results


async def test_concurrent_burst(app_token: str, session_id: str, n: int = 10):
    """Fire N requests simultaneously."""
    print(f"\n=== TEST 2: Concurrent Burst ({n} simultaneous) ===")
    async with httpx.AsyncClient() as client:
        strokes = make_strokes(3)  # Same strokes for all
        tasks = [send_strokes(client, app_token, session_id, strokes, i) for i in range(n)]
        t_start = time.perf_counter()
        results = await asyncio.gather(*tasks)
        t_total = (time.perf_counter() - t_start) * 1000

    for r in sorted(results, key=lambda x: x["latency_ms"]):
        print(f"  #{r['request_id']:2d}: {r['latency_ms']:6.0f}ms  status={r['status']}  "
              f"error={r['error'] or 'none'}")

    successes = [r for r in results if r["status"] == 200]
    failures = [r for r in results if r["status"] != 200]
    print(f"\n  Wall time: {t_total:.0f}ms, success={len(successes)}/{n}, failures={len(failures)}")
    if failures:
        for f in failures:
            print(f"  FAIL: status={f['status']} latex={f['latex']}")
    return results


async def test_sustained_rate(app_token: str, session_id: str, rps: float, duration_s: float):
    """Sustain a fixed request rate and measure success/failure."""
    n = int(rps * duration_s)
    interval = 1.0 / rps
    print(f"\n=== TEST 3: Sustained {rps} req/s for {duration_s}s ({n} total) ===")

    results = []
    async with httpx.AsyncClient() as client:
        strokes = make_strokes(3)
        t_test_start = time.perf_counter()

        async def fire(i, delay):
            await asyncio.sleep(delay)
            return await send_strokes(client, app_token, session_id, strokes, i)

        tasks = [fire(i, i * interval) for i in range(n)]
        results = await asyncio.gather(*tasks)
        t_test_end = time.perf_counter()

    successes = [r for r in results if r["status"] == 200]
    failures = [r for r in results if r["status"] != 200]
    latencies = [r["latency_ms"] for r in successes]

    print(f"  Actual duration: {t_test_end - t_test_start:.1f}s")
    print(f"  Success: {len(successes)}/{n}")
    if failures:
        status_counts = {}
        for f in failures:
            status_counts[f["status"]] = status_counts.get(f["status"], 0) + 1
        print(f"  Failures by status: {status_counts}")
        for f in failures[:3]:
            print(f"    #{f['request_id']}: status={f['status']} {f['latex'][:80]}")
    if latencies:
        latencies.sort()
        p50 = latencies[len(latencies) // 2]
        p90 = latencies[int(len(latencies) * 0.9)]
        p99 = latencies[int(len(latencies) * 0.99)] if len(latencies) > 10 else latencies[-1]
        print(f"  Latency: p50={p50:.0f}ms, p90={p90:.0f}ms, p99={p99:.0f}ms")
    return results


async def test_concurrent_escalation(app_token: str, session_id: str):
    """Escalate concurrent requests to find the breaking point."""
    print("\n=== TEST 4: Concurrent Escalation ===")
    for n in [1, 2, 5, 10, 20, 30, 50]:
        async with httpx.AsyncClient() as client:
            strokes = make_strokes(3)
            tasks = [send_strokes(client, app_token, session_id, strokes, i) for i in range(n)]
            t_start = time.perf_counter()
            results = await asyncio.gather(*tasks)
            t_total = (time.perf_counter() - t_start) * 1000

        successes = len([r for r in results if r["status"] == 200])
        latencies = [r["latency_ms"] for r in results if r["status"] == 200]
        avg_lat = sum(latencies) / len(latencies) if latencies else 0
        errors = [r for r in results if r["status"] != 200]
        err_str = ""
        if errors:
            err_str = f"  errors: {[r['status'] for r in errors[:3]]}"
        print(f"  n={n:3d}: {successes}/{n} ok, avg={avg_lat:6.0f}ms, wall={t_total:6.0f}ms{err_str}")

        if successes < n * 0.5:
            print(f"  >>> Breaking point around n={n}")
            break

        # Brief pause between escalation levels
        await asyncio.sleep(1.0)


async def main():
    print("Creating Mathpix session...")
    session_id, app_token = await create_session()
    print(f"Session: {session_id[:20]}...")

    await test_sequential_rapid_fire(app_token, session_id)
    await asyncio.sleep(2.0)

    await test_concurrent_burst(app_token, session_id, n=10)
    await asyncio.sleep(2.0)

    await test_concurrent_escalation(app_token, session_id)
    await asyncio.sleep(2.0)

    # Sustained rates: 2/s, 5/s, 10/s
    for rps in [2, 5, 10]:
        await test_sustained_rate(app_token, session_id, rps=rps, duration_s=5.0)
        await asyncio.sleep(2.0)

    print("\n=== DONE ===")


if __name__ == "__main__":
    asyncio.run(main())
