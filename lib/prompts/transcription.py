"""Prompt templates for Tier 1 handwriting transcription."""


def build_transcription_prompt(previous_transcript: str) -> str:
    """Build the transcription prompt with rolling context.

    Args:
        previous_transcript: Last ~2000 chars of existing transcript for continuity.

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

    return (
        "You are a handwriting-to-LaTeX transcription model. "
        "The image shows handwritten math/science work on paper. "
        "New strokes appear in BLACK. Previously transcribed strokes appear in GRAY for context.\n\n"
        "Output ONLY the LaTeX for the new (black) strokes. "
        "Do not repeat content from the previous transcription. "
        "Use inline $...$ for math expressions. "
        "If the new strokes are a continuation of a previous line, output only the new part."
        f"{context_section}"
    )
