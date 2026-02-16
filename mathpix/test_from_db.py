"""
Test Mathpix /v3/strokes with real stroke data from the Reef PostgreSQL database.

Fetches recent stroke logs, converts Reef's stroke format to Mathpix format,
sends to Mathpix, and prints results alongside existing Gemini transcriptions.

Usage:
    export MATHPIX_APP_ID=your_app_id
    export MATHPIX_APP_KEY=your_app_key
    export DATABASE_URL=postgresql://reef:password@localhost:5432/reef
    python mathpix/test_from_db.py
"""

import json
import os
import sys

import asyncpg
import requests

APP_ID = os.environ.get("MATHPIX_APP_ID")
APP_KEY = os.environ.get("MATHPIX_APP_KEY")
DATABASE_URL = os.environ.get("DATABASE_URL")

if not APP_ID or not APP_KEY:
    print("Error: MATHPIX_APP_ID and MATHPIX_APP_KEY must be set")
    sys.exit(1)

if not DATABASE_URL:
    print("Error: DATABASE_URL must be set")
    sys.exit(1)


def reef_strokes_to_mathpix(strokes: list[dict]) -> dict:
    """Convert Reef stroke format to Mathpix strokes format.

    Reef format (per stroke):
        {"points": [{"x": float, "y": float, "t": float, ...}, ...]}

    Mathpix format:
        {"strokes": {"x": [[x1, x2, ...], ...], "y": [[y1, y2, ...], ...]}}
    """
    all_x = []
    all_y = []

    for stroke in strokes:
        points = stroke.get("points", [])
        if not points:
            continue
        all_x.append([p["x"] for p in points])
        all_y.append([p["y"] for p in points])

    return {"strokes": {"x": all_x, "y": all_y}}


def send_to_mathpix(strokes_payload: dict) -> dict:
    """Send strokes to Mathpix and return the response."""
    response = requests.post(
        "https://api.mathpix.com/v3/strokes",
        headers={
            "app_id": APP_ID,
            "app_key": APP_KEY,
            "Content-Type": "application/json",
        },
        json={"strokes": strokes_payload},
    )
    return response.json()


async def main():
    conn = await asyncpg.connect(DATABASE_URL)

    try:
        # Get the most recent session with stroke data
        session = await conn.fetchrow(
            """
            SELECT DISTINCT session_id
            FROM stroke_logs
            WHERE event_type = 'draw'
            ORDER BY session_id DESC
            LIMIT 1
            """
        )

        if not session:
            print("No stroke data found in database")
            return

        session_id = session["session_id"]
        print(f"Using session: {session_id}")
        print()

        # Get clusters with existing transcriptions for this session
        clusters = await conn.fetch(
            """
            SELECT cluster_label, transcription, centroid_y
            FROM clusters
            WHERE session_id = $1
            ORDER BY centroid_y ASC
            """,
            session_id,
        )

        # Get all visible stroke logs for this session (resolve erases)
        all_rows = await conn.fetch(
            """
            SELECT id, strokes, event_type, cluster_labels
            FROM stroke_logs
            WHERE session_id = $1 AND event_type IN ('draw', 'erase')
            ORDER BY received_at
            """,
            session_id,
        )

        # Resolve visible rows (erase resets canvas)
        visible_rows = []
        for row in all_rows:
            if row["event_type"] == "erase":
                visible_rows = [dict(row)]
            else:
                visible_rows.append(dict(row))

        if not visible_rows:
            print("No visible strokes after resolving erases")
            return

        # Group strokes by cluster label
        cluster_strokes: dict[int, list[dict]] = {}
        for row in visible_rows:
            strokes_data = row["strokes"]
            if isinstance(strokes_data, str):
                strokes_data = json.loads(strokes_data)

            labels_data = row["cluster_labels"]
            if isinstance(labels_data, str):
                labels_data = json.loads(labels_data)

            if not labels_data:
                continue

            for i, stroke in enumerate(strokes_data):
                if i < len(labels_data):
                    label = labels_data[i]
                    cluster_strokes.setdefault(label, []).append(stroke)

        if not cluster_strokes:
            # Fall back: send all strokes as one batch
            print("No cluster labels found, sending all strokes as one batch")
            all_strokes = []
            for row in visible_rows:
                strokes_data = row["strokes"]
                if isinstance(strokes_data, str):
                    strokes_data = json.loads(strokes_data)
                all_strokes.extend(strokes_data)

            mathpix_payload = reef_strokes_to_mathpix(all_strokes)
            print(f"Sending {len(all_strokes)} strokes to Mathpix...")
            result = send_to_mathpix(mathpix_payload)
            print(f"Mathpix result: {json.dumps(result, indent=2)}")
            return

        # Send each cluster separately and compare with existing transcription
        gemini_map = {c["cluster_label"]: c["transcription"] for c in clusters}

        # Sort by cluster label (reading order already established by centroid_y)
        for label in sorted(cluster_strokes.keys()):
            strokes = cluster_strokes[label]
            mathpix_payload = reef_strokes_to_mathpix(strokes)
            stroke_count = len(strokes)
            point_count = sum(len(s.get("points", [])) for s in strokes)

            print(f"--- Cluster {label} ({stroke_count} strokes, {point_count} points) ---")

            gemini_text = gemini_map.get(label, "(no transcription)")
            print(f"  Gemini:  {gemini_text}")

            result = send_to_mathpix(mathpix_payload)
            mathpix_text = result.get("latex_styled") or result.get("text", "(empty)")
            confidence = result.get("confidence", "N/A")
            is_hw = result.get("is_handwritten", "N/A")

            print(f"  Mathpix: {mathpix_text}")
            print(f"  Confidence: {confidence}, Handwritten: {is_hw}")
            print()

    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio
    asyncio.run(main())
