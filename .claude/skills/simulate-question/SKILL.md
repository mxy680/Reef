---
name: simulate-question
description: Use when the user wants to test a specific question from the database via simulation. Extracts question text, parts, answer keys, and figures from the reef DB, starts a simulation session, and runs the full struggling-student simulation. Usage - /simulate-question <fuzzy_doc_name> <question_number>
arguments: true
---

# Simulate Question from Database

> Extract a real question from the reef database and run a full student simulation against it.

**Usage:** `/simulate-question <fuzzy_doc_name> <question_number>`

Examples:
- `/simulate-question engr 1` — first question from the ENGR_210 document
- `/simulate-question hw5 3` — third question from HW 5
- `/simulate-question hw4 2` — second question from HW4

## Procedure

### 1. Parse arguments

Split `$ARGUMENTS` into two parts:
- **fuzzy_doc_name**: everything except the last token (used for ILIKE match on `documents.filename`)
- **question_number**: the last token (1-based ordinal among the document's questions)

If `$ARGUMENTS` is empty or missing the question number, ask the user.

### 2. Find the document

```bash
psql -d reef -c "SELECT id, filename, total_problems FROM documents WHERE filename ILIKE '%<fuzzy_name>%' AND filename NOT LIKE 'sim_%' ORDER BY id DESC;"
```

- If **one match**: use it.
- If **multiple matches**: show the list and ask the user to pick.
- If **zero matches**: show all non-sim documents and ask the user to clarify.

### 3. Extract the question

```bash
psql -d reef -c "
  SELECT q.id, q.number, q.label, q.text, q.parts::text
  FROM questions q
  WHERE q.document_id = <doc_id>
  ORDER BY q.id
  OFFSET <question_number - 1> LIMIT 1;
"
```

Then get the answer keys:

```bash
psql -d reef -c "
  SELECT ak.part_label, ak.answer
  FROM answer_keys ak
  WHERE ak.question_id = <question_id>
  ORDER BY ak.part_label;
"
```

And check for figures:

```bash
psql -d reef -c "
  SELECT id, filename FROM question_figures WHERE question_id = <question_id>;
"
```

### 4. Print extracted data for confirmation

Display:
- Document name and question label
- Question text (truncated if very long)
- Parts (if any)
- Answer key entries
- Figure count

### 5. Check server health

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/health
```

If not 200, tell the user to start the server with the `startup` skill.

### 6. Start the simulation session

Build the JSON payload from extracted data:

```bash
curl -s -X POST http://localhost:8000/api/simulation/start \
  -H 'Content-Type: application/json' \
  -d '{
    "problem_text": "<question.text>",
    "answer_key": [{"part_label": "<ak.part_label>", "answer": "<ak.answer>"}, ...],
    "parts": [{"label": "<part.label>", "text": "<part.text>"}, ...],
    "label": "<question.label>",
    "question_number": <question.number>,
    "subject": "math"
  }' | python3 -m json.tool
```

Save the returned `session_id`.

### 7. Copy question figures (if any)

If the source question has figures, copy them to the sim question:

```bash
psql -d reef -c "
  INSERT INTO question_figures (question_id, filename, image_b64)
  SELECT sq.id, qf.filename, qf.image_b64
  FROM question_figures qf,
       (SELECT q.id FROM questions q JOIN documents d ON q.document_id = d.id
        WHERE d.filename = 'sim_<session_id>') sq
  WHERE qf.question_id = <source_question_id>;
"
```

### 8. Open the dashboard

Navigate to `http://localhost:3000/simulation` in the browser so the user can monitor.

### 9. Run the full simulation

Now follow the **running-simulations** skill procedure starting from step 3 ("Simulate a struggling student"). The session is already started and the dashboard is open.

Key reminders from that skill:
- **Do NOT send the correct answer in one shot.** Build up work incrementally.
- Test ALL edge cases: partial expressions, stalling, mistakes, backtracking, confusion questions.
- Each `/write` overwrites the full transcription — include all previous lines plus new work.
- After the simulation, **diagnose and fix the system prompt** — find at least one weakness and iterate.
- Use 30s timeout on `/write` and `/ask` calls (they block on the LLM).
- Reset the session when done.

### 10. Reset when done

```bash
curl -s -X POST http://localhost:8000/api/simulation/reset \
  -H 'Content-Type: application/json' \
  -d '{"session_id": "<session_id>"}'
```
