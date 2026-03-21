"""Sanitize Mathpix LaTeX output for KaTeX compatibility.

Fast, regex-only transforms — no LLM calls, no subprocess.
Called on every transcription response before returning to the client.
"""

import re


def sanitize_for_katex(latex: str) -> str:
    """Convert Mathpix LaTeX quirks to KaTeX-compatible syntax."""
    s = latex

    # Remove \tag{...} — equation numbering looks bad in sidebar
    s = re.sub(r"\\tag\{[^}]*\}", "", s)

    # \def and \newcommand not supported in KaTeX — strip them
    s = re.sub(r"\\def\\[a-zA-Z]+\{[^}]*\}", "", s)
    s = re.sub(r"\\newcommand\{[^}]*\}\{[^}]*\}", "", s)

    # \hspace{...} → \kern{...}
    s = re.sub(r"\\hspace\{([^}]*)\}", r"\\kern{\1}", s)

    # \mathrlap, \mathllap, \mathclap — not in KaTeX, strip wrapper
    for cmd in ("mathrlap", "mathllap", "mathclap"):
        s = re.sub(rf"\\{cmd}\{{([^}}]*)\}}", r"\1", s)

    # \displaystyle at start of expression — KaTeX supports it but
    # Mathpix sometimes puts it outside math mode
    s = re.sub(r"^\s*\\displaystyle\s*", "", s)

    # \limits placement: \sum\limits_{...} → \sum_{...}
    # KaTeX supports \limits but Mathpix sometimes misplaces it
    s = re.sub(r"\\(sum|prod|int|bigcup|bigcap|coprod|bigoplus|bigotimes)\\limits", r"\\\1", s)

    # Fix unbalanced \left / \right — if one is missing, remove both
    left_count = len(re.findall(r"\\left[\(\[\{|.]", s))
    right_count = len(re.findall(r"\\right[\)\]\}|.]", s))
    if left_count != right_count:
        s = re.sub(r"\\left([\(\[\{|.])", r"\1", s)
        s = re.sub(r"\\right([\)\]\}|.])", r"\1", s)

    # \boxed{} — KaTeX supports it, but Mathpix sometimes nests it oddly
    # Just leave it, KaTeX handles it fine

    # \begin{aligned} ... \end{aligned} — KaTeX supports this
    # \begin{array} ... \end{array} — KaTeX supports this
    # No changes needed for these

    # Strip trailing whitespace/newlines
    s = s.strip()

    return s
