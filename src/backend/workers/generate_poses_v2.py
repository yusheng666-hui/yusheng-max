"""
Phase 2 Pose Database Expander — adds 200 multi-person and expression-focused poses.
Reads the existing 300-pose DB, generates 200 new poses, merges to 500.

New categories:
  - Couple poses (50): romantic, casual, coordinated
  - Friend/group poses (50): fun, synchronized, candid
  - Family poses (30): warm, gentle, inclusive
  - Expression-focused (40): laughing, serene, moody, dynamic expressions
  - Advanced solo (30): complex standing variations, artistic angles

Usage: python workers/generate_poses_v2.py
"""

import json
import math
import os
import random
from copy import deepcopy
from pathlib import Path
from typing import Optional

# ── Paths ──────────────────────────────────────────────────────────
SRC_ROOT = Path(__file__).resolve().parent.parent.parent / "flutter_app"
POSE_DB_PATH = SRC_ROOT / "assets" / "poses" / "local_pose_db.json"
OUT_PATH = SRC_ROOT / "assets" / "poses" / "local_pose_db.json"

# ── MediaPipe 33 Keypoint Names ──────────────────────────────────
KP = {
    "nose": 0, "left_eye_inner": 1, "left_eye": 2, "left_eye_outer": 3,
    "right_eye_inner": 4, "right_eye": 5, "right_eye_outer": 6,
    "left_ear": 7, "right_ear": 8, "mouth_left": 9, "mouth_right": 10,
    "left_shoulder": 11, "right_shoulder": 12,
    "left_elbow": 13, "right_elbow": 14,
    "left_wrist": 15, "right_wrist": 16,
    "left_pinky": 17, "right_pinky": 18,
    "left_index": 19, "right_index": 20,
    "left_thumb": 21, "right_thumb": 22,
    "left_hip": 23, "right_hip": 24,
    "left_knee": 25, "right_knee": 26,
    "left_ankle": 27, "right_ankle": 28,
    "left_heel": 29, "right_heel": 30,
    "left_foot_index": 31, "right_foot_index": 32,
}

SCENES = {
    "outdoor": {"label_zh": "户外自然", "color": ["green", "blue", "warm"]},
    "street": {"label_zh": "城市街拍", "color": ["gray", "warm", "neutral"]},
    "indoor": {"label_zh": "室内场景", "color": ["warm", "brown", "soft"]},
    "beach": {"label_zh": "海滩", "color": ["blue", "gold", "cyan"]},
    "night": {"label_zh": "夜景", "color": ["dark", "neon", "warm"]},
}


def kp(x: float, y: float, z: float = 0.0, v: float = 1.0) -> dict:
    return {"id": 0, "name": "", "x": round(x, 3), "y": round(y, 3), "z": round(z, 3), "visibility": v}


def make_skel(parts: dict) -> list:
    """Build a 33-keypoint skeleton from partial overrides on default standing base."""
    base = [
        kp(0.50, 0.06, 0.05), kp(0.48, 0.08, 0.03), kp(0.49, 0.08, 0.03), kp(0.47, 0.08, 0.03),
        kp(0.52, 0.08, 0.03), kp(0.53, 0.08, 0.03), kp(0.54, 0.08, 0.03),
        kp(0.44, 0.10, 0.05), kp(0.56, 0.10, 0.05), kp(0.47, 0.09, 0.03), kp(0.53, 0.09, 0.03),
        kp(0.43, 0.18, 0.08), kp(0.57, 0.18, 0.08),
        kp(0.35, 0.35, 0.12), kp(0.65, 0.35, 0.12),
        kp(0.28, 0.52, 0.15), kp(0.72, 0.52, 0.15),
        kp(0.27, 0.54, 0.15), kp(0.73, 0.54, 0.15), kp(0.29, 0.53, 0.15), kp(0.71, 0.53, 0.15),
        kp(0.27, 0.51, 0.15), kp(0.73, 0.51, 0.15),
        kp(0.46, 0.50, 0.05), kp(0.54, 0.50, 0.05),
        kp(0.45, 0.73, 0.08), kp(0.55, 0.73, 0.08),
        kp(0.44, 0.93, 0.05), kp(0.56, 0.93, 0.05),
        kp(0.44, 0.94, 0.02), kp(0.56, 0.94, 0.02),
        kp(0.44, 0.93, 0.08), kp(0.56, 0.93, 0.08),
    ]
    for idx, vals in parts.items():
        int_idx = KP.get(idx, idx) if isinstance(idx, str) else idx
        if isinstance(vals, dict):
            base[int_idx].update(vals)
    return base


# ── Phase 2: New skeleton templates (multi-person + expressive) ────

NEW_TEMPLATES = {}

# ── Couple poses ──
NEW_TEMPLATES["couple_side_by_side"] = make_skel({
    "left_shoulder": kp(0.42, 0.18, 0.08), "right_shoulder": kp(0.56, 0.18, 0.08),
    "left_elbow": kp(0.34, 0.33, 0.12), "right_elbow": kp(0.60, 0.33, 0.10),
    "left_wrist": kp(0.52, 0.48, 0.08), "right_wrist": kp(0.68, 0.48, 0.10),
    "left_hip": kp(0.44, 0.50, 0.05), "right_hip": kp(0.55, 0.50, 0.05),
})

NEW_TEMPLATES["couple_hand_hold"] = make_skel({
    "left_shoulder": kp(0.41, 0.18, 0.10), "right_shoulder": kp(0.55, 0.18, 0.08),
    "left_elbow": kp(0.33, 0.32, 0.15), "right_elbow": kp(0.62, 0.32, 0.12),
    "left_wrist": kp(0.60, 0.44, 0.10), "right_wrist": kp(0.70, 0.40, 0.15),
    "nose": kp(0.48, 0.06, 0.08),
})

NEW_TEMPLATES["couple_romantic_dip"] = make_skel({
    "nose": kp(0.50, 0.10, 0.12),
    "left_shoulder": kp(0.44, 0.20, 0.15), "right_shoulder": kp(0.56, 0.20, 0.08),
    "left_elbow": kp(0.38, 0.38, 0.18), "right_elbow": kp(0.62, 0.30, 0.15),
    "left_wrist": kp(0.42, 0.55, 0.20), "right_wrist": kp(0.66, 0.22, 0.18),
    "left_hip": kp(0.45, 0.48, 0.12), "right_hip": kp(0.55, 0.46, 0.08),
    "left_knee": kp(0.43, 0.68, 0.15), "right_knee": kp(0.56, 0.65, 0.12),
})

NEW_TEMPLATES["couple_back_to_back"] = make_skel({
    "nose": kp(0.50, 0.06, -0.05),
    "left_shoulder": kp(0.42, 0.18, 0.00), "right_shoulder": kp(0.58, 0.18, 0.00),
    "left_elbow": kp(0.36, 0.32, 0.05), "right_elbow": kp(0.64, 0.32, 0.05),
    "left_wrist": kp(0.30, 0.48, 0.08), "right_wrist": kp(0.70, 0.48, 0.08),
})

NEW_TEMPLATES["couple_walking_together"] = make_skel({
    "left_shoulder": kp(0.42, 0.18, 0.10), "right_shoulder": kp(0.57, 0.18, 0.06),
    "left_elbow": kp(0.33, 0.32, 0.15), "right_elbow": kp(0.64, 0.34, 0.10),
    "left_wrist": kp(0.56, 0.44, 0.10), "right_wrist": kp(0.72, 0.50, 0.08),
    "left_hip": kp(0.45, 0.50, 0.06), "right_hip": kp(0.55, 0.50, 0.04),
    "left_knee": kp(0.42, 0.72, 0.12), "right_knee": kp(0.58, 0.68, 0.08),
})

# ── Friend/group poses ──
NEW_TEMPLATES["friends_huddle"] = make_skel({
    "left_shoulder": kp(0.40, 0.18, 0.12), "right_shoulder": kp(0.60, 0.18, 0.12),
    "left_elbow": kp(0.30, 0.30, 0.18), "right_elbow": kp(0.70, 0.30, 0.18),
    "left_wrist": kp(0.28, 0.44, 0.20), "right_wrist": kp(0.72, 0.44, 0.20),
    "nose": kp(0.50, 0.07, 0.05),
})

NEW_TEMPLATES["friends_jump_group"] = make_skel({
    "nose": kp(0.50, 0.03, 0.05),
    "left_shoulder": kp(0.40, 0.15, 0.12), "right_shoulder": kp(0.60, 0.15, 0.12),
    "left_elbow": kp(0.28, 0.20, 0.20), "right_elbow": kp(0.72, 0.20, 0.20),
    "left_wrist": kp(0.20, 0.10, 0.22), "right_wrist": kp(0.80, 0.10, 0.22),
    "left_hip": kp(0.44, 0.44, 0.10), "right_hip": kp(0.56, 0.44, 0.10),
    "left_knee": kp(0.42, 0.58, 0.18), "right_knee": kp(0.58, 0.58, 0.18),
    "left_ankle": kp(0.38, 0.75, 0.20), "right_ankle": kp(0.62, 0.75, 0.20),
})

NEW_TEMPLATES["friends_shoulder_lean"] = make_skel({
    "nose": kp(0.52, 0.07, 0.06),
    "left_shoulder": kp(0.44, 0.18, 0.10), "right_shoulder": kp(0.58, 0.18, 0.05),
    "left_elbow": kp(0.50, 0.28, 0.15), "right_elbow": kp(0.62, 0.32, 0.10),
    "left_wrist": kp(0.56, 0.22, 0.18), "right_wrist": kp(0.56, 0.48, 0.10),
    "left_hip": kp(0.46, 0.48, 0.08), "right_hip": kp(0.54, 0.50, 0.04),
})

NEW_TEMPLATES["friends_v_sign"] = make_skel({
    "right_elbow": kp(0.58, 0.20, 0.15), "right_wrist": kp(0.56, 0.08, 0.20),
    "left_elbow": kp(0.34, 0.30, 0.12), "left_wrist": kp(0.30, 0.44, 0.15),
})

NEW_TEMPLATES["friends_toast"] = make_skel({
    "right_shoulder": kp(0.56, 0.17, 0.10),
    "right_elbow": kp(0.58, 0.28, 0.15), "right_wrist": kp(0.60, 0.22, 0.18),
    "left_elbow": kp(0.36, 0.32, 0.12), "left_wrist": kp(0.32, 0.46, 0.15),
})

# ── Family poses ──
NEW_TEMPLATES["family_group_hug"] = make_skel({
    "left_shoulder": kp(0.38, 0.18, 0.15), "right_shoulder": kp(0.62, 0.18, 0.15),
    "left_elbow": kp(0.28, 0.28, 0.20), "right_elbow": kp(0.72, 0.28, 0.20),
    "left_wrist": kp(0.32, 0.22, 0.22), "right_wrist": kp(0.68, 0.22, 0.22),
    "nose": kp(0.50, 0.07, 0.05),
    "left_hip": kp(0.42, 0.48, 0.12), "right_hip": kp(0.58, 0.48, 0.12),
})

NEW_TEMPLATES["family_kneeling_with_kids"] = make_skel({
    "nose": kp(0.50, 0.28, 0.05),
    "left_shoulder": kp(0.43, 0.40, 0.08), "right_shoulder": kp(0.57, 0.40, 0.08),
    "left_elbow": kp(0.36, 0.52, 0.12), "right_elbow": kp(0.64, 0.52, 0.12),
    "left_wrist": kp(0.38, 0.64, 0.10), "right_wrist": kp(0.62, 0.64, 0.10),
    "left_hip": kp(0.46, 0.62, 0.08), "right_hip": kp(0.54, 0.62, 0.08),
    "left_knee": kp(0.45, 0.85, 0.10), "right_knee": kp(0.55, 0.85, 0.08),
})

NEW_TEMPLATES["family_piggyback"] = make_skel({
    "nose": kp(0.50, 0.08, 0.05),
    "left_shoulder": kp(0.42, 0.18, 0.12), "right_shoulder": kp(0.58, 0.18, 0.12),
    "left_elbow": kp(0.34, 0.30, 0.18), "right_elbow": kp(0.66, 0.30, 0.18),
    "left_wrist": kp(0.38, 0.44, 0.20), "right_wrist": kp(0.62, 0.44, 0.20),
    "left_hip": kp(0.44, 0.48, 0.10), "right_hip": kp(0.56, 0.48, 0.10),
    "left_knee": kp(0.43, 0.70, 0.15), "right_knee": kp(0.57, 0.70, 0.12),
})

# ── Expression-focused poses ──
NEW_TEMPLATES["expression_laughing"] = make_skel({
    "nose": kp(0.50, 0.07, 0.05),
    "mouth_left": kp(0.46, 0.10, 0.04), "mouth_right": kp(0.54, 0.10, 0.04),
    "left_eye": kp(0.48, 0.08, 0.04), "right_eye": kp(0.53, 0.08, 0.04),
    "left_shoulder": kp(0.42, 0.19, 0.10), "right_shoulder": kp(0.58, 0.19, 0.10),
})

NEW_TEMPLATES["expression_serene"] = make_skel({
    "nose": kp(0.50, 0.06, 0.05),
    "left_eye": kp(0.49, 0.08, 0.02), "right_eye": kp(0.52, 0.08, 0.02),
    "mouth_left": kp(0.48, 0.09, 0.02), "mouth_right": kp(0.52, 0.09, 0.02),
    "left_shoulder": kp(0.44, 0.18, 0.06), "right_shoulder": kp(0.56, 0.18, 0.06),
})

NEW_TEMPLATES["expression_wind_in_hair"] = make_skel({
    "left_ear": kp(0.42, 0.10, 0.10), "right_ear": kp(0.58, 0.10, 0.10),
    "left_shoulder": kp(0.42, 0.18, 0.10),
    "right_elbow": kp(0.60, 0.28, 0.15), "right_wrist": kp(0.55, 0.15, 0.20),
})

NEW_TEMPLATES["expression_candid_smile"] = make_skel({
    "nose": kp(0.48, 0.07, 0.06),
    "mouth_left": kp(0.45, 0.10, 0.05), "mouth_right": kp(0.52, 0.10, 0.05),
    "left_eye": kp(0.47, 0.08, 0.04), "right_eye": kp(0.51, 0.08, 0.04),
    "left_elbow": kp(0.38, 0.38, 0.12),
})

NEW_TEMPLATES["expression_confident"] = make_skel({
    "nose": kp(0.50, 0.05, 0.08),
    "left_shoulder": kp(0.42, 0.17, 0.12), "right_shoulder": kp(0.58, 0.17, 0.12),
    "left_hip": kp(0.45, 0.49, 0.08), "right_hip": kp(0.55, 0.49, 0.08),
    "left_elbow": kp(0.33, 0.36, 0.15), "right_wrist": kp(0.72, 0.48, 0.10),
})

# ── Advanced solo poses ──
NEW_TEMPLATES["solo_tiptoe_reach"] = make_skel({
    "right_shoulder": kp(0.56, 0.16, 0.12),
    "right_elbow": kp(0.58, 0.10, 0.18), "right_wrist": kp(0.56, 0.02, 0.22),
    "left_ankle": kp(0.43, 0.90, 0.12), "left_heel": kp(0.43, 0.91, 0.10),
    "right_ankle": kp(0.57, 0.90, 0.12), "right_heel": kp(0.57, 0.91, 0.10),
})

NEW_TEMPLATES["solo_dramatic_turn"] = make_skel({
    "nose": kp(0.44, 0.06, 0.12),
    "left_shoulder": kp(0.38, 0.18, 0.18), "right_shoulder": kp(0.52, 0.18, 0.02),
    "left_elbow": kp(0.30, 0.30, 0.22), "right_elbow": kp(0.58, 0.32, 0.05),
    "left_wrist": kp(0.26, 0.44, 0.22), "right_wrist": kp(0.54, 0.46, 0.05),
    "left_hip": kp(0.40, 0.50, 0.15), "right_hip": kp(0.52, 0.50, 0.02),
})

NEW_TEMPLATES["solo_ballet_third"] = make_skel({
    "right_elbow": kp(0.60, 0.20, 0.20), "right_wrist": kp(0.64, 0.06, 0.25),
    "left_elbow": kp(0.34, 0.28, 0.18), "left_wrist": kp(0.30, 0.40, 0.20),
    "right_knee": kp(0.52, 0.68, 0.15), "right_ankle": kp(0.50, 0.85, 0.18),
    "right_foot_index": kp(0.48, 0.88, 0.20),
})

NEW_TEMPLATES["solo_low_angle_power"] = make_skel({
    "nose": kp(0.50, 0.04, 0.10),
    "left_shoulder": kp(0.41, 0.16, 0.15), "right_shoulder": kp(0.59, 0.16, 0.15),
    "left_hip": kp(0.44, 0.48, 0.10), "right_hip": kp(0.56, 0.48, 0.10),
    "left_knee": kp(0.43, 0.72, 0.12), "right_knee": kp(0.57, 0.72, 0.12),
    "left_ankle": kp(0.40, 0.92, 0.08), "right_ankle": kp(0.60, 0.92, 0.08),
})

# ── Expression tag options ─────────────────────────────────────────
EXPRESSIONS = {
    "natural": ["自然", "放松", "不刻意"],
    "laughing": ["大笑", "露齿笑", "开心"],
    "soft_smile": ["微笑", "温柔", "不露齿"],
    "confident": ["自信", "坚定", "有力量"],
    "serene": ["宁静", "温柔", "情绪感"],
    "candid": ["抓拍感", "生活化", "不经意"],
    "moody": ["氛围感", "情绪", "深邃"],
    "romantic": ["甜蜜", "温柔", "爱意"],
    "cool": ["酷", "不笑", "高冷"],
    "playful": ["活泼", "俏皮", "开心"],
}

# ── New pose recipes ───────────────────────────────────────────────
# Format: (pose_id, body_position, sub_position, template, styles, difficulty, expressions, category)

NEW_RECIPES = []

def r(pid, bp, sp, tmpl, styles, diff, expr, cat, scene_hint="outdoor"):
    NEW_RECIPES.append((pid, bp, sp, tmpl, styles, diff, expr, cat, scene_hint))

# ── Couple poses (50) ──────────────────────────────────────────────
COUPLE_STYLES = {
    "outdoor": ["fresh", "sweet", "natural"],
    "street": ["cool", "elegant", "casual"],
    "indoor": ["sweet", "elegant", "natural"],
    "beach": ["fresh", "sweet", "natural"],
    "night": ["cool", "elegant"],
}

for scene, (label_cn, colors) in SCENES.items():
    for i in range(10):
        styles = COUPLE_STYLES[scene]
        tmpl_name = ["couple_side_by_side", "couple_hand_hold", "couple_romantic_dip",
                      "couple_back_to_back", "couple_walking_together"][i % 5]
        sp = ["并肩而立", "牵手同行", "浪漫后仰", "背靠背", "一起走"][i % 5]
        expr = ["soft_smile", "romantic", "natural", "laughing", "romantic"][i % 5]
        diff = "beginner" if i < 5 else "intermediate"
        pid = f"couple-{scene}-{i+1:03d}"
        r(pid, "standing", f"couple-{sp}", tmpl_name, styles[:2], diff, expr, "couple", scene)

# ── Friend/group poses (50) ────────────────────────────────────────
FRIEND_STYLES = {
    "outdoor": ["fresh", "casual", "natural"],
    "street": ["cool", "casual", "elegant"],
    "indoor": ["casual", "sweet", "fresh"],
    "beach": ["fresh", "casual", "sweet"],
    "night": ["cool", "casual"],
}

for scene in SCENES:
    for i in range(10):
        styles = FRIEND_STYLES[scene]
        tmpl_name = ["friends_huddle", "friends_jump_group", "friends_shoulder_lean",
                      "friends_v_sign", "friends_toast"][i % 5]
        sp = ["围拢合影", "一起跳", "靠肩", "比耶", "举杯"][i % 5]
        expr = ["laughing", "playful", "natural", "candid", "laughing"][i % 5]
        diff = "beginner" if i < 7 else "intermediate"
        pid = f"friends-{scene}-{i+1:03d}"
        r(pid, "standing", f"friends-{sp}", tmpl_name, styles[:2], diff, expr, "friends", scene)

# ── Family poses (30) ──────────────────────────────────────────────
FAMILY_SCENES = ["outdoor", "indoor", "beach"]
for scene in FAMILY_SCENES:
    for i in range(10):
        styles = ["natural", "fresh", "sweet"]
        tmpl_name = ["family_group_hug", "family_kneeling_with_kids", "family_piggyback",
                      "family_group_hug", "family_kneeling_with_kids"][i % 5]
        sp_list = ["温馨拥抱", "蹲下陪娃", "背娃", "全家福", "亲子互动"]
        sp = sp_list[i % 5]
        expr = ["soft_smile", "laughing", "natural", "soft_smile", "playful"][i % 5]
        diff = "beginner"
        pid = f"family-{scene}-{i+1:03d}"
        r(pid, "standing" if i % 2 == 0 else "kneeling", f"family-{sp}", tmpl_name,
          styles[:2], diff, expr, "family", scene)

# ── Expression-focused poses (40) ──────────────────────────────────
EXPR_SCENES = ["outdoor", "street", "indoor", "beach", "night"]
EXPR_TYPES = ["laughing", "serene", "candid", "confident", "moody", "cool", "soft_smile", "playful"]

for scene in EXPR_SCENES:
    for i in range(8):
        expr = EXPR_TYPES[i]
        tmpl_map = {
            "laughing": "expression_laughing", "serene": "expression_serene",
            "candid": "expression_candid_smile", "confident": "expression_confident",
            "moody": "expression_serene", "cool": "expression_confident",
            "soft_smile": "expression_serene", "playful": "expression_laughing",
        }
        style_map = {
            "laughing": ["fresh", "natural"], "serene": ["elegant", "natural"],
            "candid": ["casual", "natural"], "confident": ["cool", "elegant"],
            "moody": ["cool", "elegant"], "cool": ["cool"],
            "soft_smile": ["sweet", "fresh"], "playful": ["fresh", "casual"],
        }
        pid = f"expr-{scene}-{i+1:03d}"
        r(pid, "standing", f"expression-{EXPRESSIONS[expr][0]}", tmpl_map[expr],
          style_map[expr], "beginner", expr, "expression", scene)

# ── Advanced solo poses (30) ───────────────────────────────────────
ADV_TEMPLATES = [
    "solo_tiptoe_reach", "solo_dramatic_turn", "solo_ballet_third",
    "solo_low_angle_power", "solo_tiptoe_reach"
]
ADV_STYLES = [
    ["elegant"], ["cool", "elegant"], ["elegant", "fresh"],
    ["cool"], ["elegant", "natural"]
]
ADV_SP = ["踮脚伸展", "戏剧转身", "舞姿三位手", "低角度气场", "动态延展"]
ADV_EXPR = ["confident", "moody", "serene", "confident", "natural"]

for scene in EXPR_SCENES:
    for i in range(6):
        idx = i % 5
        diff = "intermediate"
        pid = f"advanced-{scene}-{i+1:03d}"
        r(pid, "standing", f"advanced-{ADV_SP[idx]}", ADV_TEMPLATES[idx],
          ADV_STYLES[idx], diff, ADV_EXPR[idx], "advanced_solo", scene)


# ── Guidance and camera params generators ──────────────────────────

def make_guidance(pose_id, body_position, sub_position, scene_key, style, category):
    """Generate Chinese guidance text."""
    scene_label = SCENES.get(scene_key, {}).get("label_zh", "户外")

    tips_map = {
        "couple": {
            "beginner_tip": "和伙伴保持半步距离，自然靠近",
            "general_tip": f"在{scene_label}场景下，注意两人间距和互动感",
            "pose_tip": "重心稳定，保持自然的身体接触",
            "photographer_tips": {
                "zh": "注意两人间距，保持画面平衡。可用人像模式虚化背景突出主体",
            },
        },
        "friends": {
            "beginner_tip": "放松身体，随意互动",
            "general_tip": f"在{scene_label}场景下，抓拍自然互动瞬间",
            "pose_tip": "动作可以夸张一点，拍出来更有感染力",
            "photographer_tips": {
                "zh": "多拍几张抓拍，选择最自然的一张。光线好时可用高速连拍",
            },
        },
        "family": {
            "beginner_tip": "保持微笑，靠近家人",
            "general_tip": f"在{scene_label}场景下，温馨的家庭时刻",
            "pose_tip": "身体微微前倾，表现亲密感",
            "photographer_tips": {
                "zh": "注意所有人都在画面内，用中等光圈确保每个人脸部清晰",
            },
        },
        "expression": {
            "beginner_tip": "放松面部肌肉，深呼吸后自然流露表情",
            "general_tip": f"在{scene_label}场景下，表情要和场景氛围匹配",
            "pose_tip": "不要刻意摆表情，想一个开心的回忆",
            "photographer_tips": {
                "zh": "关注眼神和嘴角自然弧度。抓拍比摆拍更有感染力",
            },
        },
        "advanced_solo": {
            "beginner_tip": "先站直，感受身体重心",
            "general_tip": f"在{scene_label}场景下，利用空间感和线条感",
            "pose_tip": "核心收紧，延伸四肢线条",
            "photographer_tips": {
                "zh": "低角度拍摄可拉长身型。注意背景引导线汇聚到人物",
            },
        },
    }

    tips = tips_map.get(category, {
        "beginner_tip": "先站直，脚与肩同宽",
        "general_tip": f"在{scene_label}拍照",
        "pose_tip": "重心稳定，自然放松",
        "photographer_tips": {"zh": "注意光线方向和背景简洁度"},
    })

    voice_steps = {
        "couple": ["靠近你的拍照伙伴，保持半步距离", "自然地把手放在对方肩上或身旁", "微笑看向镜头", "保持2秒"],
        "friends": ["和朋友们聚在一起", "身体放松，不要紧绷", "一起微笑", "保持自然状态"],
        "family": ["家人们聚在一起", "弯下腰或蹲下和小朋友平视", "大家一起微笑"],
        "expression": ["深呼吸，放松肩膀", "想一个开心的瞬间", "自然地流露表情"],
        "advanced_solo": ["站稳，找到重心", "收紧核心，延伸肢体", "微调角度，找到最佳线条"],
    }

    # Determine if beginner
    cat_voice = voice_steps.get(category, ["站稳，脚与肩同宽", "双手自然垂放或插口袋", "微抬下巴，眼睛看镜头", "保持姿势2秒"])

    return {
        "beginner_tip": tips["beginner_tip"],
        "general_tip": tips["general_tip"],
        "pose_tip": tips["pose_tip"],
        "photographer_tips": tips["photographer_tips"],
        "voice_guidance": cat_voice,
    }


def make_camera_params(pose_id, body_position, sub_position, category):
    """Generate camera parameter recommendations."""
    # Base on scene extracted from pose_id
    parts = pose_id.split("-")
    scene_hint = parts[1] if len(parts) > 1 else "outdoor"

    # Determine difficulty from pose_id prefix pattern
    is_dynamic = any(kw in sub_position for kw in ["跳", "turn", "动态", "走"])
    is_low_light = scene_hint == "night"
    is_couple = category == "couple"
    is_group = category in ("friends", "family")

    if is_low_light:
        iso = 800
        shutter = "1/60s"
        aperture = "f/1.8"
    elif is_dynamic:
        iso = 400
        shutter = "1/500s"
        aperture = "f/2.8"
    elif scene_hint == "beach":
        iso = 100
        shutter = "1/500s"
        aperture = "f/4.0"
    elif scene_hint == "indoor":
        iso = 400
        shutter = "1/125s"
        aperture = "f/2.8"
    else:
        iso = 200
        shutter = "1/250s"
        aperture = "f/2.8"

    # Group photos need smaller aperture (larger f-number) for depth of field
    if is_group:
        aperture = "f/5.6"

    # Couple photos: portrait mode
    beginner_mode = "portrait" if is_couple else "auto"

    return {
        "beginner": {
            "mode": beginner_mode,
            "hdr": "on" if is_low_light else "auto",
            "flash": "off" if not is_low_light else "auto",
        },
        "advanced": {
            "iso": iso,
            "shutter_speed": shutter,
            "aperture": aperture,
            "ev_compensation": -0.3 if is_low_light else 0.0,
            "white_balance": 3200 if is_low_light else 5500,
            "metering_mode": "matrix" if is_group else "spot",
            "metering_target": "face",
            "focus_mode": "af-c" if is_dynamic else "af-s",
            "focus_point": "eye",
            "raw": False,
            "burst": is_dynamic,
        },
        "rationale": f"{'夜景' if is_low_light else '户外'}{'动态' if is_dynamic else ''}拍摄: "
                     f"ISO {iso} 平衡画质与快门, {shutter}{'冻结动作' if is_dynamic else '保证稳定'}"
    }


# ── Main generation ────────────────────────────────────────────────

def _make_pose_entry(pose_id, bp, sp, tmpl, styles, diff, expr, cat, scene_hint):
    """Create a single pose entry in the DB format."""
    skel_data = NEW_TEMPLATES.get(tmpl)
    if skel_data is None:
        # Fallback to simple standing
        skel_data = make_skel({})

    # Build keypoint list with names
    keypoint_names = list(KP.keys())
    kp_list = []
    for i in range(33):
        entry = dict(skel_data[i])
        entry["id"] = i
        entry["name"] = keypoint_names[i]
        kp_list.append(entry)

    expr_tags = EXPRESSIONS.get(expr, ["自然"])
    style_list = styles if isinstance(styles, list) else [styles]

    guidance = make_guidance(pose_id, bp, sp, scene_hint, style_list[0], cat)
    cam_params = make_camera_params(pose_id, bp, sp, cat)

    quality = round(3.5 + random.random() * 2.5, 1)  # 3.5-6.0 range (varied quality)
    if cat in ("advanced_solo",):
        quality += 1.0  # advanced poses get higher base quality

    scene_label = SCENES.get(scene_hint, {}).get("label_zh", "户外自然")

    display_sp = sp.split("-", 1)[1] if "-" in sp and sp.split("-", 1)[0] in ("couple", "friends", "family", "expression", "advanced") else sp
    return {
        "pose_id": pose_id,
        "name": {
            "zh": f"{scene_label}·{display_sp}",
            "en": f"{scene_hint}-{display_sp.replace(' ', '-')}"[:40],
        },
        "description": {
            "zh": f"{guidance['general_tip']}。{guidance['pose_tip']}",
            "en": f"{sp} pose for {scene_hint} scene",
        },
        "taxonomy": {
            "scene_type": [scene_hint],
            "body_position": bp,
            "sub_position": sp,
            "style": style_list,
            "difficulty": diff,
            "expression": expr_tags,
            "category": cat,
            "person_count": {
                "couple": 2, "friends": "2-5", "family": "2-6",
                "expression": 1, "advanced_solo": 1,
            }.get(cat, 1),
        },
        "skeleton_3d": {
            "keypoints": kp_list,
            "anchor_point": "mid_hip",
        },
        "guidance": guidance,
        "camera_params": cam_params,
        "metadata": {
            "quality_score": min(quality, 10.0),
            "source": "generated_v2",
            "generated_at": "2026-05-25",
            "tags": [cat, scene_hint, diff] + style_list[:2],
        },
    }


def main():
    print("Loading existing 300-pose DB...")
    existing = json.loads(POSE_DB_PATH.read_text(encoding="utf-8"))
    existing_poses = existing.get("poses", [])
    print(f"  Found {len(existing_poses)} existing poses")

    print(f"Generating {len(NEW_RECIPES)} new poses...")
    new_poses = []
    for recipe in NEW_RECIPES:
        pid, bp, sp, tmpl, styles, diff, expr, cat, scene = recipe
        pose = _make_pose_entry(pid, bp, sp, tmpl, styles, diff, expr, cat, scene)
        new_poses.append(pose)

    print(f"  Generated {len(new_poses)} poses")
    print(f"    Couple: {sum(1 for p in new_poses if p['taxonomy']['category'] == 'couple')}")
    print(f"    Friends: {sum(1 for p in new_poses if p['taxonomy']['category'] == 'friends')}")
    print(f"    Family: {sum(1 for p in new_poses if p['taxonomy']['category'] == 'family')}")
    print(f"    Expression: {sum(1 for p in new_poses if p['taxonomy']['category'] == 'expression')}")
    print(f"    Advanced: {sum(1 for p in new_poses if p['taxonomy']['category'] == 'advanced_solo')}")

    # Merge
    all_poses = existing_poses + new_poses
    output = {
        "version": 2,
        "generated_at": "2026-05-25T00:00:00Z",
        "total_poses": len(all_poses),
        "keypoint_format": "mediapipe_33",
        "poses": all_poses,
    }

    # Backup original
    backup_path = POSE_DB_PATH.with_suffix(".json.bak")
    if not backup_path.exists():
        import shutil
        shutil.copy2(POSE_DB_PATH, backup_path)
        print(f"\nBacked up original to {backup_path}")

    OUT_PATH.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    size_kb = OUT_PATH.stat().st_size / 1024
    print(f"\nWritten {len(all_poses)} poses ({size_kb:.0f} KB) → {OUT_PATH}")


if __name__ == "__main__":
    main()
