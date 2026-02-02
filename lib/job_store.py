"""In-memory job store for async extraction jobs.

Note: Jobs are lost on container restart. For MVP this is acceptable.
Future improvement: Use Redis or PostgreSQL for persistence.
"""

import time
import uuid
from typing import Optional

from lib.models.extraction_job import ExtractionJob, JobStatus


# In-memory storage
_jobs: dict[str, ExtractionJob] = {}


def create_job(note_id: str) -> str:
    """
    Create a new extraction job.

    Args:
        note_id: UUID of the source note

    Returns:
        job_id: Unique identifier for the job
    """
    job_id = str(uuid.uuid4())
    job = ExtractionJob(
        job_id=job_id,
        note_id=note_id,
        status=JobStatus.PENDING,
        created_at=time.time()
    )
    _jobs[job_id] = job
    return job_id


def get_job(job_id: str) -> Optional[ExtractionJob]:
    """
    Get a job by ID.

    Args:
        job_id: The job identifier

    Returns:
        The job if found, None otherwise
    """
    return _jobs.get(job_id)


def update_job(job_id: str, **updates) -> Optional[ExtractionJob]:
    """
    Update a job with the given fields.

    Args:
        job_id: The job identifier
        **updates: Fields to update (status, result, error_message, completed_at)

    Returns:
        The updated job if found, None otherwise
    """
    job = _jobs.get(job_id)
    if job is None:
        return None

    for key, value in updates.items():
        if hasattr(job, key):
            setattr(job, key, value)

    return job


def cleanup_old_jobs(max_age_seconds: int = 3600) -> int:
    """
    Remove jobs older than max_age_seconds.

    Args:
        max_age_seconds: Maximum age before cleanup (default 1 hour)

    Returns:
        Number of jobs removed
    """
    now = time.time()
    old_jobs = [
        job_id for job_id, job in _jobs.items()
        if now - job.created_at > max_age_seconds
    ]

    for job_id in old_jobs:
        del _jobs[job_id]

    return len(old_jobs)
