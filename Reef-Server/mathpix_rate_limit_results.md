# Mathpix Strokes API — Rate Limit & Shared Session Test Results

**Date:** 2026-03-07

## Key Findings

1. **No rate limits observed** — up to 500 concurrent requests and 203 req/s sustained, zero 429s
2. **Shared sessions work** — multiple users sharing one `session_id` get correct, independent results
3. **Sessions expire exactly on schedule** — a 60s session returned 401 at t=62s

## Session Sharing

Each request sends the **full canvas**, so the session ID is just an auth/billing token — no cross-user contamination. Shared vs separate sessions produced identical recognition results.

## Latency vs Concurrent Users (Shared Session)

| Concurrent Users | Avg Latency | Min | Max |
|---|---|---|---|
| 10 | 0.30s | 0.19s | 0.43s |
| 25 | 0.38s | 0.21s | 1.10s |
| 50 | 0.34s | 0.26s | 0.42s |
| 100 | 0.38s | 0.31s | 0.45s |
| 200 | 0.96s | 0.54s | 1.19s |
| 500 | 6.92s | 3.69s | 8.26s |

**Sweet spot:** ≤100 concurrent users per session (~0.35s avg latency).

## Sustained Load (users sending every 100ms for 5s)

| Users | Total Requests | Throughput | Failures |
|---|---|---|---|
| 10 | 303 | 59 req/s | 0 |
| 25 | 711 | 138 req/s | 0 |
| 50 | 1,055 | 203 req/s | 0 |

## Recommendation

Share a single 5-minute session across users. Shard to multiple sessions if concurrent users exceed ~100 (to keep latency under 0.5s). Debounce client-side to reduce request volume.
