"""Prompt templates for Tier 1 handwriting transcription."""


def build_transcription_prompt(
    previous_transcript: str,
    problem_text: str = "",
    course_name: str = "",
    batches_since_check: int = 0,
    has_erasures: bool = False,
) -> str:
    """Build the transcription prompt with rolling context.

    Args:
        previous_transcript: Last ~2000 chars of existing transcript for continuity.
        problem_text: The problem the student is working on.
        course_name: Name of the course (e.g. "AP Calculus BC").
        batches_since_check: Number of screenshot batches since the last reasoning check.
        has_erasures: Whether the current image contains erased strokes (red).

    Returns:
        The complete prompt string for the transcription model.
    """
    context_section = ""
    if previous_transcript:
        # Trim to last 2000 chars for context window efficiency
        trimmed = previous_transcript[-2000:]
        context_section = (
            f"\n\nPrevious transcription (continue from here):\n{trimmed}"
        )

    problem_section = ""
    if problem_text or course_name:
        parts = []
        if course_name:
            parts.append(f"Course: {course_name}")
        if problem_text:
            parts.append(f"Problem: {problem_text[:500]}")
        problem_section = "\n\nStudent is working on:\n" + "\n".join(parts)

    erasure_section = ""
    if has_erasures:
        erasure_section = (
            "\n\nERASURE HANDLING:\n"
            "RED strokes are present — the student erased these. "
            "In addition to delta_latex, output a corrected_transcript field: "
            "take the previous transcription, REMOVE the content that corresponds "
            "to the red (erased) strokes, and INTEGRATE any new black strokes. "
            "The corrected_transcript should be the complete, updated transcript "
            "with erasures applied.\n"
            "Response JSON: {\"delta_latex\": \"...\", \"should_check\": true/false, "
            "\"corrected_transcript\": \"...\"}"
        )

    return (
        "You are a handwriting-to-LaTeX transcription model. "
        "The image shows the student's full canvas with handwritten math/science work.\n\n"
        "Colors in the image:\n"
        "- GRAY strokes = already transcribed. Do NOT re-transcribe these.\n"
        "- BLACK strokes = new work since last batch. Transcribe these.\n"
        "- RED strokes = erased by the student. If present, also output corrected_transcript "
        "with the erased content removed from the full transcript.\n\n"
        "You have TWO tasks. Respond with JSON: {\"delta_latex\": \"...\", \"should_check\": true/false}\n\n"
        "TASK 1 — TRANSCRIPTION:\n"
        "Output ONLY the LaTeX for the new (black) strokes. "
        "Do not repeat content from the previous transcription or gray strokes. "
        "Use inline $...$ for math expressions. "
        "If the new strokes are a continuation of a previous line, output only the new part.\n\n"
        "TASK 2 — CHECK SIGNAL:\n"
        "Set should_check to true if ANY of these apply:\n"
        "- Student just completed a logical step or sub-answer (finished an equation, boxed something)\n"
        "- Visible error (wrong sign, dropped variable, arithmetic mistake)\n"
        "- Student appears to be writing a final answer\n"
        "- New strokes show hesitation or repeated crossing-out\n"
        f"- Significant new work since last check (batches_since_check = {batches_since_check}; high means lots of unchecked work)\n\n"
        "Set should_check to false if the student is mid-expression or nothing notable changed. "
        "Default to false when uncertain."
        f"{erasure_section}"
        f"{problem_section}"
        f"{context_section}"
    )
