"""Simulation helper — detects active document/question and drives the tutor.

Usage from Claude Code:
    python3 scripts/sim_helper.py status          # what's open right now
    python3 scripts/sim_helper.py write "latex"    # write student work + eval
    python3 scripts/sim_helper.py reset            # clear all work for active question
    python3 scripts/sim_helper.py steps            # show answer key steps
"""

import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Config — reads from shared env file
# ---------------------------------------------------------------------------

def _load_env():
    env = {}
    for path in [os.path.expanduser("~/.config/reef/server.env")]:
        if os.path.exists(path):
            for line in open(path):
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip()
    return env

ENV = _load_env()
SUPABASE_URL = ENV.get("SUPABASE_URL", "")
SERVICE_KEY = ENV.get("SUPABASE_SERVICE_ROLE_KEY", "")
ANON_KEY = ENV.get("SUPABASE_ANON_KEY", "")
SERVER_URL = "https://reef-api.fly.dev"
SIM_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sim_state.json")

def _headers():
    return {"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}", "Content-Type": "application/json"}

def _get(path, params=None):
    url = f"{SUPABASE_URL}/rest/v1/{path}"
    if params:
        url += "?" + "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(url, headers=_headers())
    return json.loads(urllib.request.urlopen(req).read())

def _delete(path, params):
    url = f"{SUPABASE_URL}/rest/v1/{path}?" + "&".join(f"{k}={v}" for k, v in params.items())
    req = urllib.request.Request(url, headers=_headers(), method="DELETE")
    urllib.request.urlopen(req)

def _post(path, data):
    h = _headers()
    h["Prefer"] = "resolution=merge-duplicates"
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/{path}",
        data=json.dumps(data).encode(), headers=h)
    urllib.request.urlopen(req)

def _get_token():
    resp = urllib.request.urlopen(urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
        data=json.dumps({"email": "markshteyn1@gmail.com", "password": "sim_test_2026"}).encode(),
        headers={"apikey": ANON_KEY, "Content-Type": "application/json"}
    ))
    return json.loads(resp.read())["access_token"]


# ---------------------------------------------------------------------------
# Detect active context
# ---------------------------------------------------------------------------

def get_user():
    """Get the first user."""
    resp = urllib.request.urlopen(urllib.request.Request(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}"}
    ))
    users = json.loads(resp.read()).get("users", [])
    return users[0] if users else None

def detect_context():
    """Detect active document, question, and step from Supabase."""
    user = get_user()
    if not user:
        return None
    user_id = user["id"]

    # Most recent canvas_strokes row = active question
    rows = _get("canvas_strokes", {
        "user_id": f"eq.{user_id}",
        "select": "document_id,question_label,tutor_step,tutor_status,tutor_progress,latex,updated_at",
        "order": "updated_at.desc",
        "limit": "1"
    })

    if not rows:
        # No strokes — find most recent document
        docs = _get("documents", {
            "select": "id,filename,problem_count,status",
            "order": "created_at.desc",
            "limit": "1"
        })
        if not docs:
            return None
        doc = docs[0]
        return {
            "user_id": user_id,
            "document_id": doc["id"],
            "filename": doc["filename"],
            "question_label": "Q1a",
            "question_number": 1,
            "part_label": "a",
            "step_index": 0,
            "tutor_status": "idle",
            "tutor_progress": 0,
            "current_latex": "",
        }

    row = rows[0]
    doc_id = row["document_id"]

    # Get document name
    docs = _get("documents", {"id": f"eq.{doc_id}", "select": "filename"})
    filename = docs[0]["filename"] if docs else "unknown"

    # Parse question label
    ql = row["question_label"]
    qn_str = ""
    for ch in ql[1:]:  # skip 'Q'
        if ch.isdigit():
            qn_str += ch
        else:
            break
    qn = int(qn_str) if qn_str else 1
    pl = ql[1 + len(qn_str):] or "a"

    return {
        "user_id": user_id,
        "document_id": doc_id,
        "filename": filename,
        "question_label": ql,
        "question_number": qn,
        "part_label": pl,
        "step_index": row.get("tutor_step") or 0,
        "tutor_status": row.get("tutor_status") or "idle",
        "tutor_progress": row.get("tutor_progress") or 0,
        "current_latex": row.get("latex") or "",
    }


def get_answer_key(doc_id, qn):
    """Get answer key steps for a question."""
    rows = _get("answer_keys", {
        "document_id": f"eq.{doc_id}",
        "question_number": f"eq.{qn}",
        "select": "answer_text,question_json"
    })
    if not rows:
        return None, None
    ak = rows[0]["answer_text"]
    qj = rows[0]["question_json"]
    if isinstance(ak, str):
        ak = json.loads(ak)
    if isinstance(qj, str):
        qj = json.loads(qj)
    return ak, qj


def get_chat_history(user_id, doc_id, ql):
    """Get chat history for a question."""
    rows = _get("chat_history", {
        "user_id": f"eq.{user_id}",
        "document_id": f"eq.{doc_id}",
        "question_label": f"eq.{ql}",
        "select": "role,text",
        "order": "created_at.asc"
    })
    return [{"role": r["role"], "text": r["text"]} for r in rows]


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

def write_and_eval(latex, ctx=None):
    """Write student latex and call tutor-evaluate. Returns eval result."""
    if ctx is None:
        ctx = detect_context()
    if not ctx:
        print("No active context found")
        return None

    user_id = ctx["user_id"]
    doc_id = ctx["document_id"]
    ql = ctx["question_label"]
    qn = ctx["question_number"]
    pl = ctx["part_label"]
    step = ctx["step_index"]

    # Write strokes + latex to canvas_strokes
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    try:
        from app.services.latex2strokes import latex_to_strokes
        strokes = latex_to_strokes(latex.split("\\\\")[0][:50])  # first line, truncated
        for s in strokes:
            s["x"] = [x + 120 for x in s["x"]]
            s["y"] = [y + 580 for y in s["y"]]
    except Exception:
        strokes = []

    _post("canvas_strokes", {
        "user_id": user_id,
        "document_id": doc_id,
        "question_label": ql,
        "page_index": 0,
        "strokes": strokes,
        "latex": latex,
        "updated_at": datetime.now(timezone.utc).isoformat(),
    })

    # Get chat history for the request
    history = get_chat_history(user_id, doc_id, ql)

    # Get auth token and call eval
    token = _get_token()
    body = json.dumps({
        "document_id": doc_id,
        "question_number": qn,
        "part_label": pl,
        "step_index": step,
        "student_latex": latex,
        "figure_urls": [],
        "history": history,
        "is_demo": False,
    }).encode()

    req = urllib.request.Request(f"{SERVER_URL}/ai/tutor-evaluate",
        data=body, headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"})
    result = json.loads(urllib.request.urlopen(req, timeout=60).read())

    # Update sim viewer state
    _update_sim_state(ctx, latex, result)

    return result


def reset_question(ctx=None):
    """Clear all work for the active question."""
    if ctx is None:
        ctx = detect_context()
    if not ctx:
        print("No active context found")
        return

    user_id = ctx["user_id"]
    doc_id = ctx["document_id"]
    ql = ctx["question_label"]

    for table in ["canvas_strokes", "chat_history", "student_work"]:
        try:
            _delete(table, {"user_id": f"eq.{user_id}", "document_id": f"eq.{doc_id}", "question_label": f"eq.{ql}"})
        except Exception:
            pass

    print(f"Reset {ql} for {ctx['filename']}")


def _update_sim_state(ctx, latex, result):
    """Update the sim viewer JSON file."""
    ak, qj = get_answer_key(ctx["document_id"], ctx["question_number"])
    parts = ak.get("parts", []) if ak else []
    part = next((p for p in parts if p["label"] == ctx["part_label"]), None)
    steps = part["steps"] if part else (ak.get("steps", []) if ak else [])

    q_text = qj.get("text", "") if qj else ""
    pt = ""
    for p in (qj or {}).get("parts", []):
        if p.get("label") == ctx["part_label"]:
            pt = p.get("text", "")
    if pt:
        q_text += f"\nPart ({ctx['part_label']}): {pt}"

    try:
        state = json.load(open(SIM_FILE))
    except Exception:
        state = {"history": []}

    # If question changed, reset history
    if state.get("question_text", "") != q_text:
        state["history"] = []

    state["student_latex"] = latex
    state["tutor_status"] = result["status"]
    state["tutor_progress"] = result["progress"]
    state["step_index"] = ctx["step_index"]
    state["total_steps"] = len(steps)
    state["steps"] = [s["description"] for s in steps]
    state["question_text"] = q_text

    if result["status"] == "completed":
        for _ in range(result.get("steps_completed", 1)):
            state["step_index"] = min(state["step_index"] + 1, state["total_steps"] - 1)

    state["history"].append({
        "status": result["status"],
        "step": ctx["step_index"],
        "progress": result["progress"],
        "says": result.get("mistake_explanation") or "",
        "speaks": result.get("speech_text") or "",
        "steps_completed": result.get("steps_completed", 1),
    })

    json.dump(state, open(SIM_FILE, "w"), indent=2)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    if len(sys.argv) < 2:
        print("Usage: sim_helper.py [status|write|reset|steps]")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "status":
        ctx = detect_context()
        if not ctx:
            print("No active context")
            return
        print(f"Document: {ctx['filename']} ({ctx['document_id'][:12]}...)")
        print(f"Question: {ctx['question_label']} step {ctx['step_index']}")
        print(f"Status: {ctx['tutor_status']} ({ctx['tutor_progress']:.0%})")
        if ctx["current_latex"]:
            print(f"Current work: {ctx['current_latex'][:100]}")

    elif cmd == "write":
        if len(sys.argv) < 3:
            print("Usage: sim_helper.py write 'latex expression'")
            sys.exit(1)
        latex = sys.argv[2]
        ctx = detect_context()
        result = write_and_eval(latex, ctx)
        if result:
            print(f"[{result['status']}] \"{result.get('speech_text', '')}\"")
            if result.get("mistake_explanation"):
                print(f"  LaTeX: {result['mistake_explanation'][:120]}")

    elif cmd == "reset":
        reset_question()

    elif cmd == "steps":
        ctx = detect_context()
        if not ctx:
            print("No active context")
            return
        ak, qj = get_answer_key(ctx["document_id"], ctx["question_number"])
        if not ak:
            print("No answer key")
            return
        parts = ak.get("parts", [])
        part = next((p for p in parts if p["label"] == ctx["part_label"]), None)
        steps = part["steps"] if part else ak.get("steps", [])
        print(f"Q{ctx['question_number']}{ctx['part_label']}: {len(steps)} steps")
        for i, s in enumerate(steps):
            marker = "→" if i == ctx["step_index"] else " "
            print(f"  {marker} {i+1}. {s['description']}: {s['work'][:80]}")

    else:
        print(f"Unknown command: {cmd}")


if __name__ == "__main__":
    main()
