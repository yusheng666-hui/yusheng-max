"""Pose CRUD endpoint."""

from fastapi import APIRouter

router = APIRouter()


@router.get("/poses/{pose_id}")
async def get_pose(pose_id: str):
    return {"pose_id": pose_id, "status": "not_implemented"}


@router.get("/poses")
async def list_poses(
    scene: str = "",
    style: str = "",
    difficulty: str = "",
    page: int = 1,
    page_size: int = 20,
):
    return {
        "poses": [],
        "total": 0,
        "page": page,
        "page_size": page_size,
    }
