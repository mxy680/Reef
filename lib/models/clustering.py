"""Pydantic models for stroke clustering endpoint."""

from pydantic import BaseModel, Field


class ClusterRequest(BaseModel):
    session_id: str
    page: int
    eps: float = Field(default=20.0, gt=0)
    min_samples: int = Field(default=1, ge=1)


class ClusterInfo(BaseModel):
    cluster_label: int
    stroke_count: int
    centroid: list[float]       # [x, y]
    bounding_box: list[float]   # [x1, y1, x2, y2]


class ClusterResponse(BaseModel):
    session_id: str
    page: int
    num_strokes: int
    num_clusters: int
    noise_strokes: int
    clusters: list[ClusterInfo]
