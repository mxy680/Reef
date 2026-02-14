"""REST endpoint for on-demand DBSCAN stroke clustering."""

from fastapi import APIRouter, HTTPException

from lib.models.clustering import ClusterRequest, ClusterResponse
from lib.stroke_clustering import cluster_strokes

router = APIRouter()


@router.post("/api/cluster-strokes", response_model=ClusterResponse)
async def api_cluster_strokes(body: ClusterRequest):
    """Run DBSCAN clustering on all strokes for a session+page.

    Re-clustering is safe: old cluster data is replaced on each call.
    """
    try:
        return await cluster_strokes(
            session_id=body.session_id,
            page=body.page,
            eps=body.eps,
            min_samples=body.min_samples,
        )
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
