"""Pose recommendation endpoint — core API."""

import logging

from fastapi import APIRouter, HTTPException

from app.domain.recommendation.engine import engine
from app.schemas.recommend import (
    PoseRecommendationOut,
    RecommendRequest,
    RecommendResponse,
    Skeleton3DOut,
)

logger = logging.getLogger(__name__)

router = APIRouter()


# --- Endpoint ---


@router.post("/recommend", response_model=RecommendResponse)
async def recommend_poses(request: RecommendRequest):
    """Analyze scene features and return top pose recommendations.

    Phase 1: Rule-based matching against the 300-pose local database.
    Phase 2+: Will add Qwen-VL deep analysis, Milvus vector retrieval, and LLM ranking.
    """
    try:
        sf = request.scene_features.model_dump()

        results = await engine.recommend(
            scene_features=sf,
            user_context=request.user_context,
            top_k=request.top_k,
        )

        recommendations = []
        for r in results:
            cam = r.camera_params
            recommendations.append(
                PoseRecommendationOut(
                    pose_id=r.pose_id,
                    rank=r.rank,
                    score=r.score,
                    name=r.name,
                    description=r.description,
                    skeleton_3d=Skeleton3DOut(
                        keypoints=r.skeleton_3d["keypoints"],
                        anchor_point=r.skeleton_3d.get("anchor_point", "mid_hip"),
                    ),
                    guidance_text=r.photographer_tips,
                    voice_guidance=r.voice_guidance,
                    standing_position=r.standing_position,
                    lighting_tip=r.guidance.get("lighting_tip"),
                    camera_params=cam,
                )
            )

        return RecommendResponse(
            request_id=request.request_id,
            recommendations=recommendations,
            session_id=request.session_id,
            scene_detected=sf.get("scene_class", "unknown"),
            total_candidates=len(recommendations),
        )

    except Exception as e:
        logger.exception("Recommendation failed")
        raise HTTPException(status_code=500, detail=str(e)) from e


# --- Quick test endpoint ---


@router.get("/recommend/health")
async def recommend_health():
    """Return engine status for diagnostics."""
    return {
        "status": "ok",
        "engine": "rule-based-v1",
        "total_poses": len(engine._all_poses),
        "poses_per_scene": engine.get_scene_pose_count(),
    }
