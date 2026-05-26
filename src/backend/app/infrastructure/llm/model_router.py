"""LLM model router — selects and routes to the appropriate LLM."""

import logging
from typing import Optional

logger = logging.getLogger(__name__)


class ModelRouter:
    """Routes requests to the primary LLM, with automatic fallback."""

    def __init__(self):
        self.primary_vision_model = "qwen-vl-max"
        self.fallback_vision_model = "glm-4v"
        self.primary_text_model = "deepseek-chat"

    async def analyze_scene(self, scene_features: dict) -> dict:
        """
        Deep scene analysis using vision LLM.
        Falls back from Qwen-VL to GLM-4V on failure.
        """
        logger.info(f"Scene analysis via {self.primary_vision_model} (stub)")
        return {}

    async def rank_poses(
        self,
        candidates: list,
        scene_analysis: dict,
        user_context: dict,
    ) -> list:
        """
        Strategy reasoning for pose ranking using text LLM.
        """
        logger.info(f"Pose ranking via {self.primary_text_model} (stub)")
        return []

    async def generate_guidance(self, pose: dict, scene: dict) -> dict:
        """Generate natural language guidance for a pose in context."""
        return {}
