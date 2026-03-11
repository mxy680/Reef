"""Reef iOS Simulator MCP Server.

Wraps xcrun simctl, idb, and xcodebuild into clean MCP tools
with automatic landscape↔portrait coordinate conversion.
"""

import json
import re
import subprocess
import tempfile
from pathlib import Path

from fastmcp import FastMCP
from fastmcp.utilities.types import Image

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

BUNDLE_ID = "com.studyreef.app"
DEFAULT_UDID = "13F0B842-54EA-46DA-B5D9-2E74C4D8F30C"
LANDSCAPE_WIDTH, LANDSCAPE_HEIGHT = 1210, 834

XCODEPROJ = Path(__file__).parent.parent / "Reef-iOS" / "Reef.xcodeproj"

mcp = FastMCP("reef-simulator")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(cmd: list[str], *, timeout: int = 300, check: bool = True) -> subprocess.CompletedProcess:
    """Run a subprocess synchronously."""
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=check)


def _landscape_to_portrait(x: float, y: float) -> tuple[float, float]:
    """Convert landscape (x, y) → portrait (x, y) for idb/simctl."""
    return LANDSCAPE_HEIGHT - y, x


def _booted_udid() -> str:
    """Return the UDID of the first booted simulator, or raise."""
    result = _run(["xcrun", "simctl", "list", "devices", "-j"])
    devices = json.loads(result.stdout)
    for runtime, device_list in devices.get("devices", {}).items():
        for d in device_list:
            if d.get("state") == "Booted":
                return d["udid"]
    raise RuntimeError("No booted simulator found. Call boot_simulator first.")


# ---------------------------------------------------------------------------
# Tools
# ---------------------------------------------------------------------------


@mcp.tool()
def list_simulators() -> str:
    """List available iPad simulators (name, UDID, state)."""
    result = _run(["xcrun", "simctl", "list", "devices", "-j"])
    devices = json.loads(result.stdout)
    lines = []
    for runtime, device_list in devices.get("devices", {}).items():
        for d in device_list:
            if "iPad" in d.get("name", ""):
                state = d.get("state", "Unknown")
                lines.append(f"{d['name']}  {d['udid']}  ({state})")
    return "\n".join(lines) if lines else "No iPad simulators found."


@mcp.tool()
def boot_simulator(udid: str | None = None) -> str:
    """Boot a simulator. Defaults to iPad Pro 11-inch if no UDID given."""
    udid = udid or DEFAULT_UDID
    result = _run(["xcrun", "simctl", "boot", udid], check=False)
    if result.returncode != 0:
        if "current state: Booted" in result.stderr:
            return f"Simulator {udid} is already booted."
        return f"Failed to boot: {result.stderr.strip()}"
    # Open Simulator.app so the window appears
    _run(["open", "-a", "Simulator"], check=False)
    return f"Booted simulator {udid}."


@mcp.tool()
def build_and_install(configuration: str = "Debug") -> str:
    """Build Reef and install it on the booted simulator."""
    udid = _booted_udid()

    # Build
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
        # Return last 40 lines of stderr for diagnostics
        tail = "\n".join(result.stderr.strip().splitlines()[-40:])
        return f"Build failed:\n{tail}"

    # Find the .app bundle
    build_dir = XCODEPROJ.parent / "build" / "Build" / "Products" / f"{configuration}-iphonesimulator"
    app_bundles = list(build_dir.glob("*.app"))
    if not app_bundles:
        return f"Build succeeded but no .app found in {build_dir}"

    # Install
    install_result = _run(["xcrun", "simctl", "install", udid, str(app_bundles[0])], check=False)
    if install_result.returncode != 0:
        return f"Install failed: {install_result.stderr.strip()}"

    return f"Built and installed {app_bundles[0].name} on {udid}."


@mcp.tool()
def launch_app() -> str:
    """Launch Reef on the booted simulator."""
    udid = _booted_udid()
    result = _run(["xcrun", "simctl", "launch", udid, BUNDLE_ID], check=False)
    if result.returncode != 0:
        return f"Launch failed: {result.stderr.strip()}"
    return f"Launched {BUNDLE_ID}."


@mcp.tool()
def terminate_app() -> str:
    """Terminate Reef on the booted simulator."""
    udid = _booted_udid()
    result = _run(["xcrun", "simctl", "terminate", udid, BUNDLE_ID], check=False)
    if result.returncode != 0:
        return f"Terminate failed: {result.stderr.strip()}"
    return f"Terminated {BUNDLE_ID}."


@mcp.tool()
def screenshot() -> Image:
    """Capture the simulator screen, rotate for landscape, return as inline PNG."""
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        tmp_path = f.name

    _run(["xcrun", "simctl", "io", "booted", "screenshot", tmp_path])
    _run(["sips", "-r", "270", tmp_path], check=False)

    data = Path(tmp_path).read_bytes()
    Path(tmp_path).unlink(missing_ok=True)
    return Image(data=data, format="png")


@mcp.tool()
def tap(x: float, y: float) -> str:
    """Tap at landscape coordinates (auto-converts for simulator)."""
    px, py = _landscape_to_portrait(x, y)
    _run(["xcrun", "simctl", "io", "booted", "tap", str(px), str(py)])
    return f"Tapped landscape ({x}, {y}) → portrait ({px}, {py})."


@mcp.tool()
def tap_element(label: str) -> str:
    """Find a UI element by accessibility label substring and tap its center."""
    elements = _get_ui_elements()
    label_lower = label.lower()
    matches = [e for e in elements if label_lower in e["label"].lower()]

    if not matches:
        return f"No element found matching '{label}'."

    target = matches[0]
    warning = ""
    if len(matches) > 1:
        labels = [m["label"] for m in matches]
        warning = f" (Warning: {len(matches)} matches found: {labels}. Tapping first.)"

    cx, cy = target["center"]
    px, py = _landscape_to_portrait(cx, cy)
    _run(["xcrun", "simctl", "io", "booted", "tap", str(px), str(py)])
    return f"Tapped '{target['label']}' at landscape ({cx}, {cy}).{warning}"


@mcp.tool()
def describe_ui(role_filter: str | None = None) -> str:
    """Return the accessibility tree as structured JSON.

    Elements include label, role, frame, and center point (in landscape coords).
    Optionally filter by role (e.g. 'Button', 'StaticText').
    """
    elements = _get_ui_elements(role_filter=role_filter)
    if not elements:
        return "No accessible elements found."
    return json.dumps(elements, indent=2)


@mcp.tool()
def type_text(text: str) -> str:
    """Type text into the currently focused text field."""
    _run(["xcrun", "simctl", "io", "booted", "type", text])
    return f"Typed: {text}"


@mcp.tool()
def swipe(start_x: float, start_y: float, end_x: float, end_y: float) -> str:
    """Swipe gesture in landscape coordinates (auto-converts for simulator)."""
    sx, sy = _landscape_to_portrait(start_x, start_y)
    ex, ey = _landscape_to_portrait(end_x, end_y)
    _run(["xcrun", "simctl", "io", "booted", "swipe", str(sx), str(sy), str(ex), str(ey)])
    return (
        f"Swiped landscape ({start_x},{start_y})→({end_x},{end_y}) "
        f"= portrait ({sx},{sy})→({ex},{ey})."
    )


# ---------------------------------------------------------------------------
# UI element parsing
# ---------------------------------------------------------------------------

def _get_ui_elements(role_filter: str | None = None) -> list[dict]:
    """Get accessible UI elements from the booted simulator via idb."""
    udid = _booted_udid()
    result = _run(["idb", "ui", "describe-all", "--udid", udid], check=False)
    if result.returncode != 0:
        # Fallback: try xcrun simctl
        result = _run(
            ["xcrun", "simctl", "ui", udid, "describe-all"],
            check=False,
        )
        if result.returncode != 0:
            return []

    elements = _parse_accessibility_output(result.stdout)

    if role_filter:
        role_lower = role_filter.lower()
        elements = [e for e in elements if e["role"].lower() == role_lower]

    # Sort top-to-bottom, left-to-right (by center y then x)
    elements.sort(key=lambda e: (e["center"][1], e["center"][0]))
    return elements


def _parse_accessibility_output(raw: str) -> list[dict]:
    """Parse idb/simctl accessibility output into structured elements.

    Handles the common idb output format with AXLabel, AXFrame, etc.
    """
    elements = []

    # Try JSON first
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

    # Parse line-based format from idb
    # Pattern: lines with key-value pairs describing each element
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

        # Key: Value parsing
        if ":" in line:
            key, _, value = line.partition(":")
            current[key.strip()] = value.strip()

    # Don't forget last element
    if current:
        elem = _extract_element_from_dict(current)
        if elem:
            elements.append(elem)

    return elements


def _extract_element_from_dict(d: dict) -> dict | None:
    """Extract a normalized element dict from raw parsed data."""
    label = d.get("AXLabel") or d.get("label") or d.get("title") or ""
    role = d.get("AXRole") or d.get("role") or d.get("type") or ""

    # Skip elements with no label
    if not label:
        return None

    # Parse frame - try multiple formats
    frame_raw = d.get("AXFrame") or d.get("frame") or ""
    frame = _parse_frame(frame_raw) if isinstance(frame_raw, str) else frame_raw

    if not frame or (frame.get("w", 0) == 0 and frame.get("h", 0) == 0):
        # Try to get frame from nested structure
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

    # Center point in portrait coords from simctl, convert to landscape
    portrait_cx = x + w / 2
    portrait_cy = y + h / 2
    # Portrait→landscape: inverse of landscape→portrait
    # portrait_x = 834 - landscape_y  =>  landscape_y = 834 - portrait_x
    # portrait_y = landscape_x        =>  landscape_x = portrait_y
    landscape_cx = portrait_cy
    landscape_cy = LANDSCAPE_HEIGHT - portrait_cx

    return {
        "label": label,
        "role": role,
        "frame": {"x": x, "y": y, "w": w, "h": h},
        "center": [round(landscape_cx, 1), round(landscape_cy, 1)],
    }


def _parse_frame(frame_str: str) -> dict | None:
    """Parse frame string like '{{x, y}, {w, h}}' or 'x,y,w,h'."""
    if not frame_str:
        return None

    # Format: {{100, 200}, {300, 400}}
    nums = re.findall(r"[-\d.]+", frame_str)
    if len(nums) >= 4:
        return {
            "x": float(nums[0]),
            "y": float(nums[1]),
            "w": float(nums[2]),
            "h": float(nums[3]),
        }
    return None


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    mcp.run()
