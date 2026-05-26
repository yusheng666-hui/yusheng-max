"""Recommendation Pydantic schemas — request/response models."""

from typing import Optional
from pydantic import BaseModel, Field


class LightingInfo(BaseModel):
    direction: list[float] = Field(default_factory=lambda: [0.0, 0.0, 1.0])
    intensity: float = 0.5
    color_temp: float = 5500.0
    contrast_ratio: float = 2.0


class SpatialInfo(BaseModel):
    dominant_planes: list[dict] = Field(default_factory=list)
    depth_range: list[float] = Field(default_factory=lambda: [0.0, 10.0])


class SceneFeaturesIn(BaseModel):
    scene_class: str = "outdoor-nature"
    scene_confidence: float = 0.9
    lighting: LightingInfo = Field(default_factory=LightingInfo)
    spatial: SpatialInfo = Field(default_factory=SpatialInfo)
    color_palette: list[str] = Field(default_factory=list)
    time_of_day: str = "afternoon"
    weather: str = "sunny"
    crowd_density: float = 0.2
    gps: Optional[list[float]] = None


class RecommendRequest(BaseModel):
    request_id: str
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    scene_features: SceneFeaturesIn = Field(default_factory=SceneFeaturesIn)
    user_context: dict = Field(default_factory=dict)
    top_k: int = Field(default=5, ge=1, le=10)


class Skeleton3DOut(BaseModel):
    keypoints: list[dict]
    anchor_point: str = "mid_hip"


class PoseRecommendationOut(BaseModel):
    pose_id: str
    rank: int
    score: float
    name: str = ""
    description: str = ""
    skeleton_3d: Skeleton3DOut
    guidance_text: str = ""
    voice_guidance: list[str] = Field(default_factory=list)
    standing_position: list[float] = Field(default_factory=lambda: [0.0, 2.0, 0.0])
    photographer_angle: Optional[dict] = None
    composition_hints: Optional[dict] = None
    lighting_tip: Optional[str] = None
    camera_params: Optional[dict] = None
    reference_image_url: Optional[str] = None


class RecommendResponse(BaseModel):
    request_id: str
    recommendations: list[PoseRecommendationOut]
    session_id: Optional[str] = None
    scene_detected: Optional[str] = None
    total_candidates: int = 0
