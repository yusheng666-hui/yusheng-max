import json
from pathlib import Path

import pytest


@pytest.fixture
def sample_poses() -> list[dict]:
    """A minimal pose set covering different scenes, styles, and categories."""
    return [
        {
            "pose_id": "test-pose-001",
            "name": {"zh": "户外站立", "en": "Outdoor Standing"},
            "taxonomy": {
                "scene_type": ["outdoor", "beach"],
                "style": ["fresh", "natural"],
                "difficulty": "beginner",
                "category": "solo",
            },
            "skeleton_3d": {
                "keypoints": [
                    {"id": 0, "name": "nose", "x": 0.5, "y": 0.3, "z": 0.0, "visibility": 1.0},
                    {"id": 12, "name": "right_shoulder", "x": 0.55, "y": 0.4, "z": 0.0, "visibility": 1.0},
                ],
                "anchor_point": "mid_hip",
            },
            "description": {"zh": "适合户外自然场景的基础站姿"},
            "guidance": {"zh": "站直身体，双手自然下垂"},
            "camera_params": {"iso": 100},
            "reference_image_url": None,
            "metadata": {"quality_score": 4.5, "popularity_score": 80},
        },
        {
            "pose_id": "test-pose-002",
            "name": {"zh": "街拍酷感", "en": "Street Cool"},
            "taxonomy": {
                "scene_type": ["street", "urban"],
                "style": ["cool", "elegant"],
                "difficulty": "intermediate",
                "category": "solo",
            },
            "skeleton_3d": {
                "keypoints": [
                    {"id": 0, "name": "nose", "x": 0.5, "y": 0.3, "z": 0.0, "visibility": 1.0},
                    {"id": 11, "name": "left_shoulder", "x": 0.4, "y": 0.35, "z": 0.0, "visibility": 1.0},
                ],
                "anchor_point": "mid_hip",
            },
            "description": {"zh": "街拍酷感姿势，适合城市背景"},
            "guidance": {"zh": "靠墙单腿弯曲"},
            "camera_params": {"iso": 200},
            "reference_image_url": None,
            "metadata": {"quality_score": 4.0, "popularity_score": 60},
        },
        {
            "pose_id": "test-pose-003",
            "name": {"zh": "夜景氛围", "en": "Night Mood"},
            "taxonomy": {
                "scene_type": ["night"],
                "style": ["moody", "elegant"],
                "difficulty": "advanced",
                "category": "solo",
            },
            "skeleton_3d": {
                "keypoints": [
                    {"id": 0, "name": "nose", "x": 0.5, "y": 0.3, "z": 0.0, "visibility": 1.0},
                ],
                "anchor_point": "mid_hip",
            },
            "description": {"zh": "夜景氛围感姿势"},
            "guidance": {"zh": "回眸看镜头"},
            "camera_params": {"iso": 800},
            "reference_image_url": None,
            "metadata": {"quality_score": 3.8, "popularity_score": 40},
        },
        {
            "pose_id": "test-pose-004",
            "name": {"zh": "室内双人", "en": "Indoor Couple"},
            "taxonomy": {
                "scene_type": ["indoor"],
                "style": ["sweet", "casual"],
                "difficulty": "beginner",
                "category": "couple",
            },
            "skeleton_3d": {
                "keypoints": [
                    {"id": 0, "name": "nose", "x": 0.5, "y": 0.3, "z": 0.0, "visibility": 1.0},
                ],
                "anchor_point": "mid_hip",
            },
            "description": {"zh": "室内双人互动姿势"},
            "guidance": {"zh": "牵手对望"},
            "camera_params": {"iso": 400},
            "reference_image_url": None,
            "metadata": {"quality_score": 4.2, "popularity_score": 55},
        },
        {
            "pose_id": "test-pose-005",
            "name": {"zh": "海滩跳跃", "en": "Beach Jump"},
            "taxonomy": {
                "scene_type": ["beach", "outdoor"],
                "style": ["fresh", "casual"],
                "difficulty": "intermediate",
                "category": "solo",
            },
            "skeleton_3d": {
                "keypoints": [
                    {"id": 0, "name": "nose", "x": 0.5, "y": 0.2, "z": 0.0, "visibility": 1.0},
                ],
                "anchor_point": "mid_hip",
            },
            "description": {"zh": "海滩跳跃抓拍姿势"},
            "guidance": {"zh": "跳跃抓拍"},
            "camera_params": {"iso": 200},
            "reference_image_url": None,
            "metadata": {"quality_score": 4.8, "popularity_score": 90},
        },
    ]


@pytest.fixture
def tmp_pose_db(tmp_path, sample_poses):
    """Write sample poses to a temp JSON file and return the path."""
    path = tmp_path / "pose_db.json"
    path.write_text(json.dumps({"poses": sample_poses}), encoding="utf-8")
    return str(path)
