#!/usr/bin/env python3
"""Interactive tutor simulation script for the Reef tutoring system.

Lets a user (or automated script) interact with the tutor evaluation pipeline
by providing LaTeX input step-by-step.

Usage:
    python scripts/simulate_tutor.py --topic "derivatives"
    python scripts/simulate_tutor.py --scenario scenarios/derivative_basic.json
    python scripts/simulate_tutor.py --scenario scenarios/derivative_basic.json --auto
    python scripts/simulate_tutor.py --topic "derivatives" --server https://api.studyreef.com --token <jwt>

Requires env vars from ~/.config/reef/server.env (auto-loaded).
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any

import httpx

# Ensure Reef-Server root is on sys.path for latex2strokes import
_here = os.path.dirname(os.path.abspath(__file__))
_server_root = os.path.dirname(_here)
if _server_root not in sys.path:
    sys.path.insert(0, _server_root)

# ---------------------------------------------------------------------------
# Load env from shared config
# ---------------------------------------------------------------------------

ENV_FILE = Path.home() / ".config" / "reef" / "server.env"


def _load_env() -> None:
    if ENV_FILE.exists():
        for line in ENV_FILE.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, val = line.partition("=")
                os.environ.setdefault(key.strip(), val.strip())


_load_env()

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")

if not SUPABASE_URL or not SERVICE_KEY:
    print("ERROR: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in ~/.config/reef/server.env")
    sys.exit(1)

_SB_HEADERS = {
    "apikey": SERVICE_KEY,
    "Authorization": f"Bearer {SERVICE_KEY}",
    "Content-Type": "application/json",
}

# ---------------------------------------------------------------------------
# Supabase REST helpers (sync)
# ---------------------------------------------------------------------------


def _sb_get(table: str, params: dict[str, str]) -> list[dict]:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    resp = httpx.get(url, params=params, headers=_SB_HEADERS, timeout=10)
    resp.raise_for_status()
    return resp.json()


def _sb_post(table: str, body: dict, prefer: str = "return=minimal") -> httpx.Response:
    headers = {**_SB_HEADERS, "Prefer": prefer}
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    resp = httpx.post(url, json=body, headers=headers, timeout=10)
    return resp


def _sb_delete(table: str, params: dict[str, str]) -> None:
    url = f"{SUPABASE_URL}/rest/v1/{table}"
    headers = {**_SB_HEADERS, "Prefer": "return=minimal"}
    httpx.delete(url, params=params, headers=headers, timeout=10)


def upsert_student_work(doc_id: str, question_label: str, user_id: str, latex: str) -> None:
    """Upsert latex to student_work table."""
    body = {
        "document_id": doc_id,
        "question_label": question_label,
        "user_id": user_id,
        "latex_raw": latex,
        "latex_display": latex,
    }
    headers = {**_SB_HEADERS, "Prefer": "resolution=merge-duplicates,return=minimal"}
    url = f"{SUPABASE_URL}/rest/v1/student_work"
    resp = httpx.post(url, json=body, headers=headers, timeout=10)
    if resp.status_code not in (200, 201):
        print(f"  [warn] upsert_student_work failed: {resp.status_code} {resp.text[:200]}")


def insert_document(doc_id: str, user_id: str) -> None:
    """Insert a row into the documents table."""
    body = {
        "id": doc_id,
        "user_id": user_id,
        "filename": f"sim-{doc_id[:8]}.pdf",
        "status": "completed",
        "page_count": 1,
        "problem_count": 1,
    }
    resp = _sb_post("documents", body)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"insert_document failed: {resp.status_code} {resp.text[:300]}")


def insert_answer_key(
    doc_id: str,
    question_number: int,
    answer_text_json: str,
    question_json: dict,
) -> None:
    """Insert answer key row."""
    body = {
        "document_id": doc_id,
        "question_number": question_number,
        "answer_text": answer_text_json,
        "question_json": question_json,
        "model": "simulate_tutor",
        "input_tokens": 0,
        "output_tokens": 0,
    }
    resp = _sb_post("answer_keys", body)
    if resp.status_code not in (200, 201):
        raise RuntimeError(f"insert_answer_key failed: {resp.status_code} {resp.text[:300]}")


def delete_document(doc_id: str) -> None:
    """Delete document row — cascades to answer_keys etc. if FK + cascade set up."""
    _sb_delete("documents", {"id": f"eq.{doc_id}"})


def delete_table_rows(table: str, doc_id: str) -> None:
    """Delete all rows in table where document_id = doc_id."""
    _sb_delete(table, {"document_id": f"eq.{doc_id}"})


def fetch_chat_history(doc_id: str, question_label: str, user_id: str) -> list[dict]:
    """Fetch last 15 chat messages from DB, oldest first."""
    rows = _sb_get(
        "chat_history",
        {
            "user_id": f"eq.{user_id}",
            "document_id": f"eq.{doc_id}",
            "question_label": f"eq.{question_label}",
            "select": "role,text,created_at",
            "order": "created_at.desc",
            "limit": "15",
        },
    )
    rows.reverse()
    return rows


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------


def sign_in(email: str, password: str) -> tuple[str, str]:
    """Sign in via Supabase password flow. Returns (access_token, user_id)."""
    resp = httpx.post(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        json={"email": email, "password": password},
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
        timeout=15,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"Sign-in failed: {resp.status_code} {resp.text[:200]}")
    data = resp.json()
    return data["access_token"], data["user"]["id"]


def get_dev_user_token_and_id(server: str) -> tuple[str, str]:
    """For local dev, get a test JWT (or create/sign in test account) and real user_id."""
    email = "sim-tutor@studyreef.com"
    password = "sim-tutor-dev-2024"

    # Try sign in
    try:
        return sign_in(email, password)
    except RuntimeError:
        pass

    # Create via admin API
    create_resp = httpx.post(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        json={"email": email, "password": password, "email_confirm": True},
        headers={**_SB_HEADERS},
        timeout=15,
    )
    if create_resp.status_code not in (200, 201, 422):
        print(f"  [warn] Could not create test user ({create_resp.status_code}). Using fallback.")
        return "dev", "dev-user"

    try:
        return sign_in(email, password)
    except RuntimeError:
        return "dev", "dev-user"


# ---------------------------------------------------------------------------
# Server API calls
# ---------------------------------------------------------------------------


def call_demo_document(server: str, token: str, topic: str) -> dict:
    """POST /ai/demo-document to generate a problem. Returns full response dict."""
    resp = httpx.post(
        f"{server}/ai/demo-document",
        json={"topic": topic, "student_type": "college"},
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        timeout=60,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"demo-document failed: {resp.status_code} {resp.text[:300]}")
    return resp.json()


def call_tutor_evaluate(
    server: str,
    token: str,
    doc_id: str,
    question_number: int,
    part_label: str | None,
    step_index: int,
) -> dict:
    """POST /ai/tutor-evaluate. Returns response dict."""
    body: dict[str, Any] = {
        "document_id": doc_id,
        "question_number": question_number,
        "step_index": step_index,
        "student_latex": "",
    }
    if part_label is not None:
        body["part_label"] = part_label

    resp = httpx.post(
        f"{server}/ai/tutor-evaluate",
        json=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        timeout=45,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"tutor-evaluate failed: {resp.status_code} {resp.text[:300]}")
    return resp.json()


def call_tutor_chat(
    server: str,
    token: str,
    doc_id: str,
    question_number: int,
    part_label: str | None,
    step_index: int,
    message: str,
) -> dict:
    """POST /ai/tutor-chat."""
    body: dict[str, Any] = {
        "document_id": doc_id,
        "question_number": question_number,
        "step_index": step_index,
        "user_message": message,
    }
    if part_label is not None:
        body["part_label"] = part_label

    resp = httpx.post(
        f"{server}/ai/tutor-chat",
        json=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        timeout=45,
    )
    if resp.status_code != 200:
        raise RuntimeError(f"tutor-chat failed: {resp.status_code} {resp.text[:300]}")
    return resp.json()


# ---------------------------------------------------------------------------
# Output rendering
# ---------------------------------------------------------------------------

BOX_WIDTH = 60


def _pad(text: str, width: int) -> str:
    """Pad text to fill a box row (truncates if too long)."""
    if len(text) > width:
        text = text[: width - 3] + "..."
    return text.ljust(width)


def print_eval_result(
    response: dict,
    step_index: int,
    total_steps: int,
    accumulated_latex: str,
    verbose: bool = False,
    steps_list: list[dict] | None = None,
) -> None:
    status = response.get("status", "unknown")
    progress = response.get("progress", 0.0)
    steps_completed = response.get("steps_completed", 1)
    mistake = response.get("mistake_explanation") or ""
    mistake_speech = response.get("mistake_speech") or ""

    progress_pct = int(progress * 100)
    inner_w = BOX_WIDTH - 2

    header = _pad(f" Step {step_index + 1}/{total_steps}  Status: {status}  Progress: {progress_pct}%", inner_w)

    top = "\u2554" + "\u2550" * inner_w + "\u2557"
    mid = "\u2560" + "\u2550" * inner_w + "\u2563"
    bot = "\u255a" + "\u2550" * inner_w + "\u255d"
    row = "\u2551"

    print(top)
    print(f"{row} {header} {row}")
    print(mid)

    if status == "mistake" and mistake:
        # Print full mistake_explanation without truncation, word-wrapping into box rows
        print(f"{row} {'Mistake explanation:':<{inner_w}} {row}")
        words = mistake.split()
        line = ""
        for word in words:
            if len(line) + len(word) + 1 > inner_w - 2:
                print(f"{row}   {line:<{inner_w - 2}} {row}")
                line = word
            else:
                line = f"{line} {word}".strip()
        if line:
            print(f"{row}   {line:<{inner_w - 2}} {row}")
        if mistake_speech:
            print(f"{row} {'':<{inner_w}} {row}")
            print(f"{row} {'Speech (TTS):':<{inner_w}} {row}")
            words_s = mistake_speech.split()
            line = ""
            for word in words_s:
                if len(line) + len(word) + 1 > inner_w - 2:
                    print(f"{row}   {line:<{inner_w - 2}} {row}")
                    line = word
                else:
                    line = f"{line} {word}".strip()
            if line:
                print(f"{row}   {line:<{inner_w - 2}} {row}")
    elif status == "completed":
        # Show reinforcement from the answer key step if available
        reinforcement = ""
        if steps_list and step_index < len(steps_list):
            reinforcement = steps_list[step_index].get("reinforcement", "")
        if reinforcement:
            print(f"{row} {'Reinforcement:':<{inner_w}} {row}")
            words = reinforcement.split()
            line = ""
            for word in words:
                if len(line) + len(word) + 1 > inner_w - 2:
                    print(f"{row}   {line:<{inner_w - 2}} {row}")
                    line = word
                else:
                    line = f"{line} {word}".strip()
            if line:
                print(f"{row}   {line:<{inner_w - 2}} {row}")
        else:
            print(f"{row} {'Step completed successfully!':<{inner_w}} {row}")
    elif status == "working":
        print(f"{row} {'Still working on this step...':<{inner_w}} {row}")
    elif status == "idle":
        print(f"{row} {'No work detected yet.':<{inner_w}} {row}")

    print(mid)
    print(f"{row} {'Steps completed: ' + str(steps_completed):<{inner_w}} {row}")

    # Show accumulated latex (truncated to one line for readability)
    latex_preview = accumulated_latex.replace("\n", " ").strip()
    label = "Student work: "
    avail = inner_w - len(label)
    latex_display = latex_preview[:avail] if len(latex_preview) > avail else latex_preview
    print(f"{row} {label + latex_display:<{inner_w}} {row}")
    print(bot)

    if verbose and response.get("debug_prompt"):
        print("\n--- DEBUG PROMPT ---")
        print(response["debug_prompt"][:2000])
        print("--- END DEBUG ---\n")


def print_step_prompt(step: dict, step_index: int, total_steps: int, scenario: dict) -> None:
    """Print a header showing the current step's info."""
    desc = step.get("description", "(no description)")
    speech = step.get("tutor_speech", "")
    print(f"\n{'=' * BOX_WIDTH}")
    print(f"  STEP {step_index + 1}/{total_steps}: {desc}")
    if speech:
        print(f"  Tutor: \"{speech}\"")
    print(f"{'=' * BOX_WIDTH}")
    print("  Enter LaTeX (or a /command). Type /help for commands.")
    print()


def print_chat_response(response: dict) -> None:
    reply = response.get("reply", "(no reply)")
    inner_w = BOX_WIDTH - 2
    top = "\u250c" + "\u2500" * inner_w + "\u2510"
    bot = "\u2514" + "\u2500" * inner_w + "\u2518"
    row = "\u2502"

    print(top)
    print(f"{row} {'TUTOR CHAT':<{inner_w}} {row}")
    print(f"{row} {'':<{inner_w}} {row}")

    # Word-wrap reply into lines
    words = reply.split()
    line = ""
    for word in words:
        if len(line) + len(word) + 1 > inner_w - 1:
            print(f"{row} {line:<{inner_w}} {row}")
            line = word
        else:
            line = f"{line} {word}".strip()
    if line:
        print(f"{row} {line:<{inner_w}} {row}")

    print(bot)


def print_history(rows: list[dict]) -> None:
    if not rows:
        print("  (no chat history)")
        return
    print(f"\n  Chat history ({len(rows)} messages):")
    for msg in rows:
        role = msg.get("role", "?")
        text = msg.get("text", "")
        ts = msg.get("created_at", "")[:16]
        print(f"  [{ts}] {role:15s}: {text[:80]}")


# ---------------------------------------------------------------------------
# Scenario helpers
# ---------------------------------------------------------------------------


def load_scenario(path: str) -> dict:
    """Load a scenario JSON file."""
    p = Path(path)
    if not p.exists():
        raise FileNotFoundError(f"Scenario file not found: {path}")
    return json.loads(p.read_text())


def build_answer_key_json(scenario: dict) -> str:
    """Convert scenario dict into a QuestionAnswer JSON string for Supabase."""
    part_label = scenario.get("part_label", "a")
    question_number = scenario.get("question_number", 1)

    steps_raw = scenario.get("steps", [])
    steps = []
    for s in steps_raw:
        steps.append({
            "description": s.get("description", ""),
            "explanation": s.get("explanation", ""),
            "work": s.get("work", ""),
            "reinforcement": s.get("reinforcement", ""),
            "tutor_speech": s.get("tutor_speech", ""),
            "concepts": s.get("concepts", []),
        })

    part_answer = {
        "label": part_label,
        "steps": steps,
        "final_answer": scenario.get("final_answer", ""),
        "parts": [],
    }

    answer_key = {
        "question_number": question_number,
        "steps": [],
        "final_answer": "",
        "parts": [part_answer],
    }

    return json.dumps(answer_key)


def build_question_json(scenario: dict) -> dict:
    """Build question_json from scenario."""
    return {
        "number": scenario.get("question_number", 1),
        "text": scenario.get("question_text", ""),
        "parts": [{"label": scenario.get("part_label", "a"), "text": scenario.get("question_text", "")}],
        "figure_storage_urls": {},
    }


# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------


def cleanup(doc_id: str, no_cleanup: bool = False) -> None:
    if no_cleanup:
        print(f"\n  [--no-cleanup] Skipping cleanup. Document ID: {doc_id}")
        return
    print("\n  Cleaning up...")
    for table in ("student_work", "chat_history", "answer_keys"):
        try:
            delete_table_rows(table, doc_id)
        except Exception as e:
            print(f"  [warn] Failed to delete from {table}: {e}")
    try:
        delete_document(doc_id)
        print(f"  Deleted document {doc_id}")
    except Exception as e:
        print(f"  [warn] Failed to delete document: {e}")


# ---------------------------------------------------------------------------
# Interactive loop
# ---------------------------------------------------------------------------


def handle_command(
    cmd: str,
    server: str,
    token: str,
    doc_id: str,
    question_number: int,
    part_label: str | None,
    question_label: str,
    user_id: str,
    step_index: int,
    total_steps: int,
    steps_list: list[dict],
    accumulated_latex: list[str],
    verbose: bool,
    scenario_steps: list[dict] | None = None,
) -> tuple[int, bool]:
    """Handle a / command. Returns (new_step_index, should_continue).

    Returns (step_index, False) to signal quit.
    """
    parts = cmd.split(maxsplit=1)
    name = parts[0].lower()
    arg = parts[1] if len(parts) > 1 else ""

    if name == "/help":
        print("""
  Commands:
    /correct         — fill in current step's correct answer
    /correct N       — auto-complete N steps
    /chat <message>  — ask the tutor a question
    /history         — show chat history from DB
    /skip            — skip current step without eval
    /quit            — cleanup and exit
    /help            — show this help
""")
        return step_index, True

    if name == "/quit":
        return step_index, False

    if name == "/skip":
        print(f"  Skipping step {step_index + 1}.")
        return step_index + 1, True

    if name == "/history":
        rows = fetch_chat_history(doc_id, question_label, user_id)
        print_history(rows)
        return step_index, True

    if name == "/chat":
        if not arg:
            print("  Usage: /chat <your message>")
            return step_index, True
        print(f"  Sending chat: {arg!r}")
        try:
            response = call_tutor_chat(server, token, doc_id, question_number, part_label, step_index, arg)
            print_chat_response(response)
        except Exception as e:
            print(f"  [error] Chat failed: {e}")
        return step_index, True

    if name == "/correct":
        # Auto-complete N steps or just the current one
        n_str = arg.strip()
        try:
            n_steps = int(n_str) if n_str else 1
        except ValueError:
            print(f"  Usage: /correct [N]")
            return step_index, True

        n_steps = min(n_steps, total_steps - step_index)
        current_si = step_index

        for i in range(n_steps):
            if current_si >= total_steps:
                break
            step = steps_list[current_si] if current_si < len(steps_list) else {}
            correct_work = step.get("work", "")
            accumulated_latex.append(correct_work)
            latex_so_far = "\n".join(accumulated_latex)

            print(f"  Auto-completing step {current_si + 1} with: {correct_work[:60]!r}")
            upsert_student_work(doc_id, question_label, user_id, latex_so_far)

            try:
                response = call_tutor_evaluate(server, token, doc_id, question_number, part_label, current_si)
                print_eval_result(response, current_si, total_steps, latex_so_far, verbose, scenario_steps)
                advance = response.get("steps_completed", 1)
                current_si += advance
            except Exception as e:
                print(f"  [error] Eval failed: {e}")
                current_si += 1

        return current_si, True

    print(f"  Unknown command: {name!r}. Type /help for commands.")
    return step_index, True


# ---------------------------------------------------------------------------
# Stroke pipeline helpers
# ---------------------------------------------------------------------------

def acquire_mathpix_session(server: str, token: str) -> tuple[str, str]:
    """Get a Mathpix strokes session from the server."""
    resp = httpx.post(
        f"{server}/ai/strokes-session",
        headers={"Authorization": f"Bearer {token}"},
        timeout=10,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["app_token"], data["strokes_session_id"]


def latex_to_strokes_and_transcribe(
    latex: str,
    server: str,
    token: str,
    app_token: str,
    session_id: str,
) -> str:
    """Convert LaTeX to strokes via latex2strokes, send to Mathpix, return transcribed LaTeX."""
    from app.services.latex2strokes import latex_to_strokes

    strokes = latex_to_strokes(latex, jitter=False)
    resp = httpx.post(
        f"{server}/ai/transcribe-strokes",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"strokes": strokes, "app_token": app_token, "session_id": session_id},
        timeout=20,
    )
    if resp.status_code != 200:
        return f"[MATHPIX ERROR {resp.status_code}]"
    return resp.json().get("latex", resp.json().get("raw_latex", ""))


def run_interactive_loop(
    server: str,
    token: str,
    doc_id: str,
    question_number: int,
    part_label: str | None,
    user_id: str,
    steps_list: list[dict],
    verbose: bool,
    auto_inputs: list[dict] | None = None,
    no_cleanup: bool = False,
    mathpix_session: tuple[str, str] | None = None,
) -> None:
    """Main simulation loop."""
    total_steps = len(steps_list)
    question_label = f"Q{question_number}{part_label or ''}"
    step_index = 0
    accumulated_latex: list[str] = []
    auto_cursor = 0

    print(f"\n  Document: {doc_id}")
    print(f"  Question: {question_number}  Part: {part_label or '(none)'}  Steps: {total_steps}")
    print(f"  User: {user_id}")

    try:
        while step_index < total_steps:
            step = steps_list[step_index] if step_index < len(steps_list) else {}
            print_step_prompt(step, step_index, total_steps, {})

            # Get input: auto mode or interactive
            if auto_inputs is not None and auto_cursor < len(auto_inputs):
                entry = auto_inputs[auto_cursor]
                auto_cursor += 1
                latex_input = entry.get("latex", "")
                expect_status = entry.get("expect_status", "")
                print(f"  [auto] Input: {latex_input!r}  (expect: {expect_status})")
            elif auto_inputs is not None:
                print("  [auto] No more test inputs. Exiting.")
                break
            else:
                try:
                    latex_input = input("> ").strip()
                except (EOFError, KeyboardInterrupt):
                    print("\n  Interrupted.")
                    break

            if not latex_input:
                continue

            # Handle commands
            if latex_input.startswith("/"):
                step_index, should_continue = handle_command(
                    latex_input,
                    server=server,
                    token=token,
                    doc_id=doc_id,
                    question_number=question_number,
                    part_label=part_label,
                    question_label=question_label,
                    user_id=user_id,
                    step_index=step_index,
                    total_steps=total_steps,
                    steps_list=steps_list,
                    accumulated_latex=accumulated_latex,
                    verbose=verbose,
                    scenario_steps=steps_list,
                )
                if not should_continue:
                    break
                continue

            # Stroke pipeline: convert LaTeX → strokes → Mathpix → use transcribed output
            if mathpix_session:
                print(f"  Converting to strokes...")
                transcribed = latex_to_strokes_and_transcribe(
                    latex_input, server, token, mathpix_session[0], mathpix_session[1]
                )
                match = "✓" if transcribed.strip() and not transcribed.startswith("[MATHPIX") else "✗"
                print(f"  Wrote:   {latex_input}")
                print(f"  Mathpix: {transcribed}  {match}")
                accumulated_latex.append(transcribed)
            else:
                accumulated_latex.append(latex_input)

            latex_so_far = "\n".join(accumulated_latex)
            upsert_student_work(doc_id, question_label, user_id, latex_so_far)

            # Call eval
            print(f"  Evaluating step {step_index + 1}...")
            try:
                response = call_tutor_evaluate(
                    server, token, doc_id, question_number, part_label, step_index
                )
            except Exception as e:
                print(f"  [error] Eval failed: {e}")
                continue

            print_eval_result(response, step_index, total_steps, latex_so_far, verbose, steps_list)

            # Auto-advance on completion
            status = response.get("status", "")
            if status == "completed":
                advance = response.get("steps_completed", 1)
                step_index += advance

            # Auto mode: validate expectation
            if auto_inputs is not None and "expect_status" in (auto_inputs[auto_cursor - 1] if auto_cursor > 0 else {}):
                expected = auto_inputs[auto_cursor - 1].get("expect_status", "")
                actual = response.get("status", "")
                if expected and actual != expected:
                    print(f"  [FAIL] Expected status={expected!r}, got {actual!r}")
                else:
                    print(f"  [PASS] status={actual!r}")

    except KeyboardInterrupt:
        print("\n  Interrupted.")
    finally:
        cleanup(doc_id, no_cleanup)

    if step_index >= total_steps:
        print(f"\n  All {total_steps} steps completed!")
    else:
        print(f"\n  Stopped at step {step_index + 1}/{total_steps}.")


# ---------------------------------------------------------------------------
# Setup: --topic mode
# ---------------------------------------------------------------------------


def setup_topic_mode(
    server: str,
    token: str,
    topic: str,
    user_id: str,
) -> tuple[str, int, str | None, list[dict]]:
    """Call demo-document endpoint, return (doc_id, question_number, part_label, steps_list)."""
    print(f"\n  Generating demo problem: topic='{topic}'...")
    result = call_demo_document(server, token, topic)
    doc_id = result["document_id"]
    print(f"  Created document: {doc_id}")

    # Fetch the answer key from DB to get steps
    rows = _sb_get(
        "answer_keys",
        {
            "document_id": f"eq.{doc_id}",
            "select": "answer_text,question_json",
            "limit": "1",
        },
    )
    if not rows:
        raise RuntimeError("Answer key not found after demo-document call")

    answer_key = json.loads(rows[0]["answer_text"])

    # Demo always wraps in part "a"
    part_label = "a"
    steps_list: list[dict] = []
    for part in answer_key.get("parts", []):
        if part.get("label") == part_label:
            steps_list = part.get("steps", [])
            break

    if not steps_list:
        # Fallback to top-level steps
        steps_list = answer_key.get("steps", [])
        part_label = None

    return doc_id, 1, part_label, steps_list


# ---------------------------------------------------------------------------
# Setup: --scenario mode
# ---------------------------------------------------------------------------


def setup_scenario_mode(
    scenario: dict,
    user_id: str,
) -> tuple[str, int, str | None, list[dict]]:
    """Create document + answer key from scenario, return (doc_id, question_number, part_label, steps_list)."""
    doc_id = str(uuid.uuid4())
    question_number = scenario.get("question_number", 1)
    part_label = scenario.get("part_label") or None

    print(f"\n  Creating document from scenario...")
    insert_document(doc_id, user_id)
    print(f"  Document: {doc_id}")

    answer_text_json = build_answer_key_json(scenario)
    question_json = build_question_json(scenario)
    insert_answer_key(doc_id, question_number, answer_text_json, question_json)
    print(f"  Answer key inserted (Q{question_number} part={part_label})")

    steps_list = scenario.get("steps", [])
    return doc_id, question_number, part_label, steps_list


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def _resolve_token_and_user(args: argparse.Namespace) -> tuple[str, str]:
    """Return (token, user_id) based on CLI args and server URL."""
    is_local = "localhost" in args.server or "127.0.0.1" in args.server

    if args.token:
        # User provided explicit token — need user_id from Supabase
        user_id = "dev-user"
        if not is_local:
            # Try to decode user_id from JWT payload (base64, no verify)
            import base64 as _b64
            try:
                parts = args.token.split(".")
                if len(parts) >= 2:
                    payload_b64 = parts[1] + "=="  # add padding
                    payload = json.loads(_b64.urlsafe_b64decode(payload_b64))
                    user_id = payload.get("sub", "dev-user")
            except Exception:
                pass
        return args.token, user_id

    if is_local:
        # Use dev JWT — server accepts "dev" in development mode
        token, user_id = get_dev_user_token_and_id(args.server)
        return token, user_id

    # Production without token — prompt for credentials
    print("\n  Production server requires authentication.")
    email = input("  Supabase email: ").strip()
    password = input("  Supabase password: ").strip()
    token, user_id = sign_in(email, password)
    print(f"  Signed in as {user_id}")
    return token, user_id


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Reef tutor simulation script",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--server", default="http://localhost:8000", help="API base URL")
    parser.add_argument("--topic", help="Generate a demo problem on this topic")
    parser.add_argument("--scenario", help="Path to scenario JSON file")
    parser.add_argument("--token", help="Supabase JWT token (optional; defaults to dev for localhost)")
    parser.add_argument("--auto", action="store_true", help="Run test_inputs non-interactively")
    parser.add_argument("--no-cleanup", action="store_true", help="Skip cleanup on exit")
    parser.add_argument("--verbose", action="store_true", help="Show full debug prompt from server")
    parser.add_argument("--strokes", action="store_true", help="Convert LaTeX to strokes → Mathpix → tutor (full pipeline)")
    args = parser.parse_args()

    if not args.topic and not args.scenario:
        parser.error("One of --topic or --scenario is required")

    print(f"\n  Reef Tutor Simulator")
    print(f"  Server: {args.server}")

    token, user_id = _resolve_token_and_user(args)

    scenario: dict = {}
    if args.scenario:
        scenario = load_scenario(args.scenario)
        doc_id, question_number, part_label, steps_list = setup_scenario_mode(scenario, user_id)
    else:
        doc_id, question_number, part_label, steps_list = setup_topic_mode(
            args.server, token, args.topic, user_id
        )

    if not steps_list:
        print("  ERROR: No steps found. Cannot simulate.")
        cleanup(doc_id, args.no_cleanup)
        sys.exit(1)

    auto_inputs: list[dict] | None = None
    if args.auto:
        auto_inputs = scenario.get("test_inputs", [])
        if not auto_inputs:
            print("  [warn] --auto specified but scenario has no test_inputs. Running interactively.")
            auto_inputs = None

    # Acquire Mathpix session for --strokes mode
    mathpix_session: tuple[str, str] | None = None
    if args.strokes:
        print("  Acquiring Mathpix session for stroke mode...")
        try:
            mathpix_session = acquire_mathpix_session(args.server, token)
            print(f"  Stroke mode: ON (session {mathpix_session[1][:12]}...)")
        except Exception as e:
            print(f"  [error] Failed to acquire Mathpix session: {e}")
            print("  Falling back to direct LaTeX mode.")

    run_interactive_loop(
        server=args.server,
        token=token,
        doc_id=doc_id,
        question_number=question_number,
        part_label=part_label,
        user_id=user_id,
        steps_list=steps_list,
        verbose=args.verbose,
        auto_inputs=auto_inputs,
        no_cleanup=args.no_cleanup,
        mathpix_session=mathpix_session,
    )


if __name__ == "__main__":
    main()
