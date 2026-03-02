"""Deterministic Question → LaTeX converter.

Converts a structured Question object into LaTeX body text (no preamble,
no \\documentclass, no \\begin{document}).  The output is ready to be
wrapped by the LaTeX compiler's template.
"""

import re

from app.models.question import Part, Question

_CONTROL_CHARS = re.compile(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]')
_MATH_SPLIT_RE = re.compile(r'(\$[^$]+\$|\\\[.*?\\\]|\\\(.*?\\\))', re.DOTALL)


def _fix_json_latex_escapes(text: str) -> str:
    r"""Restore LaTeX commands corrupted by JSON escape interpretation."""
    text = re.sub(r'\t(ext|imes|heta|au)', r'\\t\1', text)
    text = re.sub(r'\x08(egin|f[{ ]|ar|eta|inom|ig|oldsymbol|oxed)', r'\\b\1', text)
    text = re.sub(r'\x0c(rac|orall)', r'\\f\1', text)
    text = re.sub(r'\r(ight|angle|aise|enewcommand)', r'\\r\1', text)
    return text


def _sanitize_text(text: str) -> str:
    """Fix text issues caused by JSON serialization."""
    text = _fix_json_latex_escapes(text)
    text = _CONTROL_CHARS.sub('', text)
    return text


def question_to_latex(question: Question) -> str:
    """Convert a Question to a LaTeX body string."""
    lines: list[str] = []

    if question.text:
        lines.append(_sanitize_text(question.text))
        lines.append("")

    if question.figures:
        lines.append(_render_figures(question.figures))
        lines.append("")

    if question.parts:
        for part in question.parts:
            lines.append(_render_part(part, depth=0))
            lines.append("")
    else:
        lines.append(f"\\vspace{{{question.answer_space_cm:.1f}cm}}")
        lines.append("")

    return "\n".join(lines).rstrip()


def _render_part(part: Part, depth: int) -> str:
    """Render a single part (and its subparts) to LaTeX."""
    lines: list[str] = []

    lines.append("\\needspace{4\\baselineskip}")
    lines.append(f"\\textbf{{({part.label})}} {_sanitize_text(part.text)}")

    if part.figures:
        lines.append("")
        lines.append(_render_figures(part.figures))

    if part.parts:
        lines.append("")
        for sub in part.parts:
            lines.append(_render_part(sub, depth=depth + 1))
            lines.append("")
    else:
        lines.append("")
        lines.append(f"\\vspace{{{part.answer_space_cm:.1f}cm}}")

    body = "\n".join(lines)

    if depth >= 1:
        body = f"\\begin{{adjustwidth}}{{1.5em}}{{0pt}}\n{body}\n\\end{{adjustwidth}}"

    return body


def _render_figures(filenames: list[str]) -> str:
    """Render one or more figures as LaTeX."""
    if not filenames:
        return ""

    if len(filenames) == 1:
        return (
            "\\begin{center}\n"
            f"\\fbox{{\\includegraphics[width=0.45\\linewidth]{{{filenames[0]}}}}}\n"
            "\\end{center}"
        )

    width = f"{0.93 / len(filenames):.2f}"
    parts: list[str] = []
    for fname in filenames:
        parts.append(
            f"\\begin{{minipage}}{{{width}\\linewidth}}\\centering\n"
            f"\\fbox{{\\includegraphics[width=\\linewidth]{{{fname}}}}}\n"
            f"\\end{{minipage}}"
        )
    return "\\begin{center}\n" + "\\hfill\n".join(parts) + "\n\\end{center}"
