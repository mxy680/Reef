"""Pure function for checking whether a LaTeX string is semantically complete.

Completeness means the expression is self-contained: all brackets balanced,
environments closed, and no dangling binary operators at the boundaries.
"""

import re

# Binary operators that signal an incomplete expression when trailing or leading.
# Trailing: any of these at the end means the expression is cut off.
# Leading: most of these at the start mean the expression starts mid-expression,
#          EXCEPT '-' which is valid for negative numbers.
_TRAILING_OPS = (
    r"\+",
    r"-",
    r"=",
    r"\\cdot",
    r"\\times",
    r"\\div",
    r"<",
    r">",
    r"\\leq",
    r"\\geq",
    r"\\neq",
    r"\\pm",
    r"\\mp",
    r"\\approx",
)

_LEADING_OPS = (
    r"\+",
    r"=",
    r"\\cdot",
    r"\\times",
    r"\\div",
    r"<",
    r">",
    r"\\leq",
    r"\\geq",
    r"\\neq",
    r"\\pm",
    r"\\mp",
    r"\\approx",
    # '-' is intentionally omitted: "-3x" is a complete expression
)

_TRAILING_PATTERN = re.compile(
    r"(?:" + "|".join(_TRAILING_OPS) + r")\s*$"
)
_LEADING_PATTERN = re.compile(
    r"^\s*(?:" + "|".join(_LEADING_OPS) + r")(?:\s|$)"
)

_BEGIN_RE = re.compile(r"\\begin\{([^}]+)\}")
_END_RE = re.compile(r"\\end\{([^}]+)\}")
_LEFT_RE = re.compile(r"\\left[\(\[\{\|.]")
_RIGHT_RE = re.compile(r"\\right[\)\]\}\|.]")


def _count_unescaped_brackets(latex: str, open_char: str, close_char: str) -> bool:
    """Return True if open_char and close_char are balanced in latex.

    Skips backslash-escaped versions (e.g. '\\{', '\\(', '\\[').
    """
    depth = 0
    i = 0
    while i < len(latex):
        ch = latex[i]
        if ch == "\\" and i + 1 < len(latex):
            # Skip the next character — it's escaped
            i += 2
            continue
        if ch == open_char:
            depth += 1
        elif ch == close_char:
            depth -= 1
            if depth < 0:
                return False
        i += 1
    return depth == 0


def _environments_balanced(latex: str) -> bool:
    """Check that all \\begin{X} have a matching \\end{X} using a stack."""
    stack: list[str] = []
    # We need to process \\begin and \\end in order; use finditer on the full string.
    # Collect all markers with positions.
    markers: list[tuple[int, str, str]] = []  # (pos, kind, name)
    for m in _BEGIN_RE.finditer(latex):
        markers.append((m.start(), "begin", m.group(1)))
    for m in _END_RE.finditer(latex):
        markers.append((m.start(), "end", m.group(1)))
    markers.sort(key=lambda t: t[0])

    for _, kind, name in markers:
        if kind == "begin":
            stack.append(name)
        else:
            if not stack or stack[-1] != name:
                return False
            stack.pop()
    return len(stack) == 0


def is_semantically_complete(latex: str) -> bool:
    """Return True if the LaTeX string represents a complete mathematical expression.

    Checks:
    - Non-empty after stripping
    - Parentheses balanced (skipping escaped \\( \\))
    - Square brackets balanced (skipping escaped \\[ \\])
    - Curly braces balanced (skipping escaped \\{ \\})
    - \\begin{X} / \\end{X} environments matched
    - \\left / \\right balanced
    - No trailing binary operators
    - No leading binary operators (but leading '-' is allowed)
    """
    stripped = latex.strip()
    if not stripped:
        return False

    # Parentheses: ( )
    if not _count_unescaped_brackets(stripped, "(", ")"):
        return False

    # Square brackets: [ ]
    if not _count_unescaped_brackets(stripped, "[", "]"):
        return False

    # Curly braces: { }
    if not _count_unescaped_brackets(stripped, "{", "}"):
        return False

    # LaTeX environments
    if not _environments_balanced(stripped):
        return False

    # \left / \right balance
    left_count = len(_LEFT_RE.findall(stripped))
    right_count = len(_RIGHT_RE.findall(stripped))
    if left_count != right_count:
        return False

    # Trailing binary operators
    if _TRAILING_PATTERN.search(stripped):
        return False

    # Leading binary operators (excluding '-')
    if _LEADING_PATTERN.match(stripped):
        return False

    return True
