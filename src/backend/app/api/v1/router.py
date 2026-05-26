"""API v1 Router — aggregates all v1 endpoint modules."""

from fastapi import APIRouter

from . import health, recommend, poses, evaluate, users, presets

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(health.router, tags=["health"])
api_router.include_router(recommend.router, tags=["recommend"])
api_router.include_router(poses.router, tags=["poses"])
api_router.include_router(evaluate.router, tags=["evaluate"])
api_router.include_router(users.router, tags=["users"])
api_router.include_router(presets.router, tags=["presets"])
