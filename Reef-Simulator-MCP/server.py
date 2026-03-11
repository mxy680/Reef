"""Reef iOS Simulator REST API.

Wraps xcrun simctl, idb, and xcodebuild into HTTP endpoints
with automatic landscape↔portrait coordinate conversion.

Start: uv run python server.py
Call:  curl http://localhost:9111/<endpoint>
"""

import base64
import json
import re
import subprocess
import tempfile
from pathlib import Path

from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse
import uvicorn

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BUNDLE_ID = "com.studyreef.app"
DEFAULT_UDID = "13F0B842-54EA-46DA-B5D9-2E74C4D8F30C"
LANDSCAPE_WIDTH, LANDSCAPE_HEIGHT = 1210, 834

XCODEPROJ = Path(__file__).parent.parent / "Reef-iOS" / "Reef.xcodeproj"

app = FastAPI(title="Reef Simulator")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(cmd: list[str], *, timeout: int = 300, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=check)


def _landscape_to_portrait(x: float, y: float) -> tuple[float, float]:
    return LANDSCAPE_HEIGHT - y, x


def _booted_udid() -> str:
    result = _run(["xcrun", "simctl", "list", "devices", "-j"])
    devices = json.loads(result.stdout)
    for runtime, device_list in devices.get("devices", {}).items():
        for d in device_list:
            if d.get("state") == "Booted":
                return d["udid"]
    raise RuntimeError("No booted simulator found. Call /boot first.")


def _ok(msg: str) -> JSONResponse:
    return JSONResponse({"ok": True, "message": msg})


def _err(msg: str) -> JSONResponse:
    return JSONResponse({"ok": False, "error": msg}, status_code=400)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@app.get("/simulators")
def list_simulators():
    """List available iPad simulators."""
    result = _run(["xcrun", "simctl", "list", "devices", "-j"])
    devices = json.loads(result.stdout)
    ipads = []
    for runtime, device_list in devices.get("devices", {}).items():
        for d in device_list:
            if "iPad" in d.get("name", ""):
                ipads.append({"name": d["name"], "udid": d["udid"], "state": d.get("state", "Unknown")})
    return ipads


@app.post("/boot")
def boot_simulator(udid: str | None = None):
    """Boot a simulator. Defaults to iPad Pro 11-inch."""
    udid = udid or DEFAULT_UDID
    result = _run(["xcrun", "simctl", "boot", udid], check=False)
    if result.returncode != 0:
        if "current state: Booted" in result.stderr:
            return _ok(f"Simulator {udid} is already booted.")
        return _err(f"Failed to boot: {result.stderr.strip()}")
    _run(["open", "-a", "Simulator"], check=False)
    return _ok(f"Booted simulator {udid}.")


@app.post("/build")
def build_and_install(configuration: str = "Debug"):
    """Build Reef and install it on the booted simulator."""
    udid = _booted_udid()
    build_cmd = [
        "xcodebuild",
        "-project", str(XCODEPROJ),
        "-scheme", "Reef",
        "-configuration", configuration,
        "-sdk", "iphonesimulator",
        "-destination", f"id={udid}",
        "-derivedDataPath", str(XCODEPROJ.parent / "build"),
        "build",
    ]
    result = _run(build_cmd, timeout=600, check=False)
    if result.returncode != 0:
        tail = "\n".join(result.stderr.strip().splitlines()[-40:])
        return _err(f"Build failed:\n{tail}")

    build_dir = XCODEPROJ.parent / "build" / "Build" / "Products" / f"{configuration}-iphonesimulator"
    app_bundles = list(build_dir.glob("*.app"))
    if not app_bundles:
        return _err(f"Build succeeded but no .app found in {build_dir}")

    install_result = _run(["xcrun", "simctl", "install", udid, str(app_bundles[0])], check=False)
    if install_result.returncode != 0:
        return _err(f"Install failed: {install_result.stderr.strip()}")

    return _ok(f"Built and installed {app_bundles[0].name} on {udid}.")


@app.post("/launch")
def launch_app():
    """Launch Reef on the booted simulator."""
    udid = _booted_udid()
    result = _run(["xcrun", "simctl", "launch", udid, BUNDLE_ID], check=False)
    if result.returncode != 0:
        return _err(f"Launch failed: {result.stderr.strip()}")
    return _ok(f"Launched {BUNDLE_ID}.")


@app.post("/terminate")
def terminate_app():
    """Terminate Reef on the booted simulator."""
    udid = _booted_udid()
    result = _run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    if result.returncode != 0:
        return _err(f"Terminate failed: {result.stderr.strip()}")
    return _ok(f"Terminated {BUNDLE_ID}.")


@app.get("/screenshot")
def screenshot():
    """Capture screen, rotate for landscape, return base64 PNG."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        tmp_path = f.name

    _run(["xcrun", "simctl", "io", "booted", "screenshot", tmp_path])
    _run(["sips", "-r", "270", tmp_path], check=False)

    data = Path(tmp_path).read_bytes()
    Path(tmp_path).unlink(missing_ok=True)

    return {"image_base64": base64.b64encode(data).decode(), "format": "png"}


@app.get("/screenshot.png")
def screenshot_raw():
    """Capture screen, rotate for landscape, return raw PNG (for viewing in browser)."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        tmp_path = f.name

    _run(["xcrun", "simctl", "io", "booted", "screenshot", tmp_path])
    _run(["sips", "-r", "270", tmp_path], check=False)

    data = Path(tmp_path).read_bytes()
    Path(tmp_path).unlink(missing_ok=True)

    from fastapi.responses import Response
    return Response(content=data, media_type="image/png")


@app.post("/tap")
def tap(x: float, y: float):
    """Tap at landscape coordinates (auto-converts for simulator)."""
    px, py = _landscape_to_portrait(x, y)
    _run(["xcrun", "simctl", "io", "booted", "tap", str(px), str(py)])
    return _ok(f"Tapped landscape ({x}, {y}) → portrait ({px}, {py}).")


@app.post("/tap_element")
def tap_element(label: str):
    """Find element by accessibility label substring and tap its center."""
    elements = _get_ui_elements()
    label_lower = label.lower()
    matches = [e for e in elements if label_lower in e["label"].lower()]

    if not matches:
        return _err(f"No element found matching '{label}'.")

    target = matches[0]
    warning = ""
    if len(matches) > 1:
        labels = [m["label"] for m in matches]
        warning = f" ({len(matches)} matches: {labels}, tapped first)"

    cx, cy = target["center"]
    px, py = _landscape_to_portrait(cx, cy)
    _run(["xcrun", "simctl", "io", "booted", "tap", str(px), str(py)])
    return _ok(f"Tapped '{target['label']}' at landscape ({cx}, {cy}).{warning}")


@app.get("/ui")
def describe_ui(role: str | None = None):
    """Return accessibility tree as JSON. Optionally filter by role."""
    elements = _get_ui_elements(role_filter=role)
    return elements


@app.post("/type")
def type_text(text: str):
    """Type text into focused text field."""
    _run(["xcrun", "simctl", "io", "booted", "type", text])
    return _ok(f"Typed: {text}")


@app.post("/swipe")
def swipe(start_x: float, start_y: float, end_x: float, end_y: float):
    """Swipe in landscape coordinates (auto-converts for simulator)."""
    sx, sy = _landscape_to_portrait(start_x, start_y)
    ex, ey = _landscape_to_portrait(end_x, end_y)
    _run(["xcrun", "simctl", "io", "booted", "swipe", str(sx), str(sy), str(ex), str(ey)])
    return _ok(f"Swiped landscape ({start_x},{start_y})→({end_x},{end_y}).")


# ---------------------------------------------------------------------------
# UI element parsing
# ---------------------------------------------------------------------------

def _get_ui_elements(role_filter: str | None = None) -> list[dict]:
    udid = _booted_udid()
    result = _run(["idb", "ui", "describe-all", "--udid", udid], check=False)
    if result.returncode != 0:
        result = _run(["xcrun", "simctl", "ui", udid, "describe-all"], check=False)
        if result.returncode != 0:
            return []

    elements = _parse_accessibility_output(result.stdout)

    if role_filter:
        role_lower = role_filter.lower()
        elements = [e for e in elements if e["role"].lower() == role_lower]

    elements.sort(key=lambda e: (e["center"][1], e["center"][0]))
    return elements


def _parse_accessibility_output(raw: str) -> list[dict]:
    elements = []

    try:
        data = json.loads(raw)
        if isinstance(data, list):
            for item in data:
                elem = _extract_element_from_dict(item)
                if elem:
                    elements.append(elem)
            return elements
    except (json.JSONDecodeError, TypeError):
        pass

    current: dict = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            if current:
                elem = _extract_element_from_dict(current)
                if elem:
                    elements.append(elem)
                current = {}
            continue
        if ":" in line:
            key, _, value = line.partition(":")
            current[key.strip()] = value.strip()

    if current:
        elem = _extract_element_from_dict(current)
        if elem:
            elements.append(elem)

    return elements


def _extract_element_from_dict(d: dict) -> dict | None:
    label = d.get("AXLabel") or d.get("label") or d.get("title") or ""
    role = d.get("AXRole") or d.get("role") or d.get("type") or ""

    if not label:
        return None

    frame_raw = d.get("AXFrame") or d.get("frame") or ""
    frame = _parse_frame(frame_raw) if isinstance(frame_raw, str) else frame_raw

    if not frame or (frame.get("w", 0) == 0 and frame.get("h", 0) == 0):
        if isinstance(frame_raw, dict):
            frame = frame_raw
        else:
            return None

    w = frame.get("w", frame.get("width", 0))
    h = frame.get("h", frame.get("height", 0))
    if w == 0 and h == 0:
        return None

    x = frame.get("x", 0)
    y = frame.get("y", 0)

    portrait_cx = x + w / 2
    portrait_cy = y + h / 2
    landscape_cx = portrait_cy
    landscape_cy = LANDSCAPE_HEIGHT - portrait_cx

    return {
        "label": label,
        "role": role,
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "center": [round(landscape_cx, 1), round(landscape_cy, 1)],
    }


def _parse_frame(frame_str: str) -> dict | None:
    if not frame_str:
        return None
    nums = re.findall(r"[-\d.]+", frame_str)
    if len(nums) >= 4:
        return {"x": float(nums[0]), "y": float(nums[1]), "w": float(nums[2]), "h": float(nums[3])}
    return None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=9111)
