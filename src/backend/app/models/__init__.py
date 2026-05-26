"""SQLAlchemy ORM models."""

from sqlalchemy.orm import declarative_base

from app.db.session import engine

Base = declarative_base()


async def create_all():
    """Create all tables (dev convenience)."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
