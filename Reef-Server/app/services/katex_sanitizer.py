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

    # --- Expanded: handle more Mathpix outputs that KaTeX doesn't support ---

    # Chemistry: \ce{...} → strip to plain text content
    s = re.sub(r"\\ce\{([^}]*)\}", r"\\text{\1}", s)

    # \cancel, \bcancel, \xcancel — KaTeX supports \cancel but Mathpix
    # sometimes uses variants; normalize to \cancel or strip
    s = re.sub(r"\\bcancel\{([^}]*)\}", r"\\cancel{\1}", s)
    s = re.sub(r"\\xcancel\{([^}]*)\}", r"\\cancel{\1}", s)

    # \mbox{...} → \text{...} (KaTeX uses \text)
    s = re.sub(r"\\mbox\{([^}]*)\}", r"\\text{\1}", s)

    # \textrm, \textsl, \textsc — normalize to \text
    for cmd in ("textrm", "textsl", "textsc", "textup"):
        s = re.sub(rf"\\{cmd}\{{([^}}]*)\}}", r"\\text{\1}", s)

    # \ensuremath{...} → just the content
    s = re.sub(r"\\ensuremath\{([^}]*)\}", r"\1", s)

    # \mathrm{...} — KaTeX supports it, but Mathpix sometimes uses
    # \rm which is not supported; convert \rm{...} → \mathrm{...}
    s = re.sub(r"\\rm\{([^}]*)\}", r"\\mathrm{\1}", s)
    # Bare \rm (no braces) — strip it
    s = re.sub(r"\\rm\b(?!\{)", "", s)

    # \boldmath, \unboldmath — not in KaTeX, strip
    s = re.sub(r"\\(?:un)?boldmath\b", "", s)

    # \vcenter{...} → just content
    s = re.sub(r"\\vcenter\{([^}]*)\}", r"\1", s)

    # \adjustbox, \scalebox, \resizebox — strip wrapper, keep content
    for cmd in ("adjustbox", "scalebox", "resizebox"):
        # These can have multiple brace groups; take the last one as content
        s = re.sub(rf"\\{cmd}(?:\{{[^}}]*\}})*\{{([^}}]*)\}}", r"\1", s)

    # \intertext{...} → \text{...} (used in align environments)
    s = re.sub(r"\\intertext\{([^}]*)\}", r"\\text{\1}", s)

    # Strip entire tikz/pgf environments (can't render in KaTeX)
    s = re.sub(r"\\begin\{tikzpicture\}.*?\\end\{tikzpicture\}", "[diagram]", s, flags=re.DOTALL)
    s = re.sub(r"\\begin\{pgfpicture\}.*?\\end\{pgfpicture\}", "[diagram]", s, flags=re.DOTALL)

    # \includegraphics — can't render, replace with placeholder
    s = re.sub(r"\\includegraphics(?:\[[^\]]*\])?\{[^}]*\}", "[image]", s)

    # \href{url}{text} → just the text
    s = re.sub(r"\\href\{[^}]*\}\{([^}]*)\}", r"\1", s)
    # \url{...} → plain text
    s = re.sub(r"\\url\{([^}]*)\}", r"\\text{\1}", s)

    # Strip trailing whitespace/newlines
    s = s.strip()

    return s
