---
name: testing-reconstruction
description: Use when testing document reconstruction quality. Uploads a PDF from ~/Documents/cwru to the Reef API, runs reconstruction, downloads the output, and evaluates accuracy by comparing original vs reconstructed.
---

# Testing Reconstruction

## Quick Start

```bash
cd Reef-Server && python scripts/test_reconstruct.py "~/Documents/cwru/ENGR-145/ENGR 145 - HW 1 - Due 9-5-24-1.pdf"
```

This uploads the PDF, triggers v2 reconstruction, polls for completion, and saves both original + output to a temp directory.

## Available Documents

```
~/Documents/cwru/
├── CHEM-111/
├── CSDS-233/
├── CSDS-234/
├── CSDS-302/
├── CSDS-310/
├── ENGR-145/    ← mechanics/physics with figures — good test cases
├── ESCE-275/
├── PHYS-121/
├── PHYS-122/
├── STAT-312/
└── misc/
```

## Full Workflow

1. **Pick a document** — ask the user or choose one. ENGR-145 homeworks are good because they have figures + math.

2. **Run the test script:**
   ```bash
   cd Reef-Server && python scripts/test_reconstruct.py "<pdf_path>" [--api-url http://localhost:8000]
   ```
   - Default API is production (`https://api.studyreef.com`)
   - Use `--api-url http://localhost:8000` for local dev server
   - Use `--output-dir <path>` to control where files are saved

3. **Read both PDFs** to compare:
   - Read the original PDF from the output directory
   - Read the reconstructed PDF from the output directory
   - Read metadata.json for pipeline stats

4. **Evaluate accuracy** — check for these common issues:
   - **Missing figures**: images should appear where the original had them
   - **Placeholder text**: "Placeholder for Image", "[Image]", "[Figure]" instead of actual images
   - **Duplicated text**: question parts repeated in both stem and parts list
   - **Math errors**: broken LaTeX, wrong symbols, missing equations
   - **Missing questions**: fewer problems extracted than exist in original
   - **Formatting issues**: tables mangled, bullet lists wrong, spacing off
   - **Wrong part labels**: (a), (b), (c) don't match original
   - **Answer space**: too much or too little space allocated

5. **Report results** — summarize what's correct and what's wrong, with specific problem numbers.

## Script Options

| Flag | Default | Purpose |
|------|---------|---------|
| `--api-url` | `https://api.studyreef.com` | API endpoint (use `http://localhost:8000` for local) |
| `--output-dir` | `/tmp/reef-test-*` | Where to save original + reconstructed PDFs |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Auth error (401/403) | Test user may not exist yet — script auto-creates on first run |
| Timeout | Pipeline takes up to 9 min for long docs. Wait or check server logs |
| "Could not download source PDF" | Upload to storage failed — check SUPABASE_SERVICE_ROLE_KEY in ~/.config/reef/server.env |
