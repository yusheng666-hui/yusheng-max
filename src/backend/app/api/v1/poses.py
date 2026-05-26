"""Pose endpoints — browse and detail for the 300-pose library."""

from fastapi import APIRouter, HTTPException, Query

from app.domain.recommendation.engine import engine
from app.schemas.pose import PoseListResponse, PoseDetailOut

router = APIRouter()


@router.get("/poses", response_model=PoseListResponse)
async def list_poses(
    scene: str = Query(default="", description="Filter by scene type (outdoor/street/indoor/beach/night)"),
    style: str = Query(default="", description="Filter by style tag (fresh/cool/sweet/elegant/natural/casual)"),
    difficulty: str = Query(default="", description="Filter by difficulty (beginner/intermediate/advanced)"),
    category: str = Query(default="", description="Filter by category (solo/couple/friends/family)"),
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
):
    """List poses with optional filters. Returns paginated results."""
    all_poses = engine.all_poses
    filtered = all_poses

    if scene:
        filtered = [
            p for p in filtered
            if scene in p["taxonomy"]["scene_type"]
        ]
    if style:
        filtered = [
            p for p in filtered
            if style in p["taxonomy"]["style"]
        ]
    if difficulty:
        filtered = [
            p for p in filtered
            if p["taxonomy"]["difficulty"] == difficulty
        ]
    if category:
        filtered = [
            p for p in filtered
            if p["taxonomy"]["category"] == category
        ]

    total = len(filtered)
    start = (page - 1) * page_size
    page_items = filtered[start : start + page_size]

    return {
        "poses": [
            {
                "pose_id": p["pose_id"],
                "name": p["name"],
                "category": p["taxonomy"]["category"],
                "style_tags": p["taxonomy"]["style"],
                "scene_types": p["taxonomy"]["scene_type"],
                "difficulty": p["taxonomy"]["difficulty"],
                "description": p.get("description", {}).get("zh", ""),
                "quality_score": p.get("metadata", {}).get("quality_score", 4.0),
            }
            for p in page_items
        ],
        "total": total,
        "page": page,
        "page_size": page_size,
    }


@router.get("/poses/{pose_id}", response_model=PoseDetailOut)
async def get_pose(pose_id: str):
    """Get full detail for a single pose by ID."""
    pose = engine.get_pose_by_id(pose_id)
    if pose is None:
        raise HTTPException(status_code=404, detail=f"Pose '{pose_id}' not found")

    return {
        "pose_id": pose["pose_id"],
        "name": pose["name"],
        "description": pose.get("description", {}),
        "taxonomy": pose["taxonomy"],
        "skeleton_3d": pose.get("skeleton_3d", {}),
        "guidance": pose.get("guidance", {}),
        "camera_params": pose.get("camera_params", {}),
        "reference_image_url": pose.get("reference_image_url"),
        "metadata": pose.get("metadata", {}),
    }
