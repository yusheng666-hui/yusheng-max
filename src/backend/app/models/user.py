"""User ORM model."""

from sqlalchemy import Column, String, Float, Integer, DateTime, ARRAY
from sqlalchemy.sql import func
from app.models import Base


class User(Base):
    __tablename__ = "users"

    user_id = Column(String, primary_key=True)
    username = Column(String, nullable=False, unique=True)
    display_name = Column(String, default="")
    gender = Column(String, default="unspecified")
    age_range = Column(String, default="18-25")
    height_cm = Column(Float, default=165.0)
    body_type = Column(String, default="average")
    face_shape = Column(String, default="oval")
    skin_tone = Column(String, default="medium")
    preferred_styles = Column(ARRAY(String), default=lambda: ["natural", "fresh"])
    preferred_difficulty = Column(String, default="beginner")
    photography_level = Column(String, default="beginner")
    quality_score = Column(Float, default=5.0)
    total_sessions = Column(Integer, default=0)
    total_photos = Column(Integer, default=0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
