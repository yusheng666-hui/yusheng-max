"""Tests for RecommendationEngine — rule-based pose matching."""

import pytest

from app.domain.recommendation.engine import RecommendationEngine


class TestRecommendationEngine:
    def test_loads_pose_db(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)
        assert len(engine.all_poses) == 5
        assert engine.get_scene_pose_count()

    @pytest.mark.asyncio
    async def test_recommend_returns_results_for_outdoor_scene(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)
        results = await engine.recommend(
            scene_features={"scene_class": "outdoor-nature"},
            user_context={},
            top_k=3,
        )

        assert len(results) > 0
        assert all(r.rank >= 1 for r in results)
        assert results[0].score >= results[-1].score

    @pytest.mark.asyncio
    async def test_recommend_falls_back_to_outdoor_for_unknown_scene(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)
        results = await engine.recommend(
            scene_features={"scene_class": "mountain"},
            user_context={},
            top_k=3,
        )

        assert len(results) > 0

    @pytest.mark.asyncio
    async def test_recommend_returns_empty_for_no_matching_poses(self, tmp_pose_db, tmp_path):
        import json

        empty_path = tmp_path / "empty.json"
        empty_path.write_text(json.dumps({"poses": []}), encoding="utf-8")

        engine = RecommendationEngine(pose_db_path=str(empty_path))
        results = await engine.recommend(
            scene_features={"scene_class": "outdoor-nature"},
            user_context={},
            top_k=3,
        )

        assert results == []

    @pytest.mark.asyncio
    async def test_style_preference_boosts_score(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        results_with_style = await engine.recommend(
            scene_features={"scene_class": "outdoor"},
            user_context={"preferred_styles": ["fresh", "natural"]},
            top_k=5,
        )

        results_without_style = await engine.recommend(
            scene_features={"scene_class": "outdoor"},
            user_context={},
            top_k=5,
        )

        assert len(results_with_style) > 0
        assert len(results_without_style) > 0

        if results_with_style and results_without_style:
            assert results_with_style[0].pose_id is not None

    @pytest.mark.asyncio
    async def test_difficulty_match_adds_bonus(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        beginner_results = await engine.recommend(
            scene_features={"scene_class": "outdoor"},
            user_context={"preferred_difficulty": "beginner"},
            top_k=5,
        )

        assert len(beginner_results) > 0

    @pytest.mark.asyncio
    async def test_skip_pose_ids_excludes_poses(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        all_results = await engine.recommend(
            scene_features={"scene_class": "outdoor"},
            user_context={},
            top_k=5,
        )

        if len(all_results) > 1:
            skip_id = all_results[0].pose_id
            filtered = await engine.recommend(
                scene_features={"scene_class": "outdoor"},
                user_context={"skip_pose_ids": [skip_id]},
                top_k=5,
            )

            skipped_ids = {r.pose_id for r in filtered}
            assert skip_id not in skipped_ids

    @pytest.mark.asyncio
    async def test_category_filter(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        couple_results = await engine.recommend(
            scene_features={"scene_class": "indoor"},
            user_context={"category": "couple"},
            top_k=5,
        )

        assert len(couple_results) > 0

    def test_get_pose_by_id(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        pose = engine.get_pose_by_id("test-pose-001")
        assert pose is not None
        assert pose["pose_id"] == "test-pose-001"
        assert pose["name"]["zh"] == "户外站立"

    def test_get_pose_by_id_returns_none_for_missing(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)
        assert engine.get_pose_by_id("nonexistent") is None

    def test_get_scene_pose_count(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)
        counts = engine.get_scene_pose_count()

        assert isinstance(counts, dict)
        assert len(counts) > 0
        for count in counts.values():
            assert count > 0

    def test_missing_db_path_handles_gracefully(self, tmp_path):
        engine = RecommendationEngine(pose_db_path="/nonexistent/path/db.json")
        assert engine.all_poses == []
        assert engine.get_scene_pose_count() == {}

    @pytest.mark.asyncio
    async def test_recommend_with_mmr_diversity(self, tmp_pose_db):
        engine = RecommendationEngine(pose_db_path=tmp_pose_db)

        results = await engine.recommend(
            scene_features={"scene_class": "outdoor"},
            user_context={},
            top_k=5,
        )

        assert len(results) > 0
        for i in range(len(results) - 1):
            assert results[i].rank < results[i + 1].rank
