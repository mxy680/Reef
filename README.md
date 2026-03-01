<div align="center">

# Reef

**An AI tutor that reads your handwriting and talks to you while you work.**

Built for iPad. Built for STEM students.

[Download](https://reef.study) &nbsp;&middot;&nbsp; [Website](https://reef.study) &nbsp;&middot;&nbsp; [Documentation](#architecture)

---

*Now in beta. Free to use.*

</div>

<br>

## The Problem

Every night, millions of students get stuck on homework with no one to help. They bounce between a notes app, a PDF reader, and ChatGPT. Every context switch breaks focus. By the time office hours open, the momentum is gone.

## The Solution

Reef is a single iPad app where you upload your homework, solve problems with Apple Pencil, and get real-time voice feedback from an AI tutor that reads your handwriting as you write. No prompts. No typing. Just write, and Reef talks to you about your work.

<br>

## Features

| | |
|---|---|
| **Proactive AI Tutoring** | Reef watches your work and speaks up during natural pauses. It catches mistakes, asks guiding questions, and nudges you forward without giving away the answer. |
| **Handwriting Recognition** | Write math, chemistry, or prose with Apple Pencil. Reef transcribes equations, chemical structures, and diagrams in real time. |
| **Voice Interaction** | Ask Reef a question out loud. It listens, understands context from your page, and responds with spoken feedback. |
| **Smart Document Processing** | Upload homework PDFs and Reef auto-extracts problems, answer keys, and figures. It checks your work against the solutions as you go. |
| **Exam Generation** | Reef generates practice quizzes from your course materials. Multiple choice, free response, and more. |
| **Gamified Progress** | Master topics to unlock marine species and build a personal reef that grows as you learn. |

<br>

## How It Works

```
 ┌──────────────────────────────────────┐
 │           iPad + Apple Pencil        │
 │                                      │
 │   Student writes on the canvas.      │
 │   Strokes stream to the server.      │
 └──────────────────┬───────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────┐
 │            Reef Server               │
 │                                      │
 │   Mathpix transcribes handwriting.   │
 │   Context is built (transcription,   │
 │   answer key, earlier work, erased   │
 │   work snapshots).                   │
 └──────────────────┬───────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────┐
 │          AI Reasoning Model          │
 │                                      │
 │   Qwen3 VL 235B (multimodal) with   │
 │   streaming early-exit decides:      │
 │   speak or stay silent.              │
 └──────────────────┬───────────────────┘
                    │
                    ▼
 ┌──────────────────────────────────────┐
 │          Back to the iPad            │
 │                                      │
 │   If the model speaks, TTS audio     │
 │   streams to the student via SSE.    │
 │   The loop continues as they write.  │
 └──────────────────────────────────────┘
```

<br>

## Architecture

```
Reef/
├── Reef-iOS/        iPad app — SwiftUI, Apple Pencil, Supabase auth
├── Reef-Server/     Backend  — FastAPI, async Python, PostgreSQL
├── Reef-Web/        Website  — Next.js, React, Framer Motion
└── scripts/         Setup, run, and deployment scripts
```

### Reef-iOS

Swift 6 &middot; SwiftUI &middot; iOS 18.2+ &middot; iPad only

The primary client. Handles Apple Pencil input with pressure sensitivity and palm rejection, streams strokes to the server, plays TTS audio responses, and manages course organization. Auth via Supabase (Apple Sign-In, Google OAuth).

### Reef-Server

Python 3.11+ &middot; FastAPI &middot; asyncpg &middot; Docker

The brain. All AI processing, document reconstruction, handwriting transcription, and audio synthesis happen here. Key subsystems:

- **Stroke pipeline** — 500ms debounced transcription via Mathpix, 2.5s debounced reasoning
- **Reasoning engine** — Qwen3 VL 235B with streaming early-exit (~70-80% of calls break early)
- **PDF reconstruction** — Surya layout detection + Gemini extraction + LaTeX compilation
- **Voice** — Groq Whisper transcription, DeepInfra Kokoro TTS streaming
- **Push events** — Server-Sent Events (SSE), not WebSockets

### Reef-Web

Next.js 16 &middot; React 19 &middot; Framer Motion

Landing page with scroll-driven 3D hero animation, user dashboard for document management, course organization, analytics, and billing. Smooth scrolling via Lenis.

<br>

## Quick Start

**Prerequisites:** Git, Node.js, pnpm, uv (Python), Xcode (optional, for iOS)

```bash
git clone https://github.com/mxy680/Reef.git
cd Reef
./scripts/setup.sh
```

The setup script installs all dependencies and opens the iOS project in Xcode.

### Run locally

```bash
# Everything at once
./scripts/run.sh

# Or individually
./scripts/run.sh server    # FastAPI on :8000
./scripts/run.sh web       # Next.js on :3000
```

### Run tests

```bash
cd Reef-Server
uv run python -m pytest tests/ -q    # 193 tests (112 unit, 81 integration)
```

<br>

## External Services

| Service | Role |
|---------|------|
| [OpenRouter](https://openrouter.ai) | Qwen3 VL (tutoring), Gemini 3 Flash (PDF/quiz) |
| [Mathpix](https://mathpix.com) | Handwriting transcription |
| [Groq](https://groq.com) | Whisper voice-to-text |
| [DeepInfra](https://deepinfra.com) | Kokoro TTS audio streaming |
| [Modal](https://modal.com) | GPU endpoints (Surya layout, MiniLM embeddings) |
| [Supabase](https://supabase.com) | Auth and database |

<br>

## Pricing

| Shore | Reef | Abyss |
|:---:|:---:|:---:|
| Free | $9.99/mo | $29.99/mo |
| 1 course | 5 courses | Unlimited |
| 5 homeworks | 50 homeworks | Unlimited |
| 2 hrs tutoring | 20 hrs tutoring | Unlimited |

<br>

## Subjects

Reef understands notation across STEM: calculus, linear algebra, differential equations, organic chemistry, physics, circuit analysis, and more. Diagram mode handles geometry, molecular structures, and circuit diagrams via multimodal vision.

<br>

---

<div align="center">

**Reef** &nbsp;&middot;&nbsp; Stay afloat this finals season.

</div>
