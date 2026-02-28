"""Unit tests for Pydantic model validation."""

import pytest
from pydantic import ValidationError

from lib.models.question import Part, Question, QuestionBatch
from lib.models.quiz import QuizGenerationRequest
from lib.models.group_problems import ProblemGroup, GroupProblemsResponse


# ── Part ────────────────────────────────────────────────────


class TestPart:
    def test_valid_minimal(self):
        p = Part(label="a", text="x")
        assert p.label == "a"
        assert p.text == "x"

    def test_answer_space_default_3(self):
        p = Part(label="a", text="x")
        assert p.answer_space_cm == 3.0

    def test_answer_space_zero_valid(self):
        p = Part(label="a", text="x", answer_space_cm=0.0)
        assert p.answer_space_cm == 0.0

    def test_answer_space_six_valid(self):
        p = Part(label="a", text="x", answer_space_cm=6.0)
        assert p.answer_space_cm == 6.0

    def test_answer_space_negative_fails(self):
        with pytest.raises(ValidationError):
            Part(label="a", text="x", answer_space_cm=-0.1)

    def test_answer_space_over_six_fails(self):
        with pytest.raises(ValidationError):
            Part(label="a", text="x", answer_space_cm=6.1)

    def test_recursive_parts(self):
        inner = Part(label="i", text="sub")
        outer = Part(label="a", text="main", parts=[inner])
        assert len(outer.parts) == 1
        assert outer.parts[0].label == "i"

    def test_figures_defaults_empty(self):
        p = Part(label="a", text="x")
        assert p.figures == []

    def test_parts_defaults_empty(self):
        p = Part(label="a", text="x")
        assert p.parts == []


# ── Question ────────────────────────────────────────────────


class TestQuestion:
    def test_valid_minimal(self):
        q = Question(number=1, text="hi")
        assert q.number == 1
        assert q.text == "hi"

    def test_requires_number(self):
        with pytest.raises(ValidationError):
            Question(text="hi")

    def test_requires_text(self):
        with pytest.raises(ValidationError):
            Question(number=1)

    def test_defaults_empty_lists(self):
        q = Question(number=1, text="hi")
        assert q.figures == []
        assert q.parts == []

    def test_with_parts(self):
        q = Question(number=1, text="hi", parts=[Part(label="a", text="sub")])
        assert len(q.parts) == 1
        assert q.parts[0].label == "a"


# ── QuestionBatch ───────────────────────────────────────────


class TestQuestionBatch:
    def test_valid(self):
        qb = QuestionBatch(questions=[Question(number=1, text="hi")])
        assert len(qb.questions) == 1

    def test_requires_questions(self):
        with pytest.raises(ValidationError):
            QuestionBatch()


# ── QuizGenerationRequest ──────────────────────────────────


class TestQuizGenerationRequest:
    def test_valid_full(self):
        r = QuizGenerationRequest(
            topic="algebra",
            difficulty="medium",
            num_questions=5,
            rag_context="some context",
            use_general_knowledge=True,
            additional_notes="note",
            question_types=["multiple_choice"],
        )
        assert r.topic == "algebra"
        assert r.num_questions == 5

    def test_num_questions_zero_fails(self):
        with pytest.raises(ValidationError):
            QuizGenerationRequest(
                topic="t", difficulty="d", num_questions=0, rag_context="c"
            )

    def test_num_questions_eleven_fails(self):
        with pytest.raises(ValidationError):
            QuizGenerationRequest(
                topic="t", difficulty="d", num_questions=11, rag_context="c"
            )

    def test_question_types_default(self):
        r = QuizGenerationRequest(
            topic="t", difficulty="d", num_questions=1, rag_context="c"
        )
        assert r.question_types == ["open_ended"]

    def test_additional_notes_optional(self):
        r = QuizGenerationRequest(
            topic="t", difficulty="d", num_questions=1, rag_context="c"
        )
        assert r.additional_notes is None


# ── ProblemGroup ────────────────────────────────────────────


class TestProblemGroup:
    def test_valid(self):
        pg = ProblemGroup(problem_number=1, annotation_indices=[0, 1])
        assert pg.problem_number == 1
        assert pg.annotation_indices == [0, 1]

    def test_zero_valid(self):
        pg = ProblemGroup(problem_number=0, annotation_indices=[])
        assert pg.problem_number == 0

    def test_label_defaults_empty(self):
        pg = ProblemGroup(problem_number=1, annotation_indices=[0])
        assert pg.label == ""


# ── GroupProblemsResponse ───────────────────────────────────


class TestGroupProblemsResponse:
    def test_valid(self):
        r = GroupProblemsResponse(
            problems=[ProblemGroup(problem_number=1, annotation_indices=[0])],
            total_annotations=1,
            total_problems=1,
            page_count=1,
        )
        assert r.total_problems == 1

    def test_missing_field_fails(self):
        with pytest.raises(ValidationError):
            GroupProblemsResponse(
                problems=[],
                total_annotations=1,
                total_problems=1,
                # missing page_count
            )
