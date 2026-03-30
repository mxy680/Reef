"""Tests for latex_completeness.is_semantically_complete."""

import pytest

from app.services.latex_completeness import is_semantically_complete


# ---------------------------------------------------------------------------
# Complete expressions
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "3x + 5",
    "\\frac{a}{b}",
    "(a+b)(c+d)",
    "\\sum_{i=1}^n x_i",
    "\\begin{pmatrix}a\\end{pmatrix}",
    "5",
    "-3x",
    "x^2 + 2x + 1",
    "\\sqrt{x+1}",
    "\\left(\\frac{a}{b}\\right)",
])
def test_complete(latex: str) -> None:
    assert is_semantically_complete(latex) is True, f"Expected complete: {latex!r}"


# ---------------------------------------------------------------------------
# Incomplete parentheses
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "(3x",
    "f(x",
    "((a+b)",
])
def test_incomplete_parens(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


# ---------------------------------------------------------------------------
# Incomplete curly braces
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "\\frac{a}{",
    "\\sqrt{",
    "{x+1",
])
def test_incomplete_braces(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


# ---------------------------------------------------------------------------
# Trailing binary operators
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "3x +",
    "a =",
    "x \\cdot",
    "y \\times",
    "z \\div",
    "a <",
    "b >",
    "c \\leq",
    "d \\geq",
    "e \\neq",
    "f \\pm",
    "g \\mp",
    "h \\approx",
    "x -",
])
def test_trailing_operators(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


# ---------------------------------------------------------------------------
# Leading binary operators (excluding '-')
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "+ 3x",
    "= 5",
    "\\cdot x",
    "\\times 2",
])
def test_leading_operators(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


def test_leading_minus_is_complete() -> None:
    """Leading '-' is valid for a negative number."""
    assert is_semantically_complete("-3x") is True


# ---------------------------------------------------------------------------
# Unclosed environments
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "\\begin{align} x",
    "\\begin{pmatrix} a & b",
    "\\begin{cases} x & y \\end{align}",  # mismatched
])
def test_unclosed_environments(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


# ---------------------------------------------------------------------------
# Empty / whitespace
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("latex", [
    "",
    "   ",
    "\t\n",
])
def test_empty(latex: str) -> None:
    assert is_semantically_complete(latex) is False, f"Expected incomplete: {latex!r}"


# ---------------------------------------------------------------------------
# Escaped brackets are NOT counted as unbalanced
# ---------------------------------------------------------------------------

def test_escaped_brackets_not_counted() -> None:
    """\\{ and \\} are literal braces, not grouping — should be balanced."""
    assert is_semantically_complete("\\{a, b\\}") is True


def test_unescaped_unbalanced_after_escaped() -> None:
    """One real unmatched '{' following an escaped pair should fail."""
    assert is_semantically_complete("\\{a\\} {b") is False
