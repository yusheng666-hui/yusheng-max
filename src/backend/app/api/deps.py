"""FastAPI dependencies — reusable dependency injection."""

from app.domain.recommendation.engine import engine as _recommend_engine


def get_recommendation_engine():
    """Return the singleton recommendation engine."""
    return _recommend_engine
