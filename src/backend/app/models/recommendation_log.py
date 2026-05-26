"""Recommendation log ORM model — tracks what was recommended to whom."""

from sqlalchemy import Column, String, Float, Integer, DateTime, ARRAY, JSON
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from app.models import Base


class RecommendationLog(Base):
    __tablename__ = "recommendation_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    request_id = Column(String, nullable=False, index=True)
    user_id = Column(String, nullable=True, index=True)
    session_id = Column(String, nullable=True)
    scene_class = Column(String, default="unknown")
    scene_features = Column(JSONB, default=dict)
    user_context = Column(JSONB, default=dict)
    recommended_pose_ids = Column(ARRAY(String), default=list)
    top_k = Column(Integer, default=5)
    engine_version = Column(String, default="rule-based-v1")
    created_at = Column(DateTime(timezone=True), server_default=func.now())
