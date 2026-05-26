"""POI (Point of Interest) ORM model — photo spots."""

from sqlalchemy import ARRAY, Column, DateTime, Float, String
from sqlalchemy.sql import func

from app.models import Base


class POI(Base):
    __tablename__ = "pois"

    poi_id = Column(String, primary_key=True)
    name_zh = Column(String, nullable=False)
    name_en = Column(String, default="")
    description_zh = Column(String, default="")
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    category = Column(String, default="scenic")  # scenic/urban/cafe/landmark/nature
    style_tags = Column(ARRAY(String), default=list)
    best_times = Column(ARRAY(String), default=list)  # morning/sunset/night/etc.
    scene_types = Column(ARRAY(String), default=list)
    photo_tips_zh = Column(String, default="")
    reference_images = Column(ARRAY(String), default=list)
    popularity = Column(Float, default=0.0)
    rating = Column(Float, default=4.0)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
