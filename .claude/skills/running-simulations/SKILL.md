---
name: running-simulations
description: Use when running tutor simulations, testing reasoning behavior, or the user asks to simulate a student session. Requires server running with ENVIRONMENT=development and a database connection.
---

# Running Simulations

> **Act as a struggling student working through a problem step by step. Monitor the tutor's responses on the dashboard at `/simulation`.**

**Prerequisites:** Server running on port 8000 with DB connected. Use the `startup` skill first if needed. Dashboard on port 3000 for visual monitoring.

## Quick Reference

| Action | Command |
|--------|---------|
| Start session | `POST /api/simulation/start` with `problem_text` + `answer_key` |
| Write work | `POST /api/simulation/write` with `session_id` + `transcription` |
| Ask question | `POST /api/simulation/ask` with `session_id` + `question` |
| Reset session | `POST /api/simulation/reset` with `session_id` |
| List sessions | `GET /api/simulation/sessions` |
| Monitor | Open `http://localhost:3000/simulation` in browser |

## Procedure

### 1. Start a session

```bash
curl -s -X POST http://localhost:8000/api/simulation/start \
  -H 'Content-Type: application/json' \
  -d '{"problem_text": "Solve: 2x - 7 = 3", "answer_key": [{"answer": "x = 5"}]}' \
  | python3 -m json.tool
```

Returns `{"session_id": "sim_...", "status": "ready"}`. Save the session_id.

Optional fields: `label` (default "Problem 1"), `question_number` (default 1), `subject` (default "math").

### 2. Open the dashboard

Navigate to `http://localhost:3000/simulation`. It auto-detects active sessions and shows:
- **Left sidebar**: problem setup, answer key, current transcription (raw), usage stats
- **Center**: reasoning timeline (tutor's responses with speak/silent badges)
- **Right**: student's work rendered in LaTeX

### 3. Simulate a struggling student

**Do NOT send the correct answer in one shot.** Build up work incrementally like a real student would. Each `/write` overwrites the full transcription, so include all previous lines plus new work.

**Pacing:**
1. Copy the problem first (just rewrite what's given)
2. Try one step — maybe wrong, maybe right
3. Pause and ask a question if confused
4. Try another step, possibly backtracking
5. Arrive at an answer (correct or not)
6. Ask "is this right?" or similar

**Realistic student behaviors to simulate — test ALL edge cases:**
- **Partial characters/expressions**: Write an incomplete expression mid-symbol (e.g. just `2x -` or `\frac{6x^3}{`) to test how tutor handles fragments
- **Stalling**: Write the problem but nothing else, or write one step and stop for multiple writes with no change
- **Partial work**: Write just the first step, wait for tutor reaction
- **Mistakes**: Make arithmetic errors, sign errors, apply wrong formulas, forget negatives
- **Mid-step pauses**: Write half an equation, send it, then complete it in the next write
- **Backtracking**: Cross out work (remove lines from transcription) and start over
- **Wrong approaches**: Use the completely wrong formula, then switch
- **Confusion questions**: "I don't know what to do next", "Which formula do I use?", "Why does this equal that?"
- **Self-correction**: Fix a mistake after the tutor hints at it
- **Nonsense/gibberish**: Send garbled text to test robustness
- **Repeated identical writes**: Send the same transcription twice in a row
- **Empty transcription edge**: Send just whitespace or a single character

**Example sequence for `2x - 7 = 3`:**

```
Write 1:  "2x - 7 = 3"                         (just copies problem)
Write 2:  "2x - 7 = 3\n2x ="                   (mid-step pause, hasn't finished the line)
Write 3:  "2x - 7 = 3\n2x = -4"                (wrong: added instead of subtracted)
Ask:      "Wait, do I add or subtract 7?"
Write 4:  "2x - 7 = 3\n2x = 10"                (corrected after hint)
Write 5:  "2x - 7 = 3\n2x = 10"                (identical — student paused, no new work)
Write 6:  "2x - 7 = 3\n2x = 10\nx = 4"         (division error)
Ask:      "Is my answer right?"
Write 7:  "2x - 7 = 3\n2x = 10\nx = 5"         (fixed)
```

**The goal is to cover every edge case a real iPad student would produce** — incomplete handwriting mid-stroke, pauses between steps, erasing and rewriting, asking questions at odd moments, etc.

### 4. Voice questions

```bash
curl -s -X POST http://localhost:8000/api/simulation/ask \
  -H 'Content-Type: application/json' \
  -d '{"session_id": "sim_XXX", "question": "I dont know what to do next"}' \
  | python3 -m json.tool
```

Good questions to test:
- "Is this right?"
- "I'm stuck, what do I do?"
- "Can you explain that step?"
- "Why did you say that?"
- "What formula do I use?"

### 5. Diagnose and fix the system prompt

After the simulation, review every tutor response and identify weaknesses. Common issues:

- **Too eager**: Spoke when it should have stayed silent (e.g. on repeated identical input, or when student is mid-step)
- **Too passive**: Stayed silent when a clear conceptual error warranted intervention
- **Too directive**: Gave away the answer instead of asking a guiding question
- **Repeated itself**: Said the same thing it already said in the history
- **Wrong tone**: Used jargon, LaTeX symbols, or multi-sentence responses
- **Missed error**: Didn't catch an arithmetic or conceptual mistake
- **False positive**: Flagged correct work as wrong (especially when the answer key has errors — the model tries to make the student's correct math match a wrong key)
- **Answer key bias**: Model assumed student was wrong because their result didn't match the key, even though the student's arithmetic was correct step-by-step

For each weakness found:
1. Identify the specific tutor response that was wrong
2. Trace it to which part of the system prompt allowed or caused it
3. Edit `SYSTEM_PROMPT` in `Reef-Server/lib/reasoning.py` to address it — add an explicit rule, tighten an existing rule, or add the scenario to the relevant section
4. Restart the server (`pkill -f "uvicorn api.index"` then restart)
5. Reset the session and re-run the same scenario to verify the fix

**Do NOT skip this step.** The simulation exists to improve the prompt. If you run a simulation and don't iterate on the prompt, the simulation was pointless. **ALWAYS iterate** — even if the results look mostly good, find at least one thing to improve and fix it. Commit the prompt change after verifying the fix.

### 6. Reset when done

```bash
curl -s -X POST http://localhost:8000/api/simulation/reset \
  -H 'Content-Type: application/json' \
  -d '{"session_id": "sim_XXX"}'
```

Deletes all DB data for the session.

## Benchmarking: 3-Step Error Detection Test

Use this when the user asks to benchmark or test a homework/document's questions for error detection accuracy. Do NOT write a Python script — run each question yourself via curl, one at a time.

### The 3-Step Pattern

For each question in the document:

**Step 1 — Wrong answer (expect `speak`):** Craft a realistic but incorrect answer yourself. Use your intelligence to create plausible errors: sign mistakes, wrong formulas, flawed logic, subtle arithmetic errors. Send via `/write`. The tutor should respond with `"action": "speak"` to flag the error.

**Step 2 — Correct answer (expect `silent`):** Send the answer key's correct answer via `/write`. The tutor should respond with `"action": "silent"` since nothing is wrong.

**Step 3 — Verification (expect confirmation):** Ask "Is my answer right?" via `/ask`. The tutor should confirm the answer is correct.

### Running the benchmark

1. Extract all questions for the document using `simulate-question` skill's DB queries (steps 2-3)
2. For each question:
   - Start a session, run the 3 steps, reset the session
   - Record: `+W` (wrong detected), `-W` (missed), `+C` (correct accepted), `-C` (false positive), `+V` (verified), `-V` (rejected)
3. Report results per-question and as a summary table

### Crafting wrong answers

**Do NOT use generic wrong answers** like "I think the answer involves applying the definition." These are too vague for the model to evaluate. Instead:
- For proofs: introduce a specific logical gap, wrong step, or false claim
- For computations: make a specific arithmetic or sign error
- For truth tables: get one cell wrong
- For set theory: add/remove an element from a set
- For arguments: claim the wrong validity (valid→invalid or vice versa)

**Before marking a miss**, verify the "wrong" answer is actually wrong. If the student's alternative approach is mathematically valid, it's not a miss — update your expectations.

### After benchmarking

Diagnose failures and prompt-engineer fixes (same as step 5 in the main procedure). Common patterns:
- Tutor accepts proofs that "look right" without checking each step → add verification instructions to system prompt
- Tutor misses subtle errors in long enumerations → add cell/element checking instruction
- Tutor rejects correct answers during verification → check if answer key is too restrictive

## Testing with Question Figures (image context)

Simulation sessions create their own document/question in the DB. To test image context (question figures), you must copy figures from an existing reconstructed question into the sim question after starting the session:

```python
# After POST /api/simulation/start returns session_id:
async with pool.acquire() as conn:
    sim_q = await conn.fetchrow(
        "SELECT q.id FROM questions q JOIN documents d ON q.document_id=d.id "
        "WHERE d.filename=$1", f"sim_{session_id}"
    )
    fig = await conn.fetchrow(
        "SELECT filename, image_b64 FROM question_figures WHERE question_id=$1",
        source_question_id,
    )
    await conn.execute(
        "INSERT INTO question_figures (question_id, filename, image_b64) VALUES ($1,$2,$3)",
        sim_q["id"], fig["filename"], fig["image_b64"],
    )
```

Verify with `GET /api/reasoning-preview?session_id=...&page=1` — look for `"Question Figures: N image(s) attached"` in sections.

## Tips

- **LaTeX in transcription**: Use `\\int`, `\\frac{a}{b}`, `x^2`, `\\sqrt{}` etc. for proper rendering on the right panel. Each `\n`-separated line renders as a separate equation.
- **Timeout**: `/write` and `/ask` calls block on the LLM — allow 30s timeout.
- **Server restart required** after any Reef-Server code changes for simulation endpoints to pick up changes.

## Gotchas

| Mistake | Consequence |
|---------|-------------|
| Sending correct answer immediately | Doesn't test the tutor's coaching ability. Build up incrementally. |
| Forgetting to escape `\` in JSON | `\frac` becomes a literal control character. Use `\\frac` in JSON strings. |
| Not waiting for response before next call | Reasoning calls are synchronous and slow (~2-5s). Wait for each to complete. |
| Session not found after server restart | `_simulation_sessions` is in-memory. Restart clears all sessions — must `/start` again. |
