"""Pose API response schemas."""

from pydantic import BaseModel, Field


class PoseSummaryOut(BaseModel):
    pose_id: str
    name: dict
    category: str = ""
    style_tags: list[str] = Field(default_factory=list)
    scene_types: list[str] = Field(default_factory=list)
    difficulty: str = "beginner"
    description: str = ""
    quality_score: float = 4.0


class PoseListResponse(BaseModel):
    poses: list[PoseSummaryOut]
    total: int
    page: int
    page_size: int


class PoseDetailOut(BaseModel):
    pose_id: str
    name: dict
    description: dict = Field(default_factory=dict)
    taxonomy: dict = Field(default_factory=dict)
    skeleton_3d: dict = Field(default_factory=dict)
    guidance: dict = Field(default_factory=dict)
    camera_params: dict = Field(default_factory=dict)
    reference_image_url: str | None = None
    metadata: dict = Field(default_factory=dict)
