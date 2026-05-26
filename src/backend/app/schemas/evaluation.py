"""Evaluation Pydantic schemas for photo review and feedback."""

from typing import Optional
from pydantic import BaseModel, Field


class PhotoFeatures(BaseModel):
    """Extracted features from the captured photo."""
    brightness_mean: float = Field(default=0.5, ge=0.0, le=1.0)
    contrast_rms: float = Field(default=0.3, ge=0.0, le=1.0)
    saturation_mean: float = Field(default=0.5, ge=0.0, le=1.0)
    sharpness: float = Field(default=0.6, ge=0.0, le=1.0)
    face_visible: bool = Field(default=True)
    face_count: int = Field(default=1, ge=0)
    pose_alignment: float = Field(default=0.7, ge=0.0, le=1.0,
        description="How well the user's pose matched the target skeleton")
    composition_score: float = Field(default=0.6, ge=0.0, le=1.0,
        description="Rule-of-thirds / leading-lines adherence")
    lighting_quality: float = Field(default=0.6, ge=0.0, le=1.0,
        description="Exposure balance, no blow-out or crush")


class EvaluationRequest(BaseModel):
    """Submit a captured photo for evaluation."""
    request_id: str = Field(default="eval-001")
    user_id: str = Field(default="u000000000001")
    pose_id: str = Field(..., description="The recommended pose the user attempted")
    session_id: Optional[str] = None
    scene_class: str = Field(default="outdoor-nature")
    photo_features: PhotoFeatures = Field(default_factory=PhotoFeatures)


class DimensionScore(BaseModel):
    score: float = Field(ge=0.0, le=10.0)
    label_zh: str
    feedback_zh: str


class EvaluationResponse(BaseModel):
    """Evaluation result with breakdown scores and improvement tips."""
    request_id: str
    overall_score: float = Field(ge=0.0, le=10.0)
    grade: str = Field(description="A+/A/B/C/D")
    dimensions: list[DimensionScore]
    improvement_tips: list[str]
    encouragement: str  # positive reinforcement, always
    preset_recommendation: Optional[str] = None  # best preset for this photo
    description: str = ""
