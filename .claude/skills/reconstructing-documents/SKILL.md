---
name: reconstructing-documents
description: Use when the user provides a PDF (homework, handout, worksheet) and asks to reconstruct, recreate, or cleanly typeset it. Also use when converting scanned or messy PDFs into clean LaTeX-compiled output.
---

# Reconstructing Documents

> **Send the PDF to the Reef-Server `/ai/reconstruct` endpoint. It handles layout detection, problem extraction, LaTeX compilation, and PDF merging automatically.**

## Prerequisites

The local Reef dev server must be running on port 8000. If not:

```bash
cd Reef-Server && export $(grep -v '^#' .env | xargs) && source .venv/bin/activate && uvicorn api.index:app --reload --host 0.0.0.0 --port 8000
```

Verify: `curl -s http://localhost:8000/health`

## Reconstruct a PDF

```bash
curl -s -X POST "http://localhost:8000/ai/reconstruct" \
  -F "pdf=@/path/to/input.pdf" \
  -o "/path/to/output.pdf" \
  -w "\nHTTP_CODE:%{http_code}\nSIZE:%{size_download}\n"
```

**Timeout:** Pipeline takes 30-120s depending on page count. Use `--max-time 300`.

## Options

| Query Param | Default | Purpose |
|-------------|---------|---------|
| `debug=true` | `false` | Save intermediate files (annotated pages, crops) to `Reef-Server/data/` |
| `split=true` | `false` | Return individual per-problem PDFs as JSON instead of one merged PDF |

Example with debug: `"http://localhost:8000/ai/reconstruct?debug=true"`

## What the Pipeline Does

1. Renders PDF at 192 DPI (Surya layout detection) and 384 DPI (cropping)
2. Detects layout elements via Modal GPU Surya
3. Groups annotations into logical problems via Gemini
4. Extracts structured questions per problem group via Gemini
5. Compiles each problem to LaTeX via tectonic
6. Merges per-problem PDFs into single output

## Common Issues

| Problem | Fix |
|---------|-----|
| Server not running | Start with `starting-reef-dev` skill |
| 500 error | Check server logs — usually a Modal/Surya timeout or missing `OPENROUTER_API_KEY` |
| Empty/blank output | Run with `debug=true` and inspect `Reef-Server/data/` for intermediate artifacts |
| Figures missing | Surya may miss figures — pipeline has gap detection but complex layouts can fail |
