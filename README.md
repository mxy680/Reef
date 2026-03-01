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

## Architecture

```
Reef/
├── Reef-iOS/        iPad app — SwiftUI, Apple Pencil, Supabase auth
├── Reef-Web/        Website  — Next.js, React, Framer Motion
└── scripts/         Setup, run, and deployment scripts
```

### Reef-iOS

Swift 6 &middot; SwiftUI &middot; iOS 18.2+ &middot; iPad only

The primary client. Handles Apple Pencil input with pressure sensitivity and palm rejection, streams strokes to the server, plays TTS audio responses, and manages course organization. Auth via Supabase (Apple Sign-In, Google OAuth).

### Reef-Web

Next.js 16 &middot; React 19 &middot; Framer Motion

Landing page with scroll-driven 3D hero animation, user dashboard for document management, course organization, analytics, and billing. Smooth scrolling via Lenis.

<br>

## Quick Start

**Prerequisites:** Git, Node.js, pnpm, Xcode (optional, for iOS)

```bash
git clone https://github.com/mxy680/Reef.git
cd Reef
./scripts/setup.sh
```

The setup script installs all dependencies and opens the iOS project in Xcode.

### Run locally

```bash
./scripts/run.sh       # Next.js on :3000
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
