"""Evaluation domain service — scores a captured photo against the recommended pose.

Phase 1: rule-based scoring using photo features.
Phase 2: will integrate Qwen-VL for aesthetic analysis.
"""

import random

from app.schemas.evaluation import (
    DimensionScore,
    EvaluationRequest,
    EvaluationResponse,
    PhotoFeatures,
)

# Seeded RNG for reproducible scoring during dev
_rng = random.Random(42)

# Friendly Chinese grade labels
_GRADES = [
    (9.0, "A+", "大师级！"),
    (8.0, "A", "非常出色！"),
    (7.0, "B", "很不错！"),
    (5.5, "C", "还能更好"),
    (0.0, "D", "继续加油"),
]


def _grade(score: float) -> tuple[str, str]:
    for threshold, letter, label in _GRADES:
        if score >= threshold:
            return letter, label
    return "D", "继续加油"


def evaluate(req: EvaluationRequest) -> EvaluationResponse:
    """Score a photo and generate improvement feedback."""
    pf = req.photo_features

    # ── Dimension scoring ──────────────────────────────────────
    dims: list[DimensionScore] = []

    # 1. Pose alignment (weight: 30%)
    pose_score = pf.pose_alignment * 10.0
    if pose_score >= 8.0:
        pose_fb = "姿势还原度很好，和参考姿势高度一致"
    elif pose_score >= 6.0:
        pose_fb = "姿势基本到位，注意手臂/腿的角度可以再微调"
    elif pose_score >= 4.0:
        pose_fb = "建议放慢速度，对比AR骨骼线逐一调整关键点"
    else:
        pose_fb = "别急！先站稳，从脚位开始对齐AR指示线"
    dims.append(
        DimensionScore(
            score=round(pose_score, 1),
            label_zh="姿势还原",
            feedback_zh=pose_fb,
        )
    )

    # 2. Composition (weight: 20%)
    comp_score = pf.composition_score * 10.0
    if comp_score >= 8.0:
        comp_fb = "构图严谨，主体位置恰到好处"
    elif comp_score >= 6.0:
        comp_fb = "构图可以优化：尝试用三分线网格调整主体位置"
    else:
        comp_fb = "建议开启构图辅助线，把人物放在三分线交点上"
    dims.append(
        DimensionScore(
            score=round(comp_score, 1),
            label_zh="构图",
            feedback_zh=comp_fb,
        )
    )

    # 3. Lighting / exposure (weight: 20%)
    light_score = pf.lighting_quality * 10.0
    if light_score >= 8.0:
        light_fb = "曝光准确，光线运用得当"
    elif light_score >= 6.0:
        light_fb = "曝光基本OK，注意高光区域有些过亮"
    elif light_score >= 4.0:
        light_fb = "建议调整曝光补偿或改变拍摄角度避开强光/暗部"
    else:
        light_fb = "光线条件不理想，试试换到顺光位置或开启HDR"
    dims.append(
        DimensionScore(
            score=round(light_score, 1),
            label_zh="光影",
            feedback_zh=light_fb,
        )
    )

    # 4. Overall image quality (weight: 15%)
    quality = (
        pf.sharpness * 3.0
        + pf.brightness_mean * 2.0
        + pf.saturation_mean * 2.0
        + (1.0 if pf.face_visible else 0.0) * 3.0
    )
    quality_score = min(10.0, quality)
    if quality_score >= 7.0:
        qual_fb = "画面清晰，色彩均衡，人物突出"
    elif quality_score >= 5.0:
        qual_fb = "画质尚可，建议持稳手机、确保对焦在人脸"
    else:
        qual_fb = "画面有些模糊或偏色，检查镜头是否干净，重新对焦"
    dims.append(
        DimensionScore(
            score=round(quality_score, 1),
            label_zh="画质",
            feedback_zh=qual_fb,
        )
    )

    # 5. Expression / mood (weight: 15%) — Phase 1 heuristic
    if pf.face_visible and pf.face_count > 0:
        expr_score = min(10.0, pf.pose_alignment * 6.0 + pf.brightness_mean * 4.0)
        if expr_score >= 7.0:
            expr_fb = "表情自然，状态很好"
        elif expr_score >= 5.0:
            expr_fb = "下次拍照时可以放松面部，试试微微侧脸或看向远方"
        else:
            expr_fb = "放松下巴，深呼吸后再拍，想象一个让你开心的画面"
    else:
        expr_score = 5.0
        expr_fb = "没检测到面部，如果是侧脸/背影/剪影则无需担心"
    dims.append(
        DimensionScore(
            score=round(expr_score, 1),
            label_zh="表现力",
            feedback_zh=expr_fb,
        )
    )

    # Overall score (weighted average)
    weights = [0.30, 0.20, 0.20, 0.15, 0.15]
    overall = sum(d.score * w for d, w in zip(dims, weights, strict=False))

    # ── Improvement tips ────────────────────────────────────────
    tips: list[str] = []
    if pf.pose_alignment < 0.6:
        tips.append("放慢摆姿势的速度，对照AR骨骼线一步一步调整")
    if pf.composition_score < 0.6:
        tips.append("打开构图辅助线（三分网格），把人放在左或右三分线上")
    if pf.lighting_quality < 0.6:
        tips.append("换个方向面对光源，让脸部光线更均匀")
    if pf.sharpness < 0.5:
        tips.append("拍照时双手持稳手机，或用三脚架/支撑物防抖")
    if not pf.face_visible:
        tips.append("确认人脸在画面内且未被遮挡（帽子/墨镜/口罩除外）")
    if not tips:
        tips.append("整体表现不错！微调一下姿势角度就能达到专业水准")

    # ── Encouragement ───────────────────────────────────────────
    letter, grade_label = _grade(overall)
    encouragements = {
        "A+": "太棒了！这张照片可以直接当样片展示了！",
        "A": "拍得非常好！风格和姿势都拿捏到位了",
        "B": "很不错，再注意一下光线和构图就更完美了",
        "C": "进步空间很大，每次调整一个维度就能看到提升",
        "D": "没关系，好照片需要练习。试试换个姿势或角度重拍",
    }

    # ── Preset recommendation ───────────────────────────────────
    preset = _recommend_preset(req.scene_class, pf)

    return EvaluationResponse(
        request_id=req.request_id,
        overall_score=round(overall, 1),
        grade=letter,
        dimensions=dims,
        improvement_tips=tips,
        encouragement=encouragements.get(letter, encouragements["B"]),
        preset_recommendation=preset,
        description=f"{grade_label} 综合评分 {overall:.1f}/10",
    )


def _recommend_preset(scene_class: str, pf: PhotoFeatures) -> str:
    """Simple rule-based preset recommendation based on photo features."""
    if pf.saturation_mean < 0.3 and pf.contrast_rms > 0.5:
        return "bw-high"
    if pf.brightness_mean > 0.7 and pf.saturation_mean < 0.4:
        return "clean-white"
    if pf.brightness_mean < 0.35:
        return "cool-mood"
    if pf.saturation_mean > 0.65:
        return "hdr-pop"
    if pf.contrast_rms < 0.3:
        return "warm-portrait"
    if "street" in scene_class or "urban" in scene_class:
        return "film-warm"
    if "beach" in scene_class:
        return "jp-fresh"
    if "night" in scene_class:
        return "hk-retro"
    return "natural"
