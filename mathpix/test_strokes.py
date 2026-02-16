"""
Test the Mathpix /v3/strokes endpoint with a hardcoded sample payload.

Usage:
    export MATHPIX_APP_ID=your_app_id
    export MATHPIX_APP_KEY=your_app_key
    python mathpix/test_strokes.py
"""

import json
import os
import sys

import requests

APP_ID = os.environ.get("MATHPIX_APP_ID")
APP_KEY = os.environ.get("MATHPIX_APP_KEY")

if not APP_ID or not APP_KEY:
    print("Error: MATHPIX_APP_ID and MATHPIX_APP_KEY must be set")
    sys.exit(1)

# Sample strokes representing "3x²" — three strokes with (x, y) coordinates
# Stroke 1: the digit "3"
# Stroke 2: the letter "x"
# Stroke 3: the superscript "2"
payload = {
    "strokes": {
        "strokes": {
            "x": [
                # Stroke 1: "3"
                [50, 80, 90, 80, 50, 60, 90, 80, 50],
                # Stroke 2: "x" (two crossing lines)
                [120, 160, 140, 120, 160],
                # Stroke 3: "2" (superscript)
                [170, 190, 195, 175, 170, 195],
            ],
            "y": [
                # Stroke 1: "3"
                [20, 20, 40, 60, 60, 80, 80, 100, 100],
                # Stroke 2: "x"
                [40, 100, 70, 100, 40],
                # Stroke 3: "2" (superscript, higher up)
                [10, 10, 25, 25, 40, 40],
            ],
        }
    }
}

print("Sending to Mathpix /v3/strokes...")
print(f"Payload: {json.dumps(payload, indent=2)}")
print()

response = requests.post(
    "https://api.mathpix.com/v3/strokes",
    headers={
        "app_id": APP_ID,
        "app_key": APP_KEY,
        "Content-Type": "application/json",
    },
    json=payload,
)

print(f"Status: {response.status_code}")
print(f"Response: {json.dumps(response.json(), indent=2)}")
