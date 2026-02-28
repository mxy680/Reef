"""Tests for lib/question_to_latex.py — pure deterministic functions."""

from lib.models.question import Part, Question
from lib.question_to_latex import (
    _fix_json_latex_escapes,
    _render_figures,
    _render_part,
    _sanitize_text,
    question_to_latex,
    quiz_question_to_latex,
)


# ── _fix_json_latex_escapes ──────────────────────────────────

class TestFixJsonLatexEscapes:
    def test_tab_text(self):
        assert r"\text" in _fix_json_latex_escapes("\text")

    def test_tab_times(self):
        assert r"\times" in _fix_json_latex_escapes("\times")

    def test_backspace_begin(self):
        assert r"\begin" in _fix_json_latex_escapes("\x08egin")

    def test_formfeed_frac(self):
        assert r"\frac" in _fix_json_latex_escapes("\x0crac")

    def test_cr_right(self):
        assert r"\right" in _fix_json_latex_escapes("\right")

    def test_null_any_alpha(self):
        assert r"\a" in _fix_json_latex_escapes("\x00a")

    def test_passthrough(self):
        plain = "Hello world 123"
        assert _fix_json_latex_escapes(plain) == plain


# ── _sanitize_text ───────────────────────────────────────────

class TestSanitizeText:
    def test_strips_control_chars(self):
        result = _sanitize_text("a\x01b\x02c")
        assert result == "abc"

    def test_preserves_newline_and_tab(self):
        # \n and \t are NOT in the control chars regex (0x00-0x08, 0x0b, 0x0c, 0x0e-0x1f)
        # \n = 0x0a, \t = 0x09 — both outside the stripped range
        result = _sanitize_text("a\nb")
        assert "\n" in result

    def test_applies_escape_fix_then_strips(self):
        # \x08egin should become \begin, no leftover control char
        result = _sanitize_text("\x08egin{equation}")
        assert result == "\\begin{equation}"


# ── _render_figures ──────────────────────────────────────────

class TestRenderFigures:
    def test_empty_list(self):
        assert _render_figures([]) == ""

    def test_single_figure(self):
        result = _render_figures(["fig1.png"])
        assert "\\begin{center}" in result
        assert "\\fbox" in result
        assert "fig1.png" in result
        assert "minipage" not in result

    def test_two_figures(self):
        result = _render_figures(["a.png", "b.png"])
        assert result.count("minipage") == 4  # begin + end × 2
        assert "0.47" in result  # 0.93 / 2 = 0.465 → "0.47" (f"{:.2f}")

    def test_three_figures(self):
        result = _render_figures(["a.png", "b.png", "c.png"])
        assert "0.31" in result  # 0.93 / 3 = 0.31


# ── question_to_latex ────────────────────────────────────────

class TestQuestionToLatex:
    def test_text_only(self):
        q = Question(number=1, text="Solve for x.")
        result = question_to_latex(q)
        assert "Solve for x." in result
        assert "\\vspace{3.0cm}" in result  # default answer_space_cm

    def test_with_parts_no_vspace(self):
        q = Question(
            number=1,
            text="Consider the following.",
            parts=[Part(label="a", text="Part A"), Part(label="b", text="Part B")],
        )
        result = question_to_latex(q)
        # Stem should NOT have vspace when parts are present
        lines = result.split("\n")
        # vspace only appears inside parts, not at top level after stem
        stem_section = result.split("\\needspace")[0]
        assert "\\vspace{3.0cm}" not in stem_section

    def test_with_figures(self):
        q = Question(number=1, text="See figure.", figures=["img.png"])
        result = question_to_latex(q)
        assert "img.png" in result
        assert "See figure." in result

    def test_empty_text(self):
        q = Question(number=1, text="", parts=[Part(label="a", text="Only part")])
        result = question_to_latex(q)
        assert "Only part" in result


# ── _render_part ─────────────────────────────────────────────

class TestRenderPart:
    def test_depth_zero_no_adjustwidth(self):
        p = Part(label="a", text="Do this.")
        result = _render_part(p, depth=0)
        assert "adjustwidth" not in result
        assert "\\textbf{(a)}" in result

    def test_depth_one_adjustwidth(self):
        p = Part(label="i", text="Sub part.")
        result = _render_part(p, depth=1)
        assert "\\begin{adjustwidth}" in result
        assert "\\end{adjustwidth}" in result

    def test_nested_parts_recursive(self):
        inner = Part(label="i", text="Inner")
        outer = Part(label="a", text="Outer", parts=[inner])
        result = _render_part(outer, depth=0)
        assert "\\textbf{(a)}" in result
        assert "\\textbf{(i)}" in result
        assert "adjustwidth" in result  # inner at depth=1

    def test_part_with_figures(self):
        p = Part(label="a", text="See figure.", figures=["fig.png"])
        result = _render_part(p, depth=0)
        assert "fig.png" in result

    def test_answer_space_cm(self):
        p = Part(label="a", text="Solve.", answer_space_cm=5.0)
        result = _render_part(p, depth=0)
        assert "\\vspace{5.0cm}" in result


# ── quiz_question_to_latex ───────────────────────────────────

class TestQuizQuestionToLatex:
    def test_header_format(self):
        result = quiz_question_to_latex(3, "What is 2+2?")
        assert result.startswith("\\textbf{Question 3}")

    def test_answer_space(self):
        result = quiz_question_to_latex(1, "Solve.", answer_space_cm=4.0)
        assert "\\vspace{4.0cm}" in result

    def test_default_answer_space(self):
        result = quiz_question_to_latex(1, "Solve.")
        assert "\\vspace{5.0cm}" in result

    def test_sanitizes_text(self):
        result = quiz_question_to_latex(1, "\x08egin{equation}")
        assert "\\begin{equation}" in result
