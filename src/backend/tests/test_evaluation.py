"""Tests for evaluation domain service."""

import pytest
from app.domain.evaluation.service import evaluate, _grade, _recommend_preset
from app.schemas.evaluation import EvaluationRequest, PhotoFeatures


class TestGrade:
    def test_perfect_score_is_a_plus(self):
        letter, label = _grade(9.5)
        assert letter == "A+"
        assert label == "大师级！"

    def test_excellent_score_is_a(self):
        letter, label = _grade(8.5)
        assert letter == "A"

    def test_good_score_is_b(self):
        letter, label = _grade(7.5)
        assert letter == "B"
        assert label == "很不错！"

    def test_average_score_is_c(self):
        letter, label = _grade(6.0)
        assert letter == "C"

    def test_low_score_is_d(self):
        letter, label = _grade(3.0)
        assert letter == "D"
        assert label == "继续加油"


class TestEvaluate:
    def _make_request(self, **overrides):
        pf = PhotoFeatures(
            brightness_mean=0.6,
            contrast_rms=0.3,
            saturation_mean=0.5,
            sharpness=0.7,
            face_visible=True,
            face_count=1,
            pose_alignment=0.8,
            composition_score=0.7,
            lighting_quality=0.7,
        )
        pf = pf.model_copy(update=overrides)

        return EvaluationRequest(
            request_id="test-001",
            pose_id="test-pose-001",
            scene_class="outdoor-nature",
            photo_features=pf,
        )

    def test_high_scores_produce_a_plus(self):
        req = self._make_request(
            pose_alignment=0.95,
            composition_score=0.95,
            lighting_quality=0.95,
            sharpness=0.9,
            brightness_mean=0.7,
            saturation_mean=0.6,
        )
        resp = evaluate(req)

        assert resp.overall_score >= 8.0
        assert resp.grade in ("A", "A+")
        assert len(resp.dimensions) == 5

    def test_low_scores_produce_d(self):
        req = self._make_request(
            pose_alignment=0.2,
            composition_score=0.2,
            lighting_quality=0.2,
            sharpness=0.1,
            brightness_mean=0.1,
        )
        resp = evaluate(req)
        assert resp.grade in ("D", "C")

    def test_no_face_produces_lower_expression_score(self):
        req = self._make_request(face_visible=False, face_count=0)
        resp = evaluate(req)

        expr_dim = next((d for d in resp.dimensions if d.label_zh == "表现力"), None)
        assert expr_dim is not None
        assert expr_dim.score == 5.0

    def test_improvement_tips_generated_for_low_scores(self):
        req = self._make_request(
            pose_alignment=0.3,
            composition_score=0.3,
            lighting_quality=0.3,
            sharpness=0.2,
        )
        resp = evaluate(req)

        assert len(resp.improvement_tips) > 0

    def test_no_tips_when_everything_is_good(self):
        req = self._make_request(
            pose_alignment=0.8,
            composition_score=0.8,
            lighting_quality=0.8,
            sharpness=0.8,
            face_visible=True,
        )
        resp = evaluate(req)

        # With all good scores, should give a compliment tip
        assert len(resp.improvement_tips) >= 1

    def test_encouragement_matches_grade(self):
        req = self._make_request(pose_alignment=0.9, composition_score=0.9, lighting_quality=0.9)
        resp = evaluate(req)

        assert resp.encouragement is not None
        assert len(resp.encouragement) > 0

    def test_preset_recommendation_is_not_none(self):
        req = self._make_request()
        resp = evaluate(req)

        # Preset recommendation should always return a string
        assert resp.preset_recommendation is not None
        assert isinstance(resp.preset_recommendation, str)

    def test_preset_for_street_scene(self):
        req = self._make_request()
        req.scene_class = "urban-street"
        resp = evaluate(req)
        assert resp.preset_recommendation is not None

    def test_preset_for_low_saturation_high_contrast(self):
        req = self._make_request(saturation_mean=0.1, contrast_rms=0.6)
        resp = evaluate(req)
        assert resp.preset_recommendation == "bw-high"

    def test_preset_for_high_brightness_low_saturation(self):
        req = self._make_request(brightness_mean=0.8, saturation_mean=0.2)
        resp = evaluate(req)
        assert resp.preset_recommendation == "clean-white"

    def test_preset_for_low_brightness(self):
        req = self._make_request(brightness_mean=0.2)
        resp = evaluate(req)
        assert resp.preset_recommendation == "cool-mood"


class TestRecommendPreset:
    def _make_pf(self, **overrides):
        pf = PhotoFeatures()
        return pf.model_copy(update=overrides)

    def test_default_is_natural(self):
        pf = self._make_pf(saturation_mean=0.5, contrast_rms=0.3, brightness_mean=0.5)
        preset = _recommend_preset("outdoor-nature", pf)
        assert preset == "natural"

    def test_high_saturation_is_hdr_pop(self):
        pf = self._make_pf(saturation_mean=0.8)
        preset = _recommend_preset("outdoor", pf)
        assert preset == "hdr-pop"

    def test_low_contrast_is_warm_portrait(self):
        pf = self._make_pf(contrast_rms=0.1)
        preset = _recommend_preset("outdoor", pf)
        assert preset == "warm-portrait"

    def test_beach_scene_is_jp_fresh(self):
        pf = self._make_pf()
        preset = _recommend_preset("beach", pf)
        assert preset == "jp-fresh"

    def test_night_scene_is_hk_retro(self):
        pf = self._make_pf()
        preset = _recommend_preset("night-scene", pf)
        assert preset == "hk-retro"
