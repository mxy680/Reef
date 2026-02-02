"""Models for async extraction job tracking."""

from dataclasses import dataclass, field
from typing import Optional
from enum import Enum


class JobStatus(str, Enum):
    """Status of an extraction job."""
    PENDING = "pending"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"


@dataclass
class ExtractionJob:
    """Tracks the state of an async extraction job."""
    job_id: str
    note_id: str
    status: JobStatus = JobStatus.PENDING
    created_at: float = 0.0
    completed_at: Optional[float] = None
    error_message: Optional[str] = None
    # Result stored as dict to avoid circular imports
    result: Optional[dict] = None
