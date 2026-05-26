"""Photo evaluation endpoint — scores captured photos and returns improvement tips."""

from fastapi import APIRouter, HTTPException

from app.schemas.evaluation import EvaluationRequest, EvaluationResponse
from app.domain.evaluation import service as eval_svc
from app.domain.user import service as user_svc

router = APIRouter()


@router.post("/evaluate", response_model=EvaluationResponse)
def evaluate_photo(req: EvaluationRequest):
    """Evaluate a captured photo against the recommended pose.

    Returns:
    - overall score (0-10) with grade (A+ to D)
    - per-dimension scores: pose, composition, lighting, quality, expression
    - improvement tips
    - recommended preset for post-processing
    """
    result = eval_svc.evaluate(req)

    # Update user's photo count and rolling quality score
    try:
        user_svc.increment_photos(req.user_id)
        user_svc.update_quality_score(req.user_id, result.overall_score)
    except Exception:
        pass  # user might not exist yet — non-critical

    return result
