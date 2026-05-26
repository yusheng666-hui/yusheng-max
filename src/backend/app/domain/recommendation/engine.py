"""Recommendation engine — Phase 1 rule-based pose matching.

Loads the 300-pose local database and matches scenes to poses using
deterministic rules (scene type, style preference, difficulty).
Phase 2 will add Milvus vector retrieval and LLM ranking.
"""

import json
import logging
import os
import random
from dataclasses import dataclass

logger = logging.getLogger(__name__)


# Scene class mapping: client reports "outdoor-nature" → internal key "outdoor"
SCENE_CLASS_MAP = {
    "outdoor-nature": "outdoor",
    "outdoor": "outdoor",
    "urban-street": "street",
    "street": "street",
    "urban": "street",
    "indoor": "indoor",
    "indoor-cafe": "indoor",
    "indoor-home": "indoor",
    "beach": "beach",
    "beach-coast": "beach",
    "night-scene": "night",
    "night": "night",
    "night-neon": "night",
}

# Style mapping: user preference → pose styles
STYLE_MAP = {
    "fresh": ["fresh", "natural"],
    "cool": ["cool", "elegant"],
    "sweet": ["sweet", "fresh"],
    "elegant": ["elegant", "cool"],
    "casual": ["casual", "natural"],
    "natural": ["natural", "casual"],
}


@dataclass
class RecommendationResult:
    pose_id: str
    rank: int
    score: float
    skeleton_3d: dict
    guidance: dict
    camera_params: dict
    name: str
    description: str
    standing_position: list
    photographer_tips: str
    voice_guidance: list
    reference_image_url: str | None


class RecommendationEngine:
    """Orchestrates rule-based pose recommendation for Phase 1."""

    def __init__(self, pose_db_path: str | None = None):
        self._poses: dict = {}  # scene_key → list of pose dicts
        self._all_poses: list = []
        self._load_poses(pose_db_path)

    def _load_poses(self, path: str | None = None):
        """Load the local pose database JSON."""
        if path is None:
            # __file__ = src/backend/app/domain/recommendation/engine.py
            # Go up 4 levels to src/, then down to flutter_app/
            path = os.path.normpath(
                os.path.join(
                    os.path.dirname(__file__),
                    "..",
                    "..",
                    "..",
                    "..",
                    "flutter_app",
                    "assets",
                    "poses",
                    "local_pose_db.json",
                )
            )

        if not os.path.exists(path):
            logger.warning(f"Pose DB not found at {path}, engine will return empty results.")
            return

        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        self._all_poses = data.get("poses", [])
        for pose in self._all_poses:
            for scene in pose["taxonomy"]["scene_type"]:
                self._poses.setdefault(scene, []).append(pose)

        logger.info(f"Loaded {len(self._all_poses)} poses across {len(self._poses)} scenes.")

    async def recommend(
        self,
        scene_features: dict,
        user_context: dict,
        top_k: int = 5,
    ) -> list[RecommendationResult]:
        """
        Rule-based recommendation pipeline:

        1. Map scene_class to internal scene key
        2. Filter candidates by scene
        3. Score by style match + difficulty match
        4. Apply diversity-aware ranking (MMR)
        5. Return top_k results
        """
        scene_class = scene_features.get("scene_class", "outdoor-nature")
        scene_key = SCENE_CLASS_MAP.get(scene_class, "outdoor")

        # Get user preferences
        preferred_styles = user_context.get("preferred_styles", [])
        preferred_difficulty = user_context.get("preferred_difficulty", "beginner")
        user_skip_ids = set(user_context.get("skip_pose_ids", []))
        user_liked_ids = set(user_context.get("liked_pose_ids", []))
        category_filter = user_context.get("category", None)  # solo/couple/friends/family etc.

        # Filter by scene
        candidates = self._poses.get(scene_key, [])
        if not candidates:
            logger.warning(f"No poses found for scene {scene_key}, falling back to outdoor.")
            candidates = self._poses.get("outdoor", [])

        if not candidates:
            return []

        # If we have very few candidates for this scene, pull from adjacent scenes
        if len(candidates) < top_k * 3:
            extra = []
            for key, poses in self._poses.items():
                if key != scene_key:
                    extra.extend(poses[:5])
            candidates = candidates + extra

        # Score each candidate
        scored = []
        for pose in candidates:
            pid = pose["pose_id"]

            # Skip recently shown poses
            if pid in user_skip_ids:
                continue

            # Category filter (solo/couple/friends/family/expression/advanced_solo)
            if category_filter:
                pose_cat = pose["taxonomy"].get("category", "solo")
                if pose_cat != category_filter:
                    continue

            style_tags = pose["taxonomy"]["style"]
            difficulty = pose["taxonomy"]["difficulty"]

            # Scene match score (base 50)
            score = 50.0

            # Style match (up to +25)
            if preferred_styles:
                style_hits = sum(
                    1 for ps in preferred_styles for s in STYLE_MAP.get(ps, [ps]) if s in style_tags
                )
                score += min(style_hits * 8.0, 25.0)

            # Difficulty match (up to +10)
            if difficulty == preferred_difficulty:
                score += 10.0
            elif difficulty == "beginner":
                score += 5.0  # beginners can attempt intermediate

            # Previously liked bonus (+10)
            if pid in user_liked_ids:
                score += 10.0

            # Quality score from metadata
            quality = pose["metadata"].get("quality_score", 4.0)
            score += quality * 1.5

            # Small random factor for variety (±3)
            score += random.uniform(-3.0, 3.0)

            scored.append((score, pose))

        # Sort by score descending
        scored.sort(key=lambda x: x[0], reverse=True)

        # MMR diversity re-ranking: penalize similar styles
        selected: list[tuple[float, dict]] = []
        remaining = scored[: min(len(scored), top_k * 6)]  # candidate pool

        for _ in range(min(top_k, len(remaining))):
            if not remaining:
                break
            if not selected:
                # Pick highest-scored first
                best = remaining.pop(0)
                selected.append(best)
            else:
                # MMR: maximize score - lambda * max_similarity
                best_idx = 0
                best_mmr = -999.0
                for i, (score, pose) in enumerate(remaining):
                    style_set = set(pose["taxonomy"]["style"])
                    max_sim = max(
                        (
                            len(style_set & set(s["taxonomy"]["style"]))
                            / len(style_set | set(s["taxonomy"]["style"]))
                            if style_set | set(s["taxonomy"]["style"])
                            else 0
                        )
                        for _, s in selected
                    )
                    mmr = score - 0.3 * max_sim * 100
                    if mmr > best_mmr:
                        best_mmr = mmr
                        best_idx = i
                best = remaining.pop(best_idx)
                selected.append(best)

        # Build results
        results = []
        for rank, (score, pose) in enumerate(selected, 1):
            sk = pose.get("skeleton_3d", {})
            guidance = pose.get("guidance", {})
            camera = pose.get("camera_params", {})

            results.append(
                RecommendationResult(
                    pose_id=pose["pose_id"],
                    rank=rank,
                    score=round(score, 1),
                    skeleton_3d={
                        "keypoints": sk.get("keypoints", []),
                        "anchor_point": sk.get("anchor_point", "mid_hip"),
                    },
                    guidance=guidance,
                    camera_params=camera,
                    name=pose["name"].get("zh", pose["pose_id"]),
                    description=pose["description"].get("zh", ""),
                    standing_position=[0.0, 2.0, 0.0],
                    photographer_tips=guidance.get("photographer_tips", {}).get("zh", ""),
                    voice_guidance=guidance.get("voice_guidance", []),
                    reference_image_url=None,
                )
            )

        return results

    def get_pose_by_id(self, pose_id: str) -> dict | None:
        """Retrieve a single pose by its ID."""
        for pose in self._all_poses:
            if pose["pose_id"] == pose_id:
                return pose
        return None

    @property
    def all_poses(self) -> list:
        """Public read-only access to the full pose list."""
        return self._all_poses

    def get_scene_pose_count(self) -> dict:
        """Return the count of poses per scene for diagnostics."""
        return {k: len(v) for k, v in self._poses.items()}


# Singleton
engine = RecommendationEngine()
