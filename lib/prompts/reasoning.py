"""Prompt templates for Tier 2 reasoning and feedback."""

REASONING_SYSTEM_PROMPT = (
    "You are a patient, Socratic STEM tutor. You are watching a student solve "
    "a problem in real time by observing their handwritten work transcribed to LaTeX. "
    "Your role is to assess their progress and, if needed, give a brief Socratic hint.\n\n"
    "Guidelines:\n"
    "- If the student is on track, say nothing (set feedback to null).\n"
    "- If you detect an error, give a Socratic hint: a guiding question, NOT the answer.\n"
    "- If the student appears stuck, offer a gentle nudge toward the next step.\n"
    "- If the student has completed the problem correctly, give brief encouragement.\n"
    "- Keep feedback under 2 sentences. Be warm but concise.\n"
    "- NEVER give away the answer or solve the problem for them.\n"
    "- Use plain English in feedback (no LaTeX). The student will hear this spoken aloud."
)


def build_reasoning_prompt(
    problem_text: str,
    problem_parts: list[dict],
    course_name: str,
    full_transcript: str,
    subquestion: str | None = None,
    previous_status: str | None = None,
    previous_feedback: str | None = None,
) -> str:
    """Build the reasoning prompt with full context.

    Args:
        problem_text: The problem statement text.
        problem_parts: List of {label, text} dicts for problem parts.
        course_name: Name of the course for context.
        full_transcript: Complete LaTeX transcript of student's work so far.
        subquestion: Which subquestion the student is working on, if known.
        previous_status: Last assessment status (on_track, minor_error, etc.).
        previous_feedback: Last feedback given, to avoid repetition.

    Returns:
        The complete user prompt for the reasoning model.
    """
    parts_text = ""
    if problem_parts:
        parts_lines = []
        for part in problem_parts:
            label = part.get("label", "?")
            text = part.get("text", "")
            parts_lines.append(f"  ({label}) {text}")
        parts_text = "\nParts:\n" + "\n".join(parts_lines)

    subq_text = ""
    if subquestion:
        subq_text = f"\nThe student is currently working on part: ({subquestion})"

    prev_text = ""
    if previous_status:
        prev_text = f"\nYour previous assessment: {previous_status}"
        if previous_feedback:
            prev_text += f"\nYour previous feedback: \"{previous_feedback}\""
        prev_text += "\nAvoid repeating the same feedback. Either say nothing or offer a new hint."

    return (
        f"Course: {course_name}\n\n"
        f"Problem:\n{problem_text}"
        f"{parts_text}"
        f"{subq_text}\n\n"
        f"Student's work so far (LaTeX transcript):\n{full_transcript}"
        f"{prev_text}\n\n"
        "Assess the student's progress and respond with a structured JSON object."
    )
