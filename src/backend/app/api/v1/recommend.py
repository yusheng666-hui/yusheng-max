"""Pose recommendation endpoint — core API."""

import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional

from app.domain.recommendation.engine import engine

logger = logging.getLogger(__name__)

router = APIRouter()


# --- Request / Response schemas ---

class LightingInfo(BaseModel):
    direction: List[float] = Field(default_factory=lambda: [0.0, 0.0, 1.0])
    intensity: float = 0.5
    color_temp: float = 5500.0
    contrast_ratio: float = 2.0


class SpatialInfo(BaseModel):
    dominant_planes: List[dict] = Field(default_factory=list)
    depth_range: List[float] = Field(default_factory=lambda: [0.0, 10.0])


class SceneFeaturesIn(BaseModel):
    scene_class: str = "outdoor-nature"
    scene_confidence: float = 0.9
    lighting: LightingInfo = Field(default_factory=LightingInfo)
    spatial: SpatialInfo = Field(default_factory=SpatialInfo)
    color_palette: List[str] = Field(default_factory=list)
    time_of_day: str = "afternoon"
    weather: str = "sunny"
    crowd_density: float = 0.2
    gps: Optional[List[float]] = None


class RecommendRequest(BaseModel):
    request_id: str
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    scene_features: SceneFeaturesIn = Field(default_factory=SceneFeaturesIn)
    user_context: dict = Field(default_factory=dict)
    top_k: int = Field(default=5, ge=1, le=10)


class Skeleton3D(BaseModel):
    keypoints: List[dict]
    anchor_point: str = "mid_hip"


class PoseRecommendationOut(BaseModel):
    pose_id: str
    rank: int
    score: float
    name: str = ""
    description: str = ""
    skeleton_3d: Skeleton3D
    guidance_text: str = ""
    voice_guidance: List[str] = Field(default_factory=list)
    standing_position: List[float] = Field(default_factory=lambda: [0.0, 2.0, 0.0])
    photographer_angle: Optional[dict] = None
    composition_hints: Optional[dict] = None
    lighting_tip: Optional[str] = None
    camera_params: Optional[dict] = None
    reference_image_url: Optional[str] = None


class RecommendResponse(BaseModel):
    request_id: str
    recommendations: List[PoseRecommendationOut]
    session_id: Optional[str] = None
    scene_detected: Optional[str] = None
    total_candidates: int = 0


# --- Endpoint ---

@router.post("/recommend", response_model=RecommendResponse)
async def recommend_poses(request: RecommendRequest):
    """Analyze scene features and return top pose recommendations.

    Phase 1: Rule-based matching against the 300-pose local database.
    Phase 2+: Will add Qwen-VL deep analysis, Milvus vector retrieval, and LLM ranking.
    """
    try:
        sf = request.scene_features.model_dump() if hasattr(request.scene_features, "model_dump") else request.scene_features.dict()

        results = await engine.recommend(
            scene_features=sf,
            user_context=request.user_context,
            top_k=request.top_k,
        )

        recommendations = []
        for r in results:
            cam = r.camera_params
            recommendations.append(PoseRecommendationOut(
                pose_id=r.pose_id,
                rank=r.rank,
                score=r.score,
                name=r.name,
                description=r.description,
                skeleton_3d=Skeleton3D(
                    keypoints=r.skeleton_3d["keypoints"],
                    anchor_point=r.skeleton_3d.get("anchor_point", "mid_hip"),
                ),
                guidance_text=r.photographer_tips,
                voice_guidance=r.voice_guidance,
                standing_position=r.standing_position,
                lighting_tip=r.guidance.get("lighting_tip"),
                camera_params=cam,
            ))

        return RecommendResponse(
            request_id=request.request_id,
            recommendations=recommendations,
            session_id=request.session_id,
            scene_detected=sf.get("scene_class", "unknown"),
            total_candidates=len(recommendations),
        )

    except Exception as e:
        logger.exception("Recommendation failed")
        raise HTTPException(status_code=500, detail=str(e))


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
