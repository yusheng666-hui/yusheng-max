"""Pose clone endpoint — store and retrieve cloned poses from photos.

The actual pose detection (MediaPipe) runs on-device in Flutter.
The backend stores results and cross-references with the pose library.
"""

import logging
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from app.domain.recommendation.engine import engine

logger = logging.getLogger(__name__)

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────


class CloneRequest(BaseModel):
    request_id: str = Field(default="clone-001")
    user_id: str = Field(default="u000000000001")
    keypoints: list[dict] = Field(
        default_factory=list,
        description="Detected keypoints from MediaPipe (33 landmarks)",
    )
    confidence: float = Field(default=0.8, ge=0.0, le=1.0)


class SimilarPose(BaseModel):
    pose_id: str
    name: str = ""
    similarity: float = 0.0
    category: str = ""
    style_tags: list[str] = Field(default_factory=list)


class CloneResponse(BaseModel):
    request_id: str
    status: str = "ok"
    keypoint_count: int = 0
    confidence: float = 0.0
    similar_library_poses: list[SimilarPose] = Field(default_factory=list)


# ── Endpoints ─────────────────────────────────────────────────────


@router.post("/poses/clone", response_model=CloneResponse)
async def clone_pose(req: CloneRequest):
    """Receive a cloned skeleton and find similar poses from the library."""
    kp_count = len(req.keypoints)
    similar = _find_similar_poses(req.keypoints, req.confidence)

    return CloneResponse(
        request_id=req.request_id,
        status="ok",
        keypoint_count=kp_count,
        confidence=req.confidence,
        similar_library_poses=similar,
    )


@router.get("/poses/clone/history")
async def get_clone_history(
    user_id: str = "u000000000001",
    page: int = 1,
    page_size: int = 20,
):
    """List user's clone history. Phase 2: backed by DB."""
    return {
        "user_id": user_id,
        "entries": [],
        "total": 0,
        "page": page,
        "page_size": page_size,
    }


# ── Helpers ───────────────────────────────────────────────────────


def _bbox_ar(kps: list[dict]) -> float:
    """Compute bounding box aspect ratio of keypoint set."""
    if not kps:
        return 1.0
    xs = [k.get("x", 0) for k in kps]
    ys = [k.get("y", 0) for k in kps]
    w = max(xs) - min(xs) or 0.01
    h = max(ys) - min(ys) or 0.01
    return w / h


def _find_similar_poses(keypoints: list[dict], confidence: float) -> list[SimilarPose]:
    """Find library poses with similar keypoint structure via heuristic matching."""
    all_poses = engine.all_poses
    if not keypoints or not all_poses:
        return []

    ar_src = _bbox_ar(keypoints)
    scored = []
    for pose in all_poses:
        lib_kps = pose.get("skeleton_3d", {}).get("keypoints", [])
        if not lib_kps:
            continue

        count_sim = 1.0 - abs(len(keypoints) - len(lib_kps)) / max(len(keypoints), len(lib_kps), 1)

        ar_lib = _bbox_ar(lib_kps)
        ar_sim = 1.0 - min(abs(ar_src - ar_lib) / max(ar_src, ar_lib, 1), 1.0)

        score = count_sim * 0.4 + ar_sim * 0.3 + confidence * 0.3
        if score > 0.3:
            scored.append((score, pose))

    scored.sort(key=lambda x: x[0], reverse=True)

    return [
        SimilarPose(
            pose_id=p["pose_id"],
            name=p["name"].get("zh", p["pose_id"]),
            similarity=round(s, 3),
            category=p["taxonomy"]["category"],
            style_tags=p["taxonomy"]["style"],
        )
        for s, p in scored[:3]
    ]
