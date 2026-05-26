"""User ORM model — Phase 2 PostgreSQL target.

Phase 1 uses JSON file store. This model defines the target schema
for Phase 2 migration with async SQLAlchemy + Alembic.
"""

# from sqlalchemy import Column, String, Float, Integer, DateTime, ARRAY
# from sqlalchemy.orm import declarative_base
# Base = declarative_base()

# class User(Base):
#     __tablename__ = "users"
#     user_id = Column(String, primary_key=True)
#     username = Column(String, nullable=False, unique=True)
#     display_name = Column(String)
#     gender = Column(String, default="unspecified")
#     age_range = Column(String)
#     height_cm = Column(Float, default=165.0)
#     body_type = Column(String)
#     face_shape = Column(String)
#     skin_tone = Column(String)
#     preferred_styles = Column(ARRAY(String))
#     preferred_difficulty = Column(String)
#     photography_level = Column(String)
#     quality_score = Column(Float, default=5.0)
#     total_sessions = Column(Integer, default=0)
#     total_photos = Column(Integer, default=0)
#     created_at = Column(DateTime)
#     updated_at = Column(DateTime)
