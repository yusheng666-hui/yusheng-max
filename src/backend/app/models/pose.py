"""Pose ORM model — stored pose library."""

from sqlalchemy import Column, String, Float, Integer, DateTime, ARRAY, JSON
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB
from app.models import Base


class Pose(Base):
    __tablename__ = "poses"

    pose_id = Column(String, primary_key=True)
    name_zh = Column(String, nullable=False)
    name_en = Column(String, default="")
    category = Column(String, default="solo")  # solo/couple/friends/family
    description_zh = Column(String, default="")
    style_tags = Column(ARRAY(String), default=list)
    scene_types = Column(ARRAY(String), default=list)
    difficulty = Column(String, default="beginner")
    skeleton_3d = Column(JSONB, default=dict)  # {keypoints: [...], anchor_point: "mid_hip"}
    guidance = Column(JSONB, default=dict)  # photographer_tips, voice_guidance, etc.
    camera_params = Column(JSONB, default=dict)
    standing_position = Column(ARRAY(Float), default=lambda: [0.0, 2.0, 0.0])
    quality_score = Column(Float, default=4.0)
    usage_count = Column(Integer, default=0)
    reference_image_url = Column(String, default="")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
