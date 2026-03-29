#!/usr/bin/env python3
"""Inject LaTeX as handwriting strokes onto a connected iPad canvas.

Writes stroke data directly to Supabase `simulation_strokes` table.
The iPad subscribes to realtime changes and renders strokes automatically.

Usage:
    python scripts/inject_strokes.py "3x + 5"
    python scripts/inject_strokes.py "f'(x) = 6x + 5" --y 200
    python scripts/inject_strokes.py --doc-id <id>   # interactive mode with question context
"""

import argparse
import json
import os
import sys

import httpx

_here = os.path.dirname(os.path.abspath(__file__))
_server_root = os.path.dirname(_here)
if _server_root not in sys.path:
    sys.path.insert(0, _server_root)

from app.services.latex2strokes import latex_to_strokes


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
DEFAULT_USER_ID = "a24e261a-313b-450a-88c5-7653e2ece357"


def supabase_headers() -> dict[str, str]:
    key = ENV.get("SUPABASE_SERVICE_ROLE_KEY", "")
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json",
    }


SERVER_URL = "https://api.studyreef.com"


def send_chat(message: str, doc_id: str, question_label: str, step_index: int) -> str | None:
    """Send a chat message to the tutor and return the reply."""
    # Parse question_label like "Q1a" into question_number=1, part_label="a"
    label = question_label
    if label.startswith("Q"):
        label = label[1:]
    num_str = ""
    for ch in label:
        if ch.isdigit():
            num_str += ch
        else:
            break
    question_number = int(num_str) if num_str else 1
    part_label = label[len(num_str):] or None

    resp = httpx.post(
        f"{SERVER_URL}/ai/tutor-chat",
        headers={"Authorization": "Bearer dev", "Content-Type": "application/json"},
        json={
            "document_id": doc_id,
            "question_number": question_number,
            "part_label": part_label,
            "step_index": step_index,
            "student_latex": "",
            "user_message": message,
            "history": [],
        },
        timeout=30,
    )

    if resp.status_code == 200:
        data = resp.json()
        return data.get("reply", "(no reply)")
    else:
        print(f"  ✗ Chat error {resp.status_code}: {resp.text[:200]}")
        return None


def get_page_for_question(doc_id: str, question_label: str) -> int:
    """Return the 0-based page index where a question's answer space lives."""
    url = ENV.get("SUPABASE_URL", "")
    resp = httpx.get(
        f"{url}/rest/v1/documents?id=eq.{doc_id}&select=question_pages,question_regions",
        headers=supabase_headers(), timeout=5,
    )
    if resp.status_code != 200 or not resp.json():
        return 0
    doc = resp.json()[0]
    pages = doc.get("question_pages", [])
    regions = doc.get("question_regions", [])

    # Parse label like "Q1b" → q_num=1, part="b"
    rest = question_label.lstrip("Q")
    num_str = ""
    for ch in rest:
        if ch.isdigit():
            num_str += ch
        else:
            break
    q_num = int(num_str) if num_str else 1
    part_label = rest[len(num_str):] or None

    qi = q_num - 1
    if qi >= len(pages) or qi >= len(regions):
        return 0

    page_range = pages[qi]  # e.g. [0, 1]
    q_regions = regions[qi].get("regions", []) if regions[qi] else []

    # Find the region matching the part label — its "page" field is relative to question pages
    for r in q_regions:
        if r.get("label") == part_label:
            rel_page = r.get("page", 0)
            if rel_page < len(page_range):
                return page_range[rel_page]
            return page_range[0]

    return page_range[0]


def send_strokes(latex: str, user_id: str, doc_id: str, question_label: str,
                  origin_x: float, origin_y: float, font_size: float = 14.0,
                  page_index: int = 0) -> bool:
    """Convert LaTeX to strokes and insert into simulation_strokes table."""
    strokes = latex_to_strokes(latex, origin_x=origin_x, origin_y=origin_y, font_size=font_size, jitter=False)
    url = ENV.get("SUPABASE_URL", "")

    resp = httpx.post(
        f"{url}/rest/v1/simulation_strokes",
        headers=supabase_headers(),
        json={
            "user_id": user_id,
            "document_id": doc_id,
            "question_label": question_label,
            "strokes": strokes,
            "latex": latex,
            "origin_x": origin_x,
            "origin_y": origin_y,
            "page_index": page_index,
        },
        timeout=5,
    )

    if resp.status_code in (200, 201):
        print(f"  ✓ Sent {len(strokes)} strokes (page {page_index}): {latex[:50]}")
        return True
    else:
        print(f"  ✗ Supabase error {resp.status_code}: {resp.text[:200]}")
        return False


def get_simulation_state(user_id: str) -> dict | None:
    """Read the simulation_state row to know what the user is viewing."""
    url = ENV.get("SUPABASE_URL", "")
    resp = httpx.get(
        f"{url}/rest/v1/simulation_state?user_id=eq.{user_id}&select=*",
        headers=supabase_headers(), timeout=5,
    )
    if resp.status_code == 200 and resp.json():
        return resp.json()[0]
    return None


def get_question_region(doc_id: str, question_number: int, part_label: str | None) -> tuple[float, float]:
    """Get the y_start and y_end for a specific subquestion's ANSWER SPACE.

    The answer space starts after the question text (stem). If the part region
    covers the whole page, we look for the stem's y_end to find where the
    question text ends and the answer space begins.
    """
    url = ENV.get("SUPABASE_URL", "")
    resp = httpx.get(
        f"{url}/rest/v1/documents?id=eq.{doc_id}&select=question_regions",
        headers=supabase_headers(), timeout=5,
    )
    if resp.status_code != 200 or not resp.json():
        return 60.0, 400.0

    doc = resp.json()[0]
    regions = doc.get("question_regions", [])
    if not regions or question_number - 1 >= len(regions):
        return 60.0, 400.0

    q_regions = regions[question_number - 1]
    if not q_regions:
        return 60.0, 400.0

    all_r = q_regions.get("regions", [])

    # Find the stem (label=null) — this is the question text area
    stem_y_end = 0.0
    for r in all_r:
        if r.get("label") is None:
            stem_y_end = r.get("y_end", 0.0)
            break

    # Find the target part
    for r in all_r:
        if r.get("label") == part_label:
            y_start = r.get("y_start", 0.0)
            y_end = r.get("y_end", 792.0)

            # If the part covers the whole page (no dedicated region),
            # use stem end as the answer start
            if y_start < 10 and y_end > 700:
                if stem_y_end > 10:
                    return stem_y_end, y_end
                else:
                    return 60.0, y_end  # no stem either, guess

            return y_start, y_end

    # Fallback
    if all_r:
        return all_r[-1].get("y_start", 60.0), all_r[-1].get("y_end", 400.0)
    return 60.0, 400.0


def get_all_question_labels(doc_id: str) -> list[str]:
    """Return ordered list of all question labels (e.g. ['Q1a', 'Q1b', 'Q2a', ...])."""
    url = ENV.get("SUPABASE_URL", "")
    resp = httpx.get(
        f"{url}/rest/v1/answer_keys?document_id=eq.{doc_id}&select=question_number,answer_text&order=question_number",
        headers=supabase_headers(), timeout=5,
    )
    if resp.status_code != 200 or not resp.json():
        return []
    labels = []
    for row in resp.json():
        ak = json.loads(row["answer_text"]) if isinstance(row["answer_text"], str) else row["answer_text"]
        q_num = row["question_number"]
        for part in ak.get("parts", []):
            labels.append(f"Q{q_num}{part.get('label', '')}")
        if not ak.get("parts"):
            labels.append(f"Q{q_num}")
    return labels


def show_doc_context(doc_id: str, target_label: str | None = None) -> tuple[str, list[dict], float]:
    """Fetch and display question + answer key. Returns (question_label, steps, y_start).
    If target_label is given (e.g. 'Q2a'), show that specific part."""
    url = ENV.get("SUPABASE_URL", "")

    # Parse target label to find question number + part
    target_qnum = None
    target_part = None
    if target_label and target_label.startswith("Q"):
        rest = target_label[1:]
        num_str = ""
        for ch in rest:
            if ch.isdigit():
                num_str += ch
            else:
                break
        target_qnum = int(num_str) if num_str else None
        target_part = rest[len(num_str):] or None

    query = f"{url}/rest/v1/answer_keys?document_id=eq.{doc_id}&select=answer_text,question_json"
    if target_qnum:
        query += f"&question_number=eq.{target_qnum}"
    resp = httpx.get(query, headers=supabase_headers(), timeout=5)
    if resp.status_code != 200 or not resp.json():
        print(f"  No answer key found for {doc_id}")
        return target_label or "Q1a", [], 150.0

    row = resp.json()[0]
    q_json = json.loads(row.get("question_json", "{}")) if isinstance(row.get("question_json"), str) else row.get("question_json", {})
    ak = json.loads(row["answer_text"]) if isinstance(row["answer_text"], str) else row["answer_text"]

    q_num = q_json.get("number", ak.get("question_number", 1))
    parts = ak.get("parts", [])

    # Find the target part
    chosen_part = None
    if target_part:
        for p in parts:
            if p.get("label") == target_part:
                chosen_part = p
                break
    if not chosen_part and parts:
        chosen_part = parts[0]

    part_label = chosen_part.get("label", "") if chosen_part else ""
    question_label = f"Q{q_num}{part_label}"
    steps = chosen_part.get("steps", []) if chosen_part else ak.get("steps", [])

    y_start, y_end = get_question_region(doc_id, q_num, part_label if part_label else None)

    print(f"\n  Document: {doc_id}")
    print(f"  Question: {q_json.get('text', '?')[:80]}")
    print(f"  Label: {question_label}  Steps: {len(steps)}")
    print(f"  Region: y={y_start:.0f}-{y_end:.0f} (PDF points)")
    for i, s in enumerate(steps):
        print(f"    Step {i+1}: {s.get('description', '')[:55]}")
        print(f"      Work: {s.get('work', '')[:55]}")
    print()

    origin_y = y_start + 10
    page_idx = get_page_for_question(doc_id, question_label)
    print(f"  Answer space: y={y_start:.0f} to {y_end:.0f} → stroke origin Y: {origin_y:.0f}, page: {page_idx}")
    return question_label, steps, origin_y, page_idx


def reset_question(user_id: str, doc_id: str, question_label: str) -> None:
    """Clear all simulation data for a question and reset sim state."""
    url = ENV.get("SUPABASE_URL", "")
    headers = supabase_headers()
    httpx.delete(f"{url}/rest/v1/simulation_strokes?user_id=eq.{user_id}", headers=headers, timeout=5)
    httpx.delete(f"{url}/rest/v1/student_work?user_id=eq.{user_id}&document_id=eq.{doc_id}&question_label=eq.{question_label}", headers=headers, timeout=5)
    httpx.delete(f"{url}/rest/v1/chat_history?user_id=eq.{user_id}&document_id=eq.{doc_id}&question_label=eq.{question_label}", headers=headers, timeout=5)
    print(f"  Cleared strokes, student_work, chat_history for {question_label}")


def send_command(user_id: str, command: str) -> None:
    """Send a command to the iPad via simulation_state.pending_command."""
    url = ENV.get("SUPABASE_URL", "")
    httpx.patch(
        f"{url}/rest/v1/simulation_state?user_id=eq.{user_id}",
        headers=supabase_headers(),
        json={"pending_command": command},
        timeout=5,
    )
    print(f"  Sent command: {command}")


def main():
    parser = argparse.ArgumentParser(description="Inject LaTeX as strokes onto connected iPad")
    parser.add_argument("latex", nargs="?", help="LaTeX expression to inject")
    parser.add_argument("--user-id", default=DEFAULT_USER_ID, help="Target user ID")
    parser.add_argument("--doc-id", default="", help="Document ID for context + realtime targeting")
    parser.add_argument("--question-label", default="Q1a", help="Question label (default Q1a)")
    parser.add_argument("--x", type=float, default=30.0, help="X origin")
    parser.add_argument("--y", type=float, default=150.0, help="Y origin")
    args = parser.parse_args()

    question_label = args.question_label
    steps: list[dict] = []
    y_pos = args.y
    doc_id = args.doc_id
    page_idx = 0

    # Auto-detect from simulation_state if no --doc-id provided
    if not doc_id:
        state = get_simulation_state(args.user_id)
        if state:
            doc_id = state["document_id"]
            question_label = state["question_label"]
            print(f"  Auto-detected: doc={doc_id[:12]}... label={question_label} step={state['step_index']}/{state['total_steps']}")

    if doc_id:
        question_label, steps, y_pos, page_idx = show_doc_context(doc_id, question_label)
        if args.y == 150.0:
            args.y = y_pos
        if not args.doc_id:
            args.doc_id = doc_id

    if args.latex:
        print(f"  Injecting: {args.latex}")
        send_strokes(args.latex, args.user_id, args.doc_id, question_label, args.x, args.y, page_index=page_idx)
    else:
        # Interactive mode
        print(f"  Interactive mode. Type LaTeX to inject. /quit to exit.")
        print(f"  User: {args.user_id}  Doc: {args.doc_id or '(none)'}  Label: {question_label}  Page: {page_idx}")
        y = args.y
        while True:
            try:
                latex = input("> ").strip()
            except (EOFError, KeyboardInterrupt):
                break
            if not latex or latex == "/quit":
                break
            if latex == "/status":
                state = get_simulation_state(args.user_id)
                if state:
                    print(f"  Step: {state.get('step_index', '?')}/{state.get('total_steps', '?')}")
                    print(f"  Status: {state.get('eval_status', '?')}  Progress: {state.get('eval_progress', '?')}")
                    print(f"  Evaluating: {state.get('is_evaluating', '?')}  Eval count: {state.get('eval_count', '?')}")
                    print(f"  Label: {state.get('question_label', '?')}")
                else:
                    print("  No simulation state found")
                continue
            if latex.startswith("/chat "):
                message = latex[6:].strip()
                if not message:
                    print("  Usage: /chat <question for tutor>")
                    continue
                state = get_simulation_state(args.user_id)
                step_idx = int(state["step_index"]) if state else 0
                print(f"  Asking tutor (step {step_idx})...")
                reply = send_chat(message, args.doc_id or (state["document_id"] if state else ""),
                                  question_label, step_idx)
                if reply:
                    print(f"  Tutor: {reply}")
                continue
            if latex == "/restart":
                send_command(args.user_id, "reset_question")
                reset_question(args.user_id, args.doc_id, question_label)
                y = args.y
                print(f"  Restarted {question_label}. Y reset to {y:.0f}")
                continue
            if latex == "/next":
                all_labels = get_all_question_labels(args.doc_id)
                try:
                    idx = all_labels.index(question_label)
                    if idx + 1 < len(all_labels):
                        next_label = all_labels[idx + 1]
                        send_command(args.user_id, "next_question")
                        import time; time.sleep(1)  # wait for iPad to process
                        reset_question(args.user_id, args.doc_id, question_label)
                        question_label = next_label
                        question_label, steps, y_pos, page_idx = show_doc_context(args.doc_id, question_label)
                        y = y_pos
                        args.y = y_pos
                    else:
                        print("  Already on the last question!")
                except ValueError:
                    print(f"  Current label {question_label} not found in: {all_labels}")
                continue
            if latex.startswith("/goto "):
                target = latex[6:].strip().upper()
                if not target.startswith("Q"):
                    target = "Q" + target
                send_command(args.user_id, f"goto:{target}")
                import time; time.sleep(1)
                reset_question(args.user_id, args.doc_id, question_label)
                question_label = target
                question_label, steps, y_pos, page_idx = show_doc_context(args.doc_id, question_label)
                y = y_pos
                args.y = y_pos
                continue
            if latex == "/list":
                all_labels = get_all_question_labels(args.doc_id)
                for lbl in all_labels:
                    marker = " ←" if lbl == question_label else ""
                    print(f"  {lbl}{marker}")
                continue
            if latex == "/help":
                print("  Commands:")
                print("    /status         — show tutor eval state")
                print("    /chat <msg>     — ask the tutor a question")
                print("    /correct <N>    — inject correct work for step N")
                print("    /restart        — clear current question and start over")
                print("    /next           — go to next question/part")
                print("    /goto Q2a       — jump to a specific question")
                print("    /list           — list all questions")
                print("    /help           — show this help")
                print("    /quit           — exit")
                print("    <latex>         — inject LaTeX as strokes")
                continue
            if latex.startswith("/correct") and steps:
                # Auto-inject correct work for current step
                parts = latex.split()
                step_num = int(parts[1]) - 1 if len(parts) > 1 else 0
                if 0 <= step_num < len(steps):
                    latex = steps[step_num].get("work", "")
                    print(f"  [correct] Step {step_num+1}: {latex[:50]}")
                else:
                    print(f"  [error] Step {parts[1]} not found")
                    continue
            print(f"  Injecting at y={y:.0f}...")
            send_strokes(latex, args.user_id, args.doc_id, question_label, args.x, y, page_index=page_idx)
            y += 50


if __name__ == "__main__":
    main()
