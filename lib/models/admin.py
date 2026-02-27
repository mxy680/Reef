"""Pydantic models for admin dashboard endpoints."""

from pydantic import BaseModel


class AdminOverviewResponse(BaseModel):
    total_users: int
    total_documents: int
    total_reasoning_calls: int
    total_cost: float
    speak_count: int
    silent_count: int
    active_sessions: int


class AdminUserRow(BaseModel):
    apple_user_id: str
    display_name: str | None = None
    email: str | None = None
    created_at: str | None = None
    last_active: str | None = None
    session_count: int = 0
    reasoning_calls: int = 0


class AdminUserListResponse(BaseModel):
    users: list[AdminUserRow]
    total: int


class DailyCostRow(BaseModel):
    date: str
    calls: int
    prompt_tokens: int
    completion_tokens: int
    cost: float


class AdminCostResponse(BaseModel):
    rows: list[DailyCostRow]
    total_cost: float
    total_calls: int


class AdminReasoningStatsResponse(BaseModel):
    total_calls: int
    speak_count: int
    silent_count: int
    error_count: int
    avg_prompt_tokens: float
    avg_completion_tokens: float
    by_source: dict[str, int]
