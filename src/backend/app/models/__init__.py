"""SQLAlchemy ORM models."""

from app.db.session import engine
from sqlalchemy.orm import declarative_base

Base = declarative_base()


async def create_all():
    """Create all tables (dev convenience)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
