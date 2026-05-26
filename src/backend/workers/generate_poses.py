"""
Phase 1 Pose Database Generator — Expanded Edition
Generates 300 poses across 5 scenes with full skeleton data, guidance, and camera params.
Output: src/flutter_app/assets/poses/local_pose_db.json

Usage: python workers/generate_poses.py
"""

import json
import math
import os
from copy import deepcopy
from typing import Optional

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


def kp(x: float, y: float, z: float = 0.0, v: float = 1.0) -> dict:
    """Create a keypoint dict."""
    return {"id": 0, "name": "", "x": round(x, 3), "y": round(y, 3), "z": round(z, 3), "visibility": v}


def _make_skel(parts: dict) -> list:
    """Build a 33-keypoint skeleton from partial overrides on a default standing base."""
    base = [
        kp(0.50, 0.06, 0.05, v=1.0),   # 0 nose
        kp(0.48, 0.08, 0.03), kp(0.49, 0.08, 0.03), kp(0.47, 0.08, 0.03),  # 1-3 left eye
        kp(0.52, 0.08, 0.03), kp(0.53, 0.08, 0.03), kp(0.54, 0.08, 0.03),  # 4-6 right eye
        kp(0.44, 0.10, 0.05), kp(0.56, 0.10, 0.05),  # 7-8 ears
        kp(0.47, 0.09, 0.03), kp(0.53, 0.09, 0.03),  # 9-10 mouth
        kp(0.43, 0.18, 0.08), kp(0.57, 0.18, 0.08),  # 11-12 shoulders
        kp(0.35, 0.35, 0.12), kp(0.65, 0.35, 0.12),  # 13-14 elbows
        kp(0.28, 0.52, 0.15), kp(0.72, 0.52, 0.15),  # 15-16 wrists
        kp(0.27, 0.54, 0.15), kp(0.73, 0.54, 0.15),  # 17-18 pinkies
        kp(0.29, 0.53, 0.15), kp(0.71, 0.53, 0.15),  # 19-20 index fingers
        kp(0.27, 0.51, 0.15), kp(0.73, 0.51, 0.15),  # 21-22 thumbs
        kp(0.46, 0.50, 0.05), kp(0.54, 0.50, 0.05),  # 23-24 hips
        kp(0.45, 0.73, 0.08), kp(0.55, 0.73, 0.08),  # 25-26 knees
        kp(0.44, 0.93, 0.05), kp(0.56, 0.93, 0.05),  # 27-28 ankles
        kp(0.44, 0.94, 0.02), kp(0.56, 0.94, 0.02),  # 29-30 heels
        kp(0.44, 0.93, 0.08), kp(0.56, 0.93, 0.08),  # 31-32 foot index
    ]
    for idx, vals in parts.items():
        int_idx = KP.get(idx, idx) if isinstance(idx, str) else idx
        if isinstance(vals, dict):
            base[int_idx].update(vals)
    return base


def skeleton_from_template(name: str, **overrides) -> list:
    """Build a full 33-keypoint skeleton from a named template with optional overrides."""
    templates = {}

    # ── STANDING: facing camera, weight even, arms at sides ──
    templates["standing"] = _make_skel({})

    # ── CROSS-LEG STANDING ──
    templates["standing_cross_leg"] = _make_skel({
        "left_knee": kp(0.44, 0.72, 0.12), "right_knee": kp(0.56, 0.70, 0.05),
        "left_ankle": kp(0.46, 0.91, 0.08), "right_ankle": kp(0.52, 0.93, 0.05),
        "left_heel": kp(0.46, 0.92, 0.05), "right_heel": kp(0.52, 0.94, 0.02),
        "left_hip": kp(0.45, 0.50, 0.08), "right_hip": kp(0.55, 0.50, 0.03),
    })

    # ── PROFILE STAND / LOOKBACK ──
    templates["standing_profile"] = _make_skel({
        "nose": kp(0.42, 0.06, 0.10),
        "left_shoulder": kp(0.38, 0.18, 0.15), "right_shoulder": kp(0.52, 0.18, 0.00),
        "left_elbow": kp(0.32, 0.35, 0.18), "right_elbow": kp(0.58, 0.35, 0.05),
        "left_wrist": kp(0.30, 0.50, 0.20), "right_wrist": kp(0.55, 0.48, 0.05),
        "left_hip": kp(0.42, 0.50, 0.12), "right_hip": kp(0.52, 0.50, 0.02),
        "left_knee": kp(0.41, 0.73, 0.14), "right_knee": kp(0.54, 0.73, 0.04),
        "left_ankle": kp(0.40, 0.93, 0.08), "right_ankle": kp(0.55, 0.93, 0.02),
    })

    # ── ONE LEG BENT ──
    templates["standing_one_leg_bent"] = _make_skel({
        "left_knee": kp(0.44, 0.71, 0.12), "left_ankle": kp(0.41, 0.85, 0.15),
        "left_heel": kp(0.41, 0.86, 0.12), "left_foot_index": kp(0.41, 0.85, 0.18),
    })

    # ── WALL LEAN ──
    templates["standing_wall_lean"] = _make_skel({
        "left_shoulder": kp(0.44, 0.20, 0.02), "right_shoulder": kp(0.56, 0.20, 0.02),
        "left_elbow": kp(0.38, 0.32, 0.08), "right_elbow": kp(0.62, 0.32, 0.08),
        "left_wrist": kp(0.40, 0.45, 0.12), "right_wrist": kp(0.60, 0.45, 0.12),
        "left_hip": kp(0.45, 0.52, 0.01), "right_hip": kp(0.55, 0.52, 0.01),
        "left_knee": kp(0.42, 0.68, 0.10), "right_knee": kp(0.58, 0.73, 0.05),
        "left_ankle": kp(0.40, 0.85, 0.12), "right_ankle": kp(0.60, 0.93, 0.05),
    })

    # ── HAND ON HIP (single arm bent, weight on one leg) ──
    templates["standing_hand_hip"] = _make_skel({
        "left_elbow": kp(0.32, 0.38, 0.18), "left_wrist": kp(0.40, 0.46, 0.15),
        "right_elbow": kp(0.66, 0.35, 0.10),
        "left_hip": kp(0.44, 0.50, 0.08), "right_hip": kp(0.56, 0.50, 0.03),
        "left_knee": kp(0.44, 0.71, 0.12), "left_ankle": kp(0.41, 0.85, 0.15),
    })

    # ── ARMS CROSSED ──
    templates["standing_arms_crossed"] = _make_skel({
        "left_elbow": kp(0.42, 0.33, 0.10), "right_elbow": kp(0.58, 0.33, 0.10),
        "left_wrist": kp(0.54, 0.40, 0.15), "right_wrist": kp(0.46, 0.38, 0.15),
    })

    # ── ONE ARM REACHING UP ──
    templates["standing_arm_up"] = _make_skel({
        "right_elbow": kp(0.58, 0.20, 0.15), "right_wrist": kp(0.56, 0.06, 0.20),
        "right_shoulder": kp(0.56, 0.17, 0.10),
    })

    # ── OVER-THE-SHOULDER LOOK ──
    templates["standing_over_shoulder"] = _make_skel({
        "nose": kp(0.44, 0.06, 0.12),
        "left_shoulder": kp(0.40, 0.18, 0.15), "right_shoulder": kp(0.54, 0.18, 0.02),
        "left_elbow": kp(0.33, 0.36, 0.18), "right_elbow": kp(0.60, 0.35, 0.06),
        "left_wrist": kp(0.30, 0.52, 0.20), "right_wrist": kp(0.56, 0.50, 0.05),
        "left_hip": kp(0.43, 0.50, 0.12), "right_hip": kp(0.53, 0.50, 0.03),
        "left_knee": kp(0.42, 0.73, 0.14), "right_knee": kp(0.55, 0.73, 0.04),
        "left_ankle": kp(0.41, 0.93, 0.08), "right_ankle": kp(0.56, 0.93, 0.02),
    })

    # ── LOOKING DOWN / CONTEMPLATIVE ──
    templates["standing_look_down"] = _make_skel({
        "nose": kp(0.50, 0.08, 0.08),
        "left_eye": kp(0.49, 0.10, 0.06), "right_eye": kp(0.53, 0.10, 0.06),
        "left_ear": kp(0.44, 0.12, 0.05), "right_ear": kp(0.56, 0.12, 0.05),
    })

    # ── BOTH HANDS IN HAIR ──
    templates["standing_hands_hair"] = _make_skel({
        "left_elbow": kp(0.38, 0.22, 0.18), "left_wrist": kp(0.44, 0.10, 0.20),
        "right_elbow": kp(0.62, 0.22, 0.18), "right_wrist": kp(0.56, 0.10, 0.20),
    })

    # ── SITTING FRONT ──
    templates["sitting"] = _make_skel({
        "nose": kp(0.50, 0.12, 0.05),
        "left_eye_inner": kp(0.48, 0.14, 0.03), "left_eye": kp(0.49, 0.14, 0.03), "left_eye_outer": kp(0.47, 0.14, 0.03),
        "right_eye_inner": kp(0.52, 0.14, 0.03), "right_eye": kp(0.53, 0.14, 0.03), "right_eye_outer": kp(0.54, 0.14, 0.03),
        "left_ear": kp(0.44, 0.16, 0.05), "right_ear": kp(0.56, 0.16, 0.05),
        "mouth_left": kp(0.47, 0.15, 0.03), "mouth_right": kp(0.53, 0.15, 0.03),
        "left_shoulder": kp(0.43, 0.24, 0.08), "right_shoulder": kp(0.57, 0.24, 0.08),
        "left_elbow": kp(0.36, 0.40, 0.12), "right_elbow": kp(0.64, 0.40, 0.12),
        "left_wrist": kp(0.30, 0.56, 0.15), "right_wrist": kp(0.70, 0.56, 0.15),
        "left_pinky": kp(0.29, 0.58, 0.15), "right_pinky": kp(0.71, 0.58, 0.15),
        "left_index": kp(0.31, 0.57, 0.15), "right_index": kp(0.69, 0.57, 0.15),
        "left_thumb": kp(0.29, 0.55, 0.15), "right_thumb": kp(0.71, 0.55, 0.15),
        "left_hip": kp(0.46, 0.55, 0.08), "right_hip": kp(0.54, 0.55, 0.08),
        "left_knee": kp(0.44, 0.72, 0.18), "right_knee": kp(0.56, 0.72, 0.18),
        "left_ankle": kp(0.42, 0.90, 0.10), "right_ankle": kp(0.58, 0.90, 0.10),
        "left_heel": kp(0.42, 0.91, 0.07), "right_heel": kp(0.58, 0.91, 0.07),
        "left_foot_index": kp(0.42, 0.90, 0.13), "right_foot_index": kp(0.58, 0.90, 0.13),
    })

    # ── SITTING CROSS-LEG ──
    templates["sitting_cross_leg"] = _make_skel({
        "nose": kp(0.50, 0.12, 0.05),
        "left_eye_inner": kp(0.48, 0.14, 0.03), "left_eye": kp(0.49, 0.14, 0.03), "left_eye_outer": kp(0.47, 0.14, 0.03),
        "right_eye_inner": kp(0.52, 0.14, 0.03), "right_eye": kp(0.53, 0.14, 0.03), "right_eye_outer": kp(0.54, 0.14, 0.03),
        "left_ear": kp(0.44, 0.16, 0.05), "right_ear": kp(0.56, 0.16, 0.05),
        "mouth_left": kp(0.47, 0.15, 0.03), "mouth_right": kp(0.53, 0.15, 0.03),
        "left_shoulder": kp(0.43, 0.24, 0.08), "right_shoulder": kp(0.57, 0.24, 0.08),
        "left_elbow": kp(0.36, 0.40, 0.12), "right_elbow": kp(0.64, 0.40, 0.12),
        "left_wrist": kp(0.30, 0.56, 0.15), "right_wrist": kp(0.70, 0.56, 0.15),
        "left_pinky": kp(0.29, 0.58, 0.15), "right_pinky": kp(0.71, 0.58, 0.15),
        "left_index": kp(0.31, 0.57, 0.15), "right_index": kp(0.69, 0.57, 0.15),
        "left_thumb": kp(0.29, 0.55, 0.15), "right_thumb": kp(0.71, 0.55, 0.15),
        "left_hip": kp(0.46, 0.55, 0.08), "right_hip": kp(0.54, 0.55, 0.08),
        "left_knee": kp(0.41, 0.76, 0.20), "right_knee": kp(0.59, 0.74, 0.15),
        "left_ankle": kp(0.55, 0.88, 0.12), "right_ankle": kp(0.45, 0.86, 0.18),
        "left_heel": kp(0.55, 0.89, 0.09), "right_heel": kp(0.45, 0.87, 0.15),
        "left_foot_index": kp(0.55, 0.88, 0.15), "right_foot_index": kp(0.45, 0.86, 0.21),
    })

    # ── SITTING KNEE HUG ──
    templates["sitting_knee_hug"] = _make_skel({
        "nose": kp(0.50, 0.12, 0.05),
        "left_eye_inner": kp(0.48, 0.14, 0.03), "left_eye": kp(0.49, 0.14, 0.03), "left_eye_outer": kp(0.47, 0.14, 0.03),
        "right_eye_inner": kp(0.52, 0.14, 0.03), "right_eye": kp(0.53, 0.14, 0.03), "right_eye_outer": kp(0.54, 0.14, 0.03),
        "left_ear": kp(0.44, 0.16, 0.05), "right_ear": kp(0.56, 0.16, 0.05),
        "mouth_left": kp(0.47, 0.15, 0.03), "mouth_right": kp(0.53, 0.15, 0.03),
        "left_shoulder": kp(0.43, 0.24, 0.08), "right_shoulder": kp(0.57, 0.24, 0.08),
        "left_elbow": kp(0.42, 0.50, 0.15), "right_elbow": kp(0.58, 0.50, 0.15),
        "left_wrist": kp(0.48, 0.55, 0.12), "right_wrist": kp(0.52, 0.55, 0.12),
        "left_pinky": kp(0.47, 0.57, 0.12), "right_pinky": kp(0.53, 0.57, 0.12),
        "left_index": kp(0.49, 0.56, 0.12), "right_index": kp(0.51, 0.56, 0.12),
        "left_thumb": kp(0.47, 0.54, 0.12), "right_thumb": kp(0.53, 0.54, 0.12),
        "left_hip": kp(0.46, 0.55, 0.08), "right_hip": kp(0.54, 0.55, 0.08),
        "left_knee": kp(0.42, 0.58, 0.20), "right_knee": kp(0.58, 0.58, 0.20),
        "left_ankle": kp(0.44, 0.72, 0.18), "right_ankle": kp(0.56, 0.72, 0.18),
        "left_heel": kp(0.44, 0.73, 0.15), "right_heel": kp(0.56, 0.73, 0.15),
        "left_foot_index": kp(0.44, 0.72, 0.21), "right_foot_index": kp(0.56, 0.72, 0.21),
    })

    # ── SITTING SIDE PROFILE ──
    templates["sitting_side"] = _make_skel({
        "nose": kp(0.42, 0.12, 0.10),
        "left_eye_inner": kp(0.40, 0.14, 0.08), "left_eye": kp(0.41, 0.14, 0.08), "left_eye_outer": kp(0.39, 0.14, 0.08),
        "right_eye_inner": kp(0.44, 0.14, 0.08), "right_eye": kp(0.45, 0.14, 0.08), "right_eye_outer": kp(0.46, 0.14, 0.08),
        "left_ear": kp(0.36, 0.16, 0.10), "right_ear": kp(0.48, 0.16, 0.05),
        "mouth_left": kp(0.39, 0.15, 0.08), "mouth_right": kp(0.45, 0.15, 0.05),
        "left_shoulder": kp(0.35, 0.24, 0.12), "right_shoulder": kp(0.49, 0.24, 0.04),
        "left_elbow": kp(0.30, 0.42, 0.18), "right_elbow": kp(0.56, 0.42, 0.08),
        "left_wrist": kp(0.32, 0.58, 0.15), "right_wrist": kp(0.54, 0.56, 0.10),
        "left_hip": kp(0.38, 0.55, 0.12), "right_hip": kp(0.50, 0.55, 0.04),
        "left_knee": kp(0.36, 0.72, 0.18), "right_knee": kp(0.52, 0.72, 0.10),
        "left_ankle": kp(0.34, 0.90, 0.15), "right_ankle": kp(0.54, 0.90, 0.06),
        "left_heel": kp(0.34, 0.91, 0.12), "right_heel": kp(0.54, 0.91, 0.03),
        "left_foot_index": kp(0.34, 0.90, 0.18), "right_foot_index": kp(0.54, 0.90, 0.09),
    })

    # ── SITTING LEAN BACK (hands supporting behind) ──
    templates["sitting_lean_back"] = _make_skel({
        "nose": kp(0.50, 0.10, 0.08),
        "left_shoulder": kp(0.42, 0.22, 0.12), "right_shoulder": kp(0.58, 0.22, 0.12),
        "left_elbow": kp(0.36, 0.38, 0.18), "right_elbow": kp(0.64, 0.38, 0.18),
        "left_wrist": kp(0.32, 0.52, 0.20), "right_wrist": kp(0.68, 0.52, 0.20),
        "left_hip": kp(0.46, 0.55, 0.10), "right_hip": kp(0.54, 0.55, 0.10),
        "left_knee": kp(0.44, 0.70, 0.20), "right_knee": kp(0.56, 0.70, 0.20),
        "left_ankle": kp(0.42, 0.88, 0.15), "right_ankle": kp(0.58, 0.88, 0.15),
    })

    # ── SITTING LEGS EXTENDED ──
    templates["sitting_legs_out"] = _make_skel({
        "nose": kp(0.50, 0.12, 0.05),
        "left_shoulder": kp(0.43, 0.24, 0.10), "right_shoulder": kp(0.57, 0.24, 0.08),
        "left_elbow": kp(0.34, 0.40, 0.15), "right_elbow": kp(0.66, 0.40, 0.12),
        "left_wrist": kp(0.30, 0.54, 0.18), "right_wrist": kp(0.70, 0.54, 0.15),
        "left_hip": kp(0.46, 0.55, 0.08), "right_hip": kp(0.54, 0.55, 0.06),
        "left_knee": kp(0.44, 0.78, 0.15), "right_knee": kp(0.56, 0.78, 0.12),
        "left_ankle": kp(0.40, 0.92, 0.18), "right_ankle": kp(0.60, 0.92, 0.15),
        "left_heel": kp(0.40, 0.93, 0.15), "right_heel": kp(0.60, 0.93, 0.12),
        "left_foot_index": kp(0.40, 0.92, 0.21), "right_foot_index": kp(0.60, 0.92, 0.18),
    })

    # ── SQUATTING ──
    templates["squatting"] = _make_skel({
        "nose": kp(0.50, 0.25, 0.05),
        "left_eye": kp(0.49, 0.27, 0.03), "right_eye": kp(0.53, 0.27, 0.03),
        "left_shoulder": kp(0.43, 0.38, 0.08), "right_shoulder": kp(0.57, 0.38, 0.08),
        "left_elbow": kp(0.40, 0.55, 0.15), "right_elbow": kp(0.60, 0.55, 0.15),
        "left_wrist": kp(0.42, 0.60, 0.15), "right_wrist": kp(0.58, 0.60, 0.15),
        "left_hip": kp(0.45, 0.62, 0.10), "right_hip": kp(0.55, 0.62, 0.10),
        "left_knee": kp(0.43, 0.80, 0.20), "right_knee": kp(0.57, 0.80, 0.20),
        "left_ankle": kp(0.42, 0.95, 0.08), "right_ankle": kp(0.58, 0.95, 0.08),
        "left_foot_index": kp(0.42, 0.95, 0.11), "right_foot_index": kp(0.58, 0.95, 0.11),
    })

    # ── KNEELING ──
    templates["kneeling"] = _make_skel({
        "nose": kp(0.50, 0.18, 0.05),
        "left_shoulder": kp(0.43, 0.30, 0.08), "right_shoulder": kp(0.57, 0.30, 0.08),
        "left_elbow": kp(0.36, 0.45, 0.12), "right_elbow": kp(0.64, 0.45, 0.12),
        "left_wrist": kp(0.30, 0.55, 0.15), "right_wrist": kp(0.70, 0.55, 0.15),
        "left_hip": kp(0.46, 0.55, 0.08), "right_hip": kp(0.54, 0.55, 0.05),
        "left_knee": kp(0.45, 0.85, 0.10), "right_knee": kp(0.55, 0.85, 0.08),
        "left_ankle": kp(0.44, 0.96, 0.05), "right_ankle": kp(0.56, 0.96, 0.04),
    })

    # ── WALKING ──
    templates["walking"] = _make_skel({
        "left_shoulder": kp(0.42, 0.18, 0.10), "right_shoulder": kp(0.58, 0.18, 0.06),
        "left_elbow": kp(0.32, 0.32, 0.15), "right_elbow": kp(0.66, 0.38, 0.10),
        "left_wrist": kp(0.28, 0.48, 0.18), "right_wrist": kp(0.72, 0.55, 0.12),
        "left_pinky": kp(0.27, 0.50, 0.18), "right_pinky": kp(0.73, 0.57, 0.12),
        "left_index": kp(0.29, 0.49, 0.18), "right_index": kp(0.71, 0.56, 0.12),
        "left_thumb": kp(0.27, 0.47, 0.18), "right_thumb": kp(0.73, 0.54, 0.12),
        "left_hip": kp(0.45, 0.50, 0.08), "right_hip": kp(0.55, 0.50, 0.04),
        "left_knee": kp(0.42, 0.72, 0.15), "right_knee": kp(0.58, 0.70, 0.08),
        "left_ankle": kp(0.40, 0.91, 0.15), "right_ankle": kp(0.60, 0.88, 0.05),
        "left_heel": kp(0.40, 0.92, 0.12), "right_heel": kp(0.60, 0.89, 0.02),
        "left_foot_index": kp(0.40, 0.91, 0.18), "right_foot_index": kp(0.60, 0.88, 0.08),
    })

    # ── JUMP ──
    templates["jump"] = _make_skel({
        "nose": kp(0.50, 0.04, 0.05),
        "left_shoulder": kp(0.42, 0.16, 0.10), "right_shoulder": kp(0.58, 0.16, 0.10),
        "left_elbow": kp(0.30, 0.22, 0.18), "right_elbow": kp(0.70, 0.22, 0.18),
        "left_wrist": kp(0.22, 0.12, 0.20), "right_wrist": kp(0.78, 0.12, 0.20),
        "left_pinky": kp(0.21, 0.14, 0.20), "right_pinky": kp(0.79, 0.14, 0.20),
        "left_index": kp(0.23, 0.13, 0.20), "right_index": kp(0.77, 0.13, 0.20),
        "left_thumb": kp(0.21, 0.11, 0.20), "right_thumb": kp(0.79, 0.11, 0.20),
        "left_knee": kp(0.40, 0.68, 0.20), "right_knee": kp(0.60, 0.68, 0.20),
        "left_ankle": kp(0.38, 0.85, 0.15), "right_ankle": kp(0.62, 0.85, 0.15),
        "left_foot_index": kp(0.38, 0.85, 0.18), "right_foot_index": kp(0.62, 0.85, 0.18),
    })

    # ── HAIR FLIP ──
    templates["hair_flip"] = _make_skel({
        "right_elbow": kp(0.58, 0.22, 0.15), "right_wrist": kp(0.52, 0.10, 0.18),
        "nose": kp(0.48, 0.06, 0.08),
        "left_hip": kp(0.45, 0.50, 0.08), "right_hip": kp(0.55, 0.50, 0.03),
    })

    # ── BACK VIEW ──
    back = _make_skel({})
    for i in range(33):
        back[i]["x"] = round(1.0 - back[i]["x"], 3)
        back[i]["z"] = round(-back[i]["z"], 3)
    templates["back_view"] = back

    # ── WALKING AWAY (back view + stride) ──
    t = deepcopy(back)
    t[KP["left_knee"]]  = kp(0.58, 0.72, -0.15)
    t[KP["right_knee"]] = kp(0.42, 0.70, -0.08)
    t[KP["left_ankle"]] = kp(0.60, 0.91, -0.15)
    t[KP["right_ankle"]] = kp(0.40, 0.88, -0.05)
    t[KP["left_elbow"]] = kp(0.68, 0.32, -0.15)
    t[KP["right_elbow"]] = kp(0.34, 0.38, -0.10)
    t[KP["left_wrist"]] = kp(0.72, 0.48, -0.18)
    t[KP["right_wrist"]] = kp(0.30, 0.55, -0.12)
    templates["walking_away"] = t

    # ── MIRROR SELFIE ──
    templates["mirror_selfie"] = _make_skel({
        "right_elbow": kp(0.60, 0.22, 0.18), "right_wrist": kp(0.56, 0.10, 0.20),
        "nose": kp(0.50, 0.07, 0.08),
        "left_elbow": kp(0.36, 0.38, 0.10), "left_wrist": kp(0.42, 0.48, 0.12),
    })

    # ── DYNAMIC TWIRL (one arm out, slight spin) ──
    templates["dynamic_twirl"] = _make_skel({
        "left_shoulder": kp(0.40, 0.17, 0.12), "right_shoulder": kp(0.60, 0.19, 0.06),
        "left_elbow": kp(0.22, 0.28, 0.20), "right_elbow": kp(0.68, 0.32, 0.12),
        "left_wrist": kp(0.15, 0.40, 0.22), "right_wrist": kp(0.62, 0.15, 0.18),
        "left_hip": kp(0.44, 0.50, 0.10), "right_hip": kp(0.56, 0.50, 0.04),
        "left_knee": kp(0.42, 0.72, 0.15), "right_knee": kp(0.54, 0.70, 0.06),
        "left_ankle": kp(0.40, 0.92, 0.10), "right_ankle": kp(0.52, 0.90, 0.04),
    })

    # ── DYNAMIC KICK (one leg kicked up) ──
    templates["dynamic_kick"] = _make_skel({
        "left_shoulder": kp(0.42, 0.17, 0.10), "right_shoulder": kp(0.58, 0.17, 0.06),
        "left_elbow": kp(0.30, 0.30, 0.18), "right_elbow": kp(0.66, 0.34, 0.10),
        "left_wrist": kp(0.25, 0.42, 0.20), "right_wrist": kp(0.72, 0.48, 0.12),
        "right_knee": kp(0.60, 0.60, 0.22), "right_ankle": kp(0.65, 0.78, 0.25),
        "right_heel": kp(0.65, 0.79, 0.22), "right_foot_index": kp(0.65, 0.78, 0.28),
    })

    # ── CROUCHING LOW (deeper than squatting, ground-level) ──
    templates["crouching"] = _make_skel({
        "nose": kp(0.50, 0.35, 0.05),
        "left_shoulder": kp(0.43, 0.48, 0.08), "right_shoulder": kp(0.57, 0.48, 0.08),
        "left_elbow": kp(0.42, 0.62, 0.15), "right_elbow": kp(0.58, 0.62, 0.15),
        "left_wrist": kp(0.44, 0.66, 0.15), "right_wrist": kp(0.56, 0.66, 0.15),
        "left_hip": kp(0.46, 0.68, 0.10), "right_hip": kp(0.54, 0.68, 0.08),
        "left_knee": kp(0.44, 0.85, 0.20), "right_knee": kp(0.56, 0.85, 0.18),
        "left_ankle": kp(0.43, 0.96, 0.08), "right_ankle": kp(0.57, 0.96, 0.06),
    })

    if name not in templates:
        raise ValueError(f"Unknown template: {name}. Available: {list(templates.keys())}")

    sk = deepcopy(templates[name])
    for kp_id, vals in overrides.items():
        int_id = kp_id if isinstance(kp_id, int) else KP.get(kp_id, -1)
        if int_id >= 0 and int_id < 33:
            sk[int_id].update(vals)

    id_to_name = {v: k for k, v in KP.items()}
    for i, kpt in enumerate(sk):
        kpt["id"] = i
        kpt["name"] = id_to_name.get(i, "")

    return sk


# ── Scene / Style / Difficulty Tags ─────────────────────────────

SCENES = {
    "outdoor": "户外自然",
    "street": "城市街拍",
    "indoor": "室内",
    "beach": "海滩",
    "night": "夜景",
}

SUB_POSITION_CN = {
    # Standing
    "straight": "站直", "cross-leg": "交叉腿站", "profile-lookback": "侧身回眸",
    "one-leg-bent": "单腿屈膝", "lean-tree": "靠树", "lean-wall": "靠墙",
    "arms-up-stretch": "抬手伸展", "hand-hip": "叉腰", "arms-crossed": "双臂交叉",
    "arm-up": "单臂上举", "over-shoulder": "回眸一瞥", "look-down": "低头沉思",
    "hands-hair": "手撩秀发", "side-lean": "侧身倚靠",
    # Sitting
    "front-sit": "正面坐", "side-sit": "侧坐", "cross-leg-sit": "盘腿坐",
    "knee-hug": "抱膝坐", "side-sit-profile": "侧身坐", "lean-back": "后仰坐",
    "legs-extended": "伸腿坐", "floor-sit": "地板坐", "reading-book": "看书坐",
    # Dynamic
    "walk-lookback": "走路回眸", "jump": "跳跃", "spin-skirt": "转裙摆",
    "throw-leaves": "撒落叶", "walk-crosswalk": "走斑马线", "walk-lookback-smile": "回眸微笑",
    "walk-shoreline": "走海岸线", "jump-waves": "跳浪", "splash-water": "踩水花",
    "spin-beach": "海滩转圈", "run-shore": "海边奔跑", "hair-flip-ocean": "海边撩发",
    "walk-away": "走远背影", "twirl": "旋转", "kick": "踢腿", "walk-night-street": "夜景行走",
    "lookback-neon": "霓虹回眸",
    # Special
    "back-view": "背影", "hair-flip": "撩发", "silhouette-stand": "剪影站姿",
    "lying-grass": "躺草地", "hand-flower-closeup": "手部特写",
    "mirror-selfie": "镜前自拍", "hands-in-pockets": "手插口袋", "holding-coffee": "手持咖啡",
    "holding-prop": "手持道具", "crouching": "蹲姿", "kneeling": "跪姿",
    "squatting": "深蹲", "looking-up": "仰望", "touching-wall": "触墙",
    # Scene-specific specials
    "sunset-silhouette": "落日剪影", "back-view-sunset": "落日背影", "lying-sand": "躺沙滩",
    "shell-closeup": "贝壳特写", "waves-edge": "浪边站姿", "back-view-ocean": "面海背影",
    "front-sit-sand": "沙滩正面坐", "side-sit-sand": "沙滩侧坐", "cross-leg-sand": "沙滩盘腿",
    "knee-hug-sand": "沙滩抱膝", "lean-graffiti-wall": "靠涂鸦墙", "walking-down-stairs": "下楼梯",
    "back-view-street": "街拍背影", "mirror-selfie-full": "镜前全身",
    "window-light": "窗光站姿", "front-sit-sofa": "沙发正面坐", "side-sit-chair": "椅子侧坐",
    "cross-leg-sofa": "沙发盘腿", "knee-hug-bed": "床上抱膝", "back-view-window": "窗边背影",
    "lying-bed": "躺床", "window-silhouette": "窗影", "closeup-coffee": "咖啡特写",
    "lean-door-frame": "倚门框", "hair-flip-indoor": "室内撩发", "spin-dress": "转裙",
    "lean-wall-night": "夜景靠墙", "backlit-street": "街灯逆光", "look-up-neon": "仰望霓虹",
    "front-sit-stairs": "台阶正面坐", "side-sit-bench": "长凳侧坐", "cross-leg-bench": "长凳盘腿",
    "sparkler-closeup": "仙女棒特写", "puddle-reflection": "积水倒影",
    "traffic-blur-background": "车流虚化背景", "transparent-umbrella": "透明伞",
    "leaning-car": "靠车", "light-trail-spin": "光轨旋转", "neon-silhouette": "霓虹剪影",
    "back-view-neon": "霓虹背影", "ground-sit-night": "夜景地面坐", "cross-leg-neon": "霓虹交叉腿",
    "profile-neon": "霓虹侧身", "profile": "侧身", "sitting-wall": "靠墙坐",
    "hands-in-frame": "手入画", "skirt-hold": "提裙",
    "water-touch": "触水", "sand-play": "玩沙",
}

STYLES = ["fresh", "cool", "sweet", "elegant", "casual", "natural"]
DIFFICULTIES = ["beginner", "intermediate"]


# ── Pose Recipes: (pose_id_base, body_position, sub_position, template, styles, difficulty) ──

POSE_RECIPES = [
    # ═══════════════════════════════════════════════════════════════
    # 户外自然 (60 poses)
    # ═══════════════════════════════════════════════════════════════
    # -- Standing (20) --
    ("outdoor-standing-straight", "standing", "straight", "standing", ["natural", "fresh"], "beginner"),
    ("outdoor-standing-cross", "standing", "cross-leg", "standing_cross_leg", ["elegant", "casual"], "beginner"),
    ("outdoor-standing-profile", "standing", "profile-lookback", "standing_profile", ["fresh", "sweet"], "beginner"),
    ("outdoor-standing-bentleg", "standing", "one-leg-bent", "standing_one_leg_bent", ["casual", "cool"], "beginner"),
    ("outdoor-standing-lean-tree", "standing", "lean-tree", "standing_wall_lean", ["casual", "natural"], "beginner"),
    ("outdoor-standing-armsup", "standing", "arms-up-stretch", "jump", ["natural", "fresh"], "intermediate"),
    ("outdoor-standing-back", "standing", "back-view", "back_view", ["elegant", "cool"], "beginner"),
    ("outdoor-standing-hairflip", "standing", "hair-flip", "hair_flip", ["sweet", "fresh"], "intermediate"),
    ("outdoor-standing-handhip", "standing", "hand-hip", "standing_hand_hip", ["cool", "casual"], "beginner"),
    ("outdoor-standing-armcross", "standing", "arms-crossed", "standing_arms_crossed", ["cool", "elegant"], "beginner"),
    ("outdoor-standing-armup", "standing", "arm-up", "standing_arm_up", ["natural", "fresh"], "intermediate"),
    ("outdoor-standing-overshoulder", "standing", "over-shoulder", "standing_over_shoulder", ["elegant", "sweet"], "beginner"),
    ("outdoor-standing-lookdown", "standing", "look-down", "standing_look_down", ["elegant", "natural"], "beginner"),
    ("outdoor-standing-handshair", "standing", "hands-hair", "standing_hands_hair", ["sweet", "fresh"], "intermediate"),
    ("outdoor-standing-sidelean", "standing", "side-lean", "standing_wall_lean", ["casual", "natural"], "beginner"),
    ("outdoor-standing-windblow", "standing", "hair-flip", "hair_flip", ["fresh", "sweet"], "intermediate"),
    ("outdoor-standing-faceup", "standing", "looking-up", "standing_arm_up", ["natural", "fresh"], "beginner"),
    ("outdoor-standing-handcoat", "standing", "hands-in-pockets", "standing_cross_leg", ["cool", "casual"], "beginner"),
    ("outdoor-standing-skirthold", "standing", "skirt-hold", "standing_one_leg_bent", ["sweet", "elegant"], "beginner"),
    ("outdoor-standing-hattouch", "standing", "hand-hip", "standing_hand_hip", ["casual", "natural"], "beginner"),
    # -- Sitting (12) --
    ("outdoor-sitting-front", "sitting", "front-sit", "sitting", ["natural", "casual"], "beginner"),
    ("outdoor-sitting-side", "sitting", "side-sit", "sitting", ["elegant", "fresh"], "beginner"),
    ("outdoor-sitting-crossleg", "sitting", "cross-leg-sit", "sitting_cross_leg", ["casual", "natural"], "beginner"),
    ("outdoor-sitting-kneehug", "sitting", "knee-hug", "sitting_knee_hug", ["sweet", "fresh"], "intermediate"),
    ("outdoor-sitting-sideprofile", "sitting", "side-sit-profile", "sitting_side", ["elegant", "cool"], "beginner"),
    ("outdoor-sitting-leanback", "sitting", "lean-back", "sitting_lean_back", ["casual", "natural"], "intermediate"),
    ("outdoor-sitting-legsout", "sitting", "legs-extended", "sitting_legs_out", ["casual", "fresh"], "beginner"),
    ("outdoor-sitting-floor", "sitting", "floor-sit", "sitting_cross_leg", ["casual", "natural"], "beginner"),
    ("outdoor-sitting-wall", "sitting", "sitting-wall", "sitting_lean_back", ["casual", "cool"], "beginner"),
    ("outdoor-sitting-reading", "sitting", "reading-book", "sitting", ["elegant", "fresh"], "beginner"),
    ("outdoor-sitting-sidelook", "sitting", "side-sit-profile", "sitting_side", ["elegant", "sweet"], "beginner"),
    ("outdoor-sitting-hatlap", "sitting", "front-sit", "sitting_cross_leg", ["sweet", "natural"], "beginner"),
    # -- Dynamic (16) --
    ("outdoor-dynamic-walk", "dynamic", "walk-lookback", "walking", ["fresh", "natural"], "intermediate"),
    ("outdoor-dynamic-jump", "dynamic", "jump", "jump", ["cool", "casual"], "intermediate"),
    ("outdoor-dynamic-spin", "dynamic", "spin-skirt", "hair_flip", ["sweet", "elegant"], "intermediate"),
    ("outdoor-dynamic-throw", "dynamic", "throw-leaves", "jump", ["natural", "fresh"], "intermediate"),
    ("outdoor-dynamic-run", "dynamic", "run-shore", "walking", ["natural", "fresh"], "intermediate"),
    ("outdoor-dynamic-walkaway", "dynamic", "walk-away", "walking_away", ["cool", "elegant"], "intermediate"),
    ("outdoor-dynamic-twirl", "dynamic", "twirl", "dynamic_twirl", ["sweet", "elegant"], "intermediate"),
    ("outdoor-dynamic-kick", "dynamic", "kick", "dynamic_kick", ["casual", "cool"], "intermediate"),
    ("outdoor-dynamic-hairflip-wind", "dynamic", "hair-flip", "hair_flip", ["sweet", "fresh"], "intermediate"),
    ("outdoor-dynamic-jump-back", "dynamic", "jump", "jump", ["cool", "elegant"], "intermediate"),
    ("outdoor-dynamic-walk-smile", "dynamic", "walk-lookback-smile", "walking", ["sweet", "fresh"], "intermediate"),
    ("outdoor-dynamic-spin-fast", "dynamic", "spin-skirt", "dynamic_twirl", ["sweet", "fresh"], "intermediate"),
    ("outdoor-dynamic-leaf-toss", "dynamic", "throw-leaves", "jump", ["natural", "casual"], "intermediate"),
    ("outdoor-dynamic-stride", "dynamic", "walk-lookback", "walking", ["cool", "casual"], "intermediate"),
    ("outdoor-dynamic-hop", "dynamic", "jump", "jump", ["casual", "fresh"], "intermediate"),
    ("outdoor-dynamic-field-run", "dynamic", "run-shore", "walking", ["natural", "fresh"], "intermediate"),
    # -- Special (12) --
    ("outdoor-special-back", "special", "back-view", "back_view", ["cool", "elegant"], "beginner"),
    ("outdoor-special-silhouette", "special", "silhouette-stand", "standing", ["elegant", "cool"], "beginner"),
    ("outdoor-special-lying", "special", "lying-grass", "sitting", ["casual", "natural"], "intermediate"),
    ("outdoor-special-closeup", "special", "hand-flower-closeup", "standing", ["sweet", "fresh"], "beginner"),
    ("outdoor-special-squatting", "special", "squatting", "squatting", ["casual", "cool"], "beginner"),
    ("outdoor-special-kneeling", "special", "kneeling", "kneeling", ["elegant", "sweet"], "intermediate"),
    ("outdoor-special-crouching", "special", "crouching", "crouching", ["casual", "natural"], "beginner"),
    ("outdoor-special-touch-tree", "special", "touching-wall", "standing_arm_up", ["natural", "fresh"], "beginner"),
    ("outdoor-special-looking-up-canopy", "special", "looking-up", "standing_look_down", ["natural", "elegant"], "beginner"),
    ("outdoor-special-hands-frame", "special", "hands-in-frame", "standing", ["sweet", "fresh"], "beginner"),
    ("outdoor-special-shadow-play", "special", "silhouette-stand", "standing_profile", ["cool", "elegant"], "beginner"),
    ("outdoor-special-lying-side", "special", "lying-grass", "sitting_side", ["sweet", "casual"], "intermediate"),

    # ═══════════════════════════════════════════════════════════════
    # 城市街拍 (60 poses)
    # ═══════════════════════════════════════════════════════════════
    # -- Standing (20) --
    ("street-standing-straight", "standing", "straight", "standing", ["cool", "elegant"], "beginner"),
    ("street-standing-cross", "standing", "cross-leg", "standing_cross_leg", ["cool", "elegant"], "beginner"),
    ("street-standing-profile", "standing", "profile-lookback", "standing_profile", ["cool", "casual"], "beginner"),
    ("street-standing-bentleg", "standing", "one-leg-bent", "standing_one_leg_bent", ["cool", "elegant"], "beginner"),
    ("street-standing-lean", "standing", "lean-wall", "standing_wall_lean", ["cool", "casual"], "beginner"),
    ("street-standing-mirror", "standing", "mirror-selfie", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("street-standing-handpocket", "standing", "hands-in-pockets", "standing_cross_leg", ["cool", "casual"], "beginner"),
    ("street-standing-coffee", "standing", "holding-coffee", "standing_one_leg_bent", ["casual", "natural"], "beginner"),
    ("street-standing-handhip", "standing", "hand-hip", "standing_hand_hip", ["cool", "elegant"], "beginner"),
    ("street-standing-armcross", "standing", "arms-crossed", "standing_arms_crossed", ["cool", "casual"], "beginner"),
    ("street-standing-overshoulder", "standing", "over-shoulder", "standing_over_shoulder", ["cool", "elegant"], "beginner"),
    ("street-standing-lookdown", "standing", "look-down", "standing_look_down", ["cool", "elegant"], "beginner"),
    ("street-standing-handshair", "standing", "hands-hair", "standing_hands_hair", ["sweet", "cool"], "intermediate"),
    ("street-standing-phone", "standing", "holding-prop", "mirror_selfie", ["casual", "natural"], "beginner"),
    ("street-standing-baghold", "standing", "holding-prop", "standing_one_leg_bent", ["elegant", "casual"], "beginner"),
    ("street-standing-lookaway", "standing", "profile-lookback", "standing_profile", ["cool", "casual"], "beginner"),
    ("street-standing-umbrella", "standing", "holding-prop", "standing_hand_hip", ["elegant", "sweet"], "beginner"),
    ("street-standing-sidelean-gate", "standing", "side-lean", "standing_wall_lean", ["cool", "casual"], "beginner"),
    ("street-standing-cap", "standing", "hand-hip", "standing_hand_hip", ["cool", "casual"], "beginner"),
    ("street-standing-kickwall", "standing", "one-leg-bent", "standing_one_leg_bent", ["cool", "elegant"], "beginner"),
    # -- Sitting (12) --
    ("street-sitting-stairs", "sitting", "front-sit-stairs", "sitting", ["cool", "casual"], "beginner"),
    ("street-sitting-bench-side", "sitting", "side-sit-bench", "sitting", ["elegant", "fresh"], "beginner"),
    ("street-sitting-bench-cross", "sitting", "cross-leg-bench", "sitting_cross_leg", ["elegant", "cool"], "beginner"),
    ("street-sitting-stairs-kneehug", "sitting", "knee-hug", "sitting_knee_hug", ["casual", "cool"], "intermediate"),
    ("street-sitting-floor", "sitting", "floor-sit", "sitting_cross_leg", ["cool", "casual"], "beginner"),
    ("street-sitting-legsout", "sitting", "legs-extended", "sitting_legs_out", ["casual", "cool"], "beginner"),
    ("street-sitting-leanback", "sitting", "lean-back", "sitting_lean_back", ["casual", "cool"], "intermediate"),
    ("street-sitting-sideprofile", "sitting", "side-sit-profile", "sitting_side", ["elegant", "cool"], "beginner"),
    ("street-sitting-wall", "sitting", "sitting-wall", "sitting_lean_back", ["cool", "casual"], "beginner"),
    ("street-sitting-curb", "sitting", "front-sit-stairs", "sitting", ["casual", "natural"], "beginner"),
    ("street-sitting-reading-bench", "sitting", "reading-book", "sitting", ["elegant", "fresh"], "beginner"),
    ("street-sitting-coffee-bench", "sitting", "holding-coffee", "sitting", ["casual", "cool"], "beginner"),
    # -- Dynamic (16) --
    ("street-dynamic-walk-crosswalk", "dynamic", "walk-crosswalk", "walking", ["cool", "natural"], "intermediate"),
    ("street-dynamic-lookback", "dynamic", "walk-lookback-smile", "walking", ["sweet", "fresh"], "intermediate"),
    ("street-dynamic-hairflip", "dynamic", "hair-flip", "hair_flip", ["cool", "elegant"], "intermediate"),
    ("street-dynamic-jump", "dynamic", "jump", "jump", ["casual", "fresh"], "intermediate"),
    ("street-dynamic-walkaway", "dynamic", "walk-away", "walking_away", ["cool", "elegant"], "intermediate"),
    ("street-dynamic-twirl", "dynamic", "twirl", "dynamic_twirl", ["sweet", "elegant"], "intermediate"),
    ("street-dynamic-stride", "dynamic", "walk-lookback", "walking", ["cool", "casual"], "intermediate"),
    ("street-dynamic-kick", "dynamic", "kick", "dynamic_kick", ["cool", "casual"], "intermediate"),
    ("street-dynamic-stairs-walk", "dynamic", "walking-down-stairs", "walking", ["elegant", "cool"], "intermediate"),
    ("street-dynamic-run", "dynamic", "run-shore", "walking", ["casual", "fresh"], "intermediate"),
    ("street-dynamic-bike-push", "dynamic", "walk-lookback-smile", "walking", ["casual", "natural"], "intermediate"),
    ("street-dynamic-spin", "dynamic", "spin-skirt", "dynamic_twirl", ["sweet", "fresh"], "intermediate"),
    ("street-dynamic-crosswalk-smile", "dynamic", "walk-crosswalk", "walking", ["fresh", "natural"], "intermediate"),
    ("street-dynamic-hop", "dynamic", "jump", "jump", ["casual", "cool"], "intermediate"),
    ("street-dynamic-walk-coffee", "dynamic", "walk-lookback", "walking", ["casual", "natural"], "intermediate"),
    ("street-dynamic-turn-back", "dynamic", "walk-lookback-smile", "walking", ["cool", "elegant"], "intermediate"),
    # -- Special (12) --
    ("street-special-back", "special", "back-view-street", "back_view", ["cool", "elegant"], "beginner"),
    ("street-special-mirror", "special", "mirror-selfie", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("street-special-graffiti", "special", "lean-graffiti-wall", "standing_wall_lean", ["cool", "casual"], "beginner"),
    ("street-special-down-stairs", "special", "walking-down-stairs", "walking", ["elegant", "cool"], "intermediate"),
    ("street-special-squatting", "special", "squatting", "squatting", ["cool", "casual"], "beginner"),
    ("street-special-kneeling", "special", "kneeling", "kneeling", ["cool", "elegant"], "intermediate"),
    ("street-special-crouching", "special", "crouching", "crouching", ["casual", "cool"], "beginner"),
    ("street-special-looking-up", "special", "looking-up", "standing_look_down", ["cool", "elegant"], "beginner"),
    ("street-special-shadow", "special", "silhouette-stand", "standing_profile", ["cool", "elegant"], "beginner"),
    ("street-special-umbrella-open", "special", "holding-prop", "standing_hand_hip", ["elegant", "sweet"], "beginner"),
    ("street-special-doorway", "special", "lean-door-frame", "standing_wall_lean", ["elegant", "cool"], "beginner"),
    ("street-special-escalator", "special", "walking-down-stairs", "walking", ["cool", "casual"], "intermediate"),

    # ═══════════════════════════════════════════════════════════════
    # 室内 (60 poses)
    # ═══════════════════════════════════════════════════════════════
    # -- Standing (18) --
    ("indoor-standing-straight", "standing", "straight", "standing", ["elegant", "natural"], "beginner"),
    ("indoor-standing-cross", "standing", "cross-leg", "standing_cross_leg", ["elegant", "cool"], "beginner"),
    ("indoor-standing-profile", "standing", "profile", "standing_profile", ["elegant", "sweet"], "beginner"),
    ("indoor-standing-lean", "standing", "lean-wall", "standing_wall_lean", ["casual", "natural"], "beginner"),
    ("indoor-standing-mirror", "standing", "mirror-selfie", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("indoor-standing-window", "standing", "window-light", "standing_profile", ["elegant", "fresh"], "beginner"),
    ("indoor-standing-handhip", "standing", "hand-hip", "standing_hand_hip", ["elegant", "cool"], "beginner"),
    ("indoor-standing-armcross", "standing", "arms-crossed", "standing_arms_crossed", ["cool", "elegant"], "beginner"),
    ("indoor-standing-overshoulder", "standing", "over-shoulder", "standing_over_shoulder", ["elegant", "sweet"], "beginner"),
    ("indoor-standing-lookdown", "standing", "look-down", "standing_look_down", ["elegant", "natural"], "beginner"),
    ("indoor-standing-handshair", "standing", "hands-hair", "standing_hands_hair", ["sweet", "elegant"], "intermediate"),
    ("indoor-standing-armup", "standing", "arm-up", "standing_arm_up", ["elegant", "fresh"], "beginner"),
    ("indoor-standing-doorframe", "standing", "lean-door-frame", "standing_wall_lean", ["elegant", "cool"], "beginner"),
    ("indoor-standing-curtain", "standing", "touching-wall", "standing_arm_up", ["elegant", "sweet"], "beginner"),
    ("indoor-standing-bookhold", "standing", "holding-prop", "standing_one_leg_bent", ["elegant", "natural"], "beginner"),
    ("indoor-standing-coffee-stand", "standing", "holding-coffee", "standing_hand_hip", ["casual", "natural"], "beginner"),
    ("indoor-standing-lookback-sofa", "standing", "over-shoulder", "standing_over_shoulder", ["casual", "cool"], "beginner"),
    ("indoor-standing-hat-hallway", "standing", "hand-hip", "standing_hand_hip", ["elegant", "cool"], "beginner"),
    # -- Sitting (20) --
    ("indoor-sitting-sofa-front", "sitting", "front-sit-sofa", "sitting", ["elegant", "natural"], "beginner"),
    ("indoor-sitting-chair-side", "sitting", "side-sit-chair", "sitting", ["elegant", "casual"], "beginner"),
    ("indoor-sitting-sofa-cross", "sitting", "cross-leg-sofa", "sitting_cross_leg", ["elegant", "cool"], "beginner"),
    ("indoor-sitting-bed-kneehug", "sitting", "knee-hug-bed", "sitting_knee_hug", ["sweet", "casual"], "intermediate"),
    ("indoor-sitting-floor", "sitting", "floor-sit", "sitting_cross_leg", ["casual", "natural"], "beginner"),
    ("indoor-sitting-reading", "sitting", "reading-book", "sitting", ["elegant", "fresh"], "beginner"),
    ("indoor-sitting-sideprofile", "sitting", "side-sit-profile", "sitting_side", ["elegant", "cool"], "beginner"),
    ("indoor-sitting-leanback", "sitting", "lean-back", "sitting_lean_back", ["casual", "natural"], "intermediate"),
    ("indoor-sitting-legsout", "sitting", "legs-extended", "sitting_legs_out", ["casual", "fresh"], "beginner"),
    ("indoor-sitting-wall-floor", "sitting", "sitting-wall", "sitting_lean_back", ["casual", "cool"], "beginner"),
    ("indoor-sitting-window-sill", "sitting", "side-sit-profile", "sitting_side", ["elegant", "sweet"], "beginner"),
    ("indoor-sitting-coffee-chair", "sitting", "holding-coffee", "sitting", ["casual", "natural"], "beginner"),
    ("indoor-sitting-magazine", "sitting", "reading-book", "sitting_cross_leg", ["casual", "fresh"], "beginner"),
    ("indoor-sitting-cross-floor-cushion", "sitting", "cross-leg-sit", "sitting_cross_leg", ["casual", "natural"], "beginner"),
    ("indoor-sitting-chair-backwards", "sitting", "arms-crossed", "sitting", ["cool", "casual"], "beginner"),
    ("indoor-sitting-oneleg-up", "sitting", "one-leg-bent", "sitting_knee_hug", ["casual", "cool"], "intermediate"),
    ("indoor-sitting-floor-side", "sitting", "side-sit", "sitting_side", ["elegant", "sweet"], "beginner"),
    ("indoor-sitting-bed-edge", "sitting", "front-sit-sofa", "sitting_legs_out", ["casual", "natural"], "beginner"),
    ("indoor-sitting-desk-lean", "sitting", "lean-back", "sitting_lean_back", ["elegant", "cool"], "beginner"),
    ("indoor-sitting-cushion-hug", "sitting", "knee-hug", "sitting_knee_hug", ["sweet", "casual"], "intermediate"),
    # -- Dynamic (10) --
    ("indoor-dynamic-hairflip", "dynamic", "hair-flip-indoor", "hair_flip", ["elegant", "sweet"], "intermediate"),
    ("indoor-dynamic-spin", "dynamic", "spin-dress", "hair_flip", ["elegant", "sweet"], "intermediate"),
    ("indoor-dynamic-twirl", "dynamic", "twirl", "dynamic_twirl", ["sweet", "elegant"], "intermediate"),
    ("indoor-dynamic-walk", "dynamic", "walk-lookback-smile", "walking", ["elegant", "fresh"], "intermediate"),
    ("indoor-dynamic-jump", "dynamic", "jump", "jump", ["casual", "fresh"], "intermediate"),
    ("indoor-dynamic-kick", "dynamic", "kick", "dynamic_kick", ["cool", "casual"], "intermediate"),
    ("indoor-dynamic-curtain-twirl", "dynamic", "spin-dress", "dynamic_twirl", ["sweet", "elegant"], "intermediate"),
    ("indoor-dynamic-bed-jump", "dynamic", "jump", "jump", ["casual", "fresh"], "intermediate"),
    ("indoor-dynamic-walk-away", "dynamic", "walk-away", "walking_away", ["cool", "elegant"], "intermediate"),
    ("indoor-dynamic-spin-slow", "dynamic", "twirl", "dynamic_twirl", ["elegant", "sweet"], "intermediate"),
    # -- Special (12) --
    ("indoor-special-mirror-full", "special", "mirror-selfie-full", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("indoor-special-back-window", "special", "back-view-window", "back_view", ["elegant", "cool"], "beginner"),
    ("indoor-special-lying-bed", "special", "lying-bed", "sitting", ["sweet", "casual"], "intermediate"),
    ("indoor-special-silhouette", "special", "window-silhouette", "standing_profile", ["elegant", "cool"], "beginner"),
    ("indoor-special-coffee-closeup", "special", "closeup-coffee", "sitting", ["casual", "natural"], "beginner"),
    ("indoor-special-lean-door-frame", "special", "lean-door-frame", "standing_wall_lean", ["elegant", "cool"], "beginner"),
    ("indoor-special-kneeling", "special", "kneeling", "kneeling", ["elegant", "sweet"], "intermediate"),
    ("indoor-special-squatting", "special", "squatting", "squatting", ["cool", "casual"], "beginner"),
    ("indoor-special-crouching", "special", "crouching", "crouching", ["casual", "natural"], "beginner"),
    ("indoor-special-looking-up", "special", "looking-up", "standing_look_down", ["elegant", "natural"], "beginner"),
    ("indoor-special-hands-frame", "special", "hands-in-frame", "standing", ["sweet", "fresh"], "beginner"),
    ("indoor-special-book-closeup", "special", "reading-book", "sitting", ["elegant", "natural"], "beginner"),

    # ═══════════════════════════════════════════════════════════════
    # 海滩 (60 poses)
    # ═══════════════════════════════════════════════════════════════
    # -- Standing (18) --
    ("beach-standing-straight", "standing", "straight", "standing", ["natural", "fresh"], "beginner"),
    ("beach-standing-cross", "standing", "cross-leg", "standing_cross_leg", ["elegant", "fresh"], "beginner"),
    ("beach-standing-profile", "standing", "profile-lookback", "standing_profile", ["sweet", "natural"], "beginner"),
    ("beach-standing-bentleg", "standing", "one-leg-bent", "standing_one_leg_bent", ["casual", "fresh"], "beginner"),
    ("beach-standing-waves-edge", "standing", "waves-edge", "standing_cross_leg", ["natural", "sweet"], "beginner"),
    ("beach-standing-back-ocean", "standing", "back-view-ocean", "back_view", ["cool", "elegant"], "beginner"),
    ("beach-standing-handhip", "standing", "hand-hip", "standing_hand_hip", ["cool", "casual"], "beginner"),
    ("beach-standing-armup", "standing", "arm-up", "standing_arm_up", ["natural", "fresh"], "intermediate"),
    ("beach-standing-armsup-sky", "standing", "arms-up-stretch", "jump", ["natural", "fresh"], "intermediate"),
    ("beach-standing-lookdown-waves", "standing", "look-down", "standing_look_down", ["elegant", "natural"], "beginner"),
    ("beach-standing-handshair-wind", "standing", "hands-hair", "standing_hands_hair", ["sweet", "fresh"], "intermediate"),
    ("beach-standing-hat-hold", "standing", "hand-hip", "standing_hand_hip", ["sweet", "casual"], "beginner"),
    ("beach-standing-dress-hold", "standing", "skirt-hold", "standing_one_leg_bent", ["sweet", "elegant"], "beginner"),
    ("beach-standing-overshoulder", "standing", "over-shoulder", "standing_over_shoulder", ["elegant", "sweet"], "beginner"),
    ("beach-standing-wind-hair", "standing", "hair-flip", "hair_flip", ["sweet", "fresh"], "intermediate"),
    ("beach-standing-armcross", "standing", "arms-crossed", "standing_arms_crossed", ["cool", "elegant"], "beginner"),
    ("beach-standing-sidelean-rock", "standing", "side-lean", "standing_wall_lean", ["casual", "natural"], "beginner"),
    ("beach-standing-feet-water", "standing", "waves-edge", "standing_cross_leg", ["natural", "fresh"], "beginner"),
    # -- Sitting (14) --
    ("beach-sitting-sand-front", "sitting", "front-sit-sand", "sitting", ["natural", "casual"], "beginner"),
    ("beach-sitting-sand-side", "sitting", "side-sit-sand", "sitting", ["elegant", "fresh"], "beginner"),
    ("beach-sitting-sand-cross", "sitting", "cross-leg-sand", "sitting_cross_leg", ["casual", "natural"], "beginner"),
    ("beach-sitting-sand-kneehug", "sitting", "knee-hug-sand", "sitting_knee_hug", ["sweet", "fresh"], "intermediate"),
    ("beach-sitting-legsout", "sitting", "legs-extended", "sitting_legs_out", ["casual", "fresh"], "beginner"),
    ("beach-sitting-leanback", "sitting", "lean-back", "sitting_lean_back", ["casual", "natural"], "intermediate"),
    ("beach-sitting-sideprofile", "sitting", "side-sit-profile", "sitting_side", ["elegant", "cool"], "beginner"),
    ("beach-sitting-water-edge", "sitting", "front-sit-sand", "sitting_legs_out", ["natural", "fresh"], "beginner"),
    ("beach-sitting-shell-looking", "sitting", "looking-up", "sitting", ["natural", "sweet"], "beginner"),
    ("beach-sitting-hat-lap", "sitting", "front-sit-sand", "sitting_cross_leg", ["sweet", "casual"], "beginner"),
    ("beach-sitting-cross-water", "sitting", "cross-leg-sand", "sitting_cross_leg", ["natural", "fresh"], "beginner"),
    ("beach-sitting-kneehug-wind", "sitting", "knee-hug-sand", "sitting_knee_hug", ["sweet", "casual"], "intermediate"),
    ("beach-sitting-side-waves", "sitting", "side-sit-sand", "sitting_side", ["elegant", "sweet"], "beginner"),
    ("beach-sitting-sand-play", "sitting", "sand-play", "sitting", ["casual", "natural"], "beginner"),
    # -- Dynamic (16) --
    ("beach-dynamic-walk-shore", "dynamic", "walk-shoreline", "walking", ["natural", "fresh"], "intermediate"),
    ("beach-dynamic-jump-waves", "dynamic", "jump-waves", "jump", ["casual", "cool"], "intermediate"),
    ("beach-dynamic-splash", "dynamic", "splash-water", "jump", ["casual", "natural"], "intermediate"),
    ("beach-dynamic-spin", "dynamic", "spin-beach", "hair_flip", ["sweet", "fresh"], "intermediate"),
    ("beach-dynamic-run-shore", "dynamic", "run-shore", "walking", ["natural", "fresh"], "intermediate"),
    ("beach-dynamic-hairflip", "dynamic", "hair-flip-ocean", "hair_flip", ["sweet", "elegant"], "intermediate"),
    ("beach-dynamic-walkaway", "dynamic", "walk-away", "walking_away", ["cool", "elegant"], "intermediate"),
    ("beach-dynamic-twirl", "dynamic", "twirl", "dynamic_twirl", ["sweet", "elegant"], "intermediate"),
    ("beach-dynamic-kick-water", "dynamic", "kick", "dynamic_kick", ["casual", "fresh"], "intermediate"),
    ("beach-dynamic-jump-high", "dynamic", "jump-waves", "jump", ["cool", "casual"], "intermediate"),
    ("beach-dynamic-run-splash", "dynamic", "run-shore", "walking", ["casual", "natural"], "intermediate"),
    ("beach-dynamic-spin-fast", "dynamic", "spin-beach", "dynamic_twirl", ["sweet", "fresh"], "intermediate"),
    ("beach-dynamic-walk-lookback", "dynamic", "walk-lookback-smile", "walking", ["sweet", "fresh"], "intermediate"),
    ("beach-dynamic-water-touch", "dynamic", "water-touch", "squatting", ["natural", "fresh"], "intermediate"),
    ("beach-dynamic-hop-waves", "dynamic", "jump-waves", "jump", ["casual", "fresh"], "intermediate"),
    ("beach-dynamic-stride-surf", "dynamic", "walk-shoreline", "walking", ["cool", "natural"], "intermediate"),
    # -- Special (12) --
    ("beach-special-sunset-silhouette", "special", "sunset-silhouette", "standing_profile", ["elegant", "cool"], "beginner"),
    ("beach-special-back-sunset", "special", "back-view-sunset", "back_view", ["cool", "elegant"], "beginner"),
    ("beach-special-lying-sand", "special", "lying-sand", "sitting", ["sweet", "casual"], "intermediate"),
    ("beach-special-shell-closeup", "special", "shell-closeup", "sitting", ["natural", "sweet"], "beginner"),
    ("beach-special-squatting", "special", "squatting", "squatting", ["casual", "natural"], "beginner"),
    ("beach-special-kneeling-sand", "special", "kneeling", "kneeling", ["elegant", "sweet"], "intermediate"),
    ("beach-special-crouching", "special", "crouching", "crouching", ["casual", "natural"], "beginner"),
    ("beach-special-looking-up-sky", "special", "looking-up", "standing_look_down", ["natural", "elegant"], "beginner"),
    ("beach-special-shadow-sand", "special", "silhouette-stand", "standing_profile", ["cool", "elegant"], "beginner"),
    ("beach-special-water-reflection", "special", "puddle-reflection", "standing", ["elegant", "cool"], "beginner"),
    ("beach-special-sand-writing", "special", "crouching", "crouching", ["casual", "sweet"], "beginner"),
    ("beach-special-driftwood-sit", "special", "sitting-wall", "sitting", ["natural", "casual"], "beginner"),

    # ═══════════════════════════════════════════════════════════════
    # 夜景 (60 poses)
    # ═══════════════════════════════════════════════════════════════
    # -- Standing (18) --
    ("night-standing-straight", "standing", "straight", "standing", ["cool", "elegant"], "beginner"),
    ("night-standing-cross-neon", "standing", "cross-leg-neon", "standing_cross_leg", ["cool", "elegant"], "beginner"),
    ("night-standing-profile-neon", "standing", "profile-neon", "standing_profile", ["cool", "casual"], "beginner"),
    ("night-standing-lean-wall", "standing", "lean-wall-night", "standing_wall_lean", ["cool", "casual"], "beginner"),
    ("night-standing-lookup-neon", "standing", "look-up-neon", "standing_cross_leg", ["cool", "elegant"], "beginner"),
    ("night-standing-backlit", "standing", "backlit-street", "standing", ["cool", "elegant"], "beginner"),
    ("night-standing-handhip", "standing", "hand-hip", "standing_hand_hip", ["cool", "elegant"], "beginner"),
    ("night-standing-armcross", "standing", "arms-crossed", "standing_arms_crossed", ["cool", "casual"], "beginner"),
    ("night-standing-overshoulder", "standing", "over-shoulder", "standing_over_shoulder", ["cool", "elegant"], "beginner"),
    ("night-standing-lookdown", "standing", "look-down", "standing_look_down", ["cool", "elegant"], "beginner"),
    ("night-standing-umbrella", "standing", "holding-prop", "standing_cross_leg", ["sweet", "fresh"], "beginner"),
    ("night-standing-lamp-post", "standing", "side-lean", "standing_wall_lean", ["cool", "elegant"], "beginner"),
    ("night-standing-hands-hair", "standing", "hands-hair", "standing_hands_hair", ["cool", "elegant"], "intermediate"),
    ("night-standing-armup-neon", "standing", "arm-up", "standing_arm_up", ["cool", "casual"], "beginner"),
    ("night-standing-window-shop", "standing", "over-shoulder", "standing_over_shoulder", ["casual", "cool"], "beginner"),
    ("night-standing-phone-light", "standing", "holding-prop", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("night-standing-coat-pocket", "standing", "hands-in-pockets", "standing_cross_leg", ["cool", "elegant"], "beginner"),
    ("night-standing-car-lean", "standing", "leaning-car", "standing_wall_lean", ["cool", "casual"], "beginner"),
    # -- Sitting (12) --
    ("night-sitting-stairs-front", "sitting", "front-sit-stairs", "sitting", ["cool", "casual"], "beginner"),
    ("night-sitting-bench-side", "sitting", "side-sit-bench", "sitting", ["elegant", "cool"], "beginner"),
    ("night-sitting-bench-cross", "sitting", "cross-leg-bench", "sitting_cross_leg", ["cool", "elegant"], "beginner"),
    ("night-sitting-ground", "sitting", "ground-sit-night", "sitting_knee_hug", ["casual", "cool"], "intermediate"),
    ("night-sitting-legsout", "sitting", "legs-extended", "sitting_legs_out", ["casual", "cool"], "beginner"),
    ("night-sitting-leanback", "sitting", "lean-back", "sitting_lean_back", ["cool", "casual"], "intermediate"),
    ("night-sitting-sideprofile", "sitting", "side-sit-profile", "sitting_side", ["elegant", "cool"], "beginner"),
    ("night-sitting-wall", "sitting", "sitting-wall", "sitting_lean_back", ["cool", "casual"], "beginner"),
    ("night-sitting-curb", "sitting", "front-sit-stairs", "sitting", ["casual", "cool"], "beginner"),
    ("night-sitting-steps-side", "sitting", "side-sit-bench", "sitting_side", ["elegant", "cool"], "beginner"),
    ("night-sitting-kneehug-neon", "sitting", "knee-hug", "sitting_knee_hug", ["casual", "cool"], "intermediate"),
    ("night-sitting-floor-cross", "sitting", "cross-leg-bench", "sitting_cross_leg", ["cool", "casual"], "beginner"),
    # -- Dynamic (14) --
    ("night-dynamic-walk-street", "dynamic", "walk-night-street", "walking", ["cool", "elegant"], "intermediate"),
    ("night-dynamic-lookback-neon", "dynamic", "lookback-neon", "walking", ["cool", "casual"], "intermediate"),
    ("night-dynamic-hairflip", "dynamic", "hair-flip", "hair_flip", ["cool", "elegant"], "intermediate"),
    ("night-dynamic-walkaway", "dynamic", "walk-away", "walking_away", ["cool", "elegant"], "intermediate"),
    ("night-dynamic-twirl", "dynamic", "twirl", "dynamic_twirl", ["elegant", "sweet"], "intermediate"),
    ("night-dynamic-kick", "dynamic", "kick", "dynamic_kick", ["cool", "casual"], "intermediate"),
    ("night-dynamic-run", "dynamic", "run-shore", "walking", ["casual", "cool"], "intermediate"),
    ("night-dynamic-jump-neon", "dynamic", "jump", "jump", ["casual", "cool"], "intermediate"),
    ("night-dynamic-stride", "dynamic", "walk-night-street", "walking", ["cool", "casual"], "intermediate"),
    ("night-dynamic-spin-neon", "dynamic", "twirl", "dynamic_twirl", ["cool", "elegant"], "intermediate"),
    ("night-dynamic-lookback-smile", "dynamic", "lookback-neon", "walking", ["sweet", "cool"], "intermediate"),
    ("night-dynamic-umbrella-walk", "dynamic", "walk-night-street", "walking", ["elegant", "sweet"], "intermediate"),
    ("night-dynamic-hop", "dynamic", "jump", "jump", ["casual", "cool"], "intermediate"),
    ("night-dynamic-walk-couple", "dynamic", "walk-night-street", "walking", ["cool", "elegant"], "intermediate"),
    # -- Special (16) --
    ("night-special-neon-silhouette", "special", "neon-silhouette", "standing_profile", ["cool", "elegant"], "beginner"),
    ("night-special-back-neon", "special", "back-view-neon", "back_view", ["cool", "elegant"], "beginner"),
    ("night-special-sparkler", "special", "sparkler-closeup", "standing", ["sweet", "cool"], "beginner"),
    ("night-special-puddle-reflection", "special", "puddle-reflection", "standing", ["cool", "elegant"], "beginner"),
    ("night-special-traffic-blur", "special", "traffic-blur-background", "standing_profile", ["cool", "casual"], "beginner"),
    ("night-special-umbrella", "special", "transparent-umbrella", "standing_cross_leg", ["sweet", "fresh"], "beginner"),
    ("night-special-car-lean", "special", "leaning-car", "standing_wall_lean", ["cool", "casual"], "beginner"),
    ("night-special-light-trail", "special", "light-trail-spin", "hair_flip", ["cool", "elegant"], "intermediate"),
    ("night-special-squatting", "special", "squatting", "squatting", ["cool", "casual"], "beginner"),
    ("night-special-kneeling", "special", "kneeling", "kneeling", ["cool", "elegant"], "intermediate"),
    ("night-special-crouching", "special", "crouching", "crouching", ["casual", "cool"], "beginner"),
    ("night-special-looking-up-neon", "special", "looking-up", "standing_look_down", ["cool", "elegant"], "beginner"),
    ("night-special-shadow-wall", "special", "silhouette-stand", "standing_profile", ["cool", "elegant"], "beginner"),
    ("night-special-phone-glow", "special", "holding-prop", "mirror_selfie", ["cool", "casual"], "beginner"),
    ("night-special-doorway-light", "special", "lean-wall-night", "standing_wall_lean", ["cool", "elegant"], "beginner"),
    ("night-special-bridge-view", "special", "back-view-neon", "back_view", ["cool", "elegant"], "beginner"),
]


# ── Guidance Text Templates ──────────────────────────────────────

def make_guidance(scene_key: str, position: str, style_tags: list, difficulty: str, pose_id: str) -> dict:
    """Generate guidance text based on pose characteristics."""

    scene_tips = {
        "outdoor": {
            "photographer": "站在低角度仰拍，让天空占画面1/3，人在画面中线偏右",
            "common_mistakes": ["头顶和背景树干重叠", "太端正反而显得僵硬", "背光导致脸黑"],
        },
        "street": {
            "photographer": "开启人像模式，用斑马线/墙面的线条做引导线，三分法构图",
            "common_mistakes": ["背景路人太多", "光线太硬导致脸上阴影重", "表情太紧张"],
        },
        "indoor": {
            "photographer": "利用窗光做侧光源，保持画面冷暖对比，室内暖光+窗外冷光",
            "common_mistakes": ["头顶上方有灯导致影子奇怪", "ISO开太高画面噪点爆炸"],
        },
        "beach": {
            "photographer": "顺光拍海天一色，逆光拍剪影。注意海平面不要切头",
            "common_mistakes": ["风大导致头发满脸飞", "白裙子湿水后变透", "海平面歪斜"],
        },
        "night": {
            "photographer": "优先找霓虹灯/路灯/橱窗光做面光源。用夜景模式，提醒保持稳定1秒",
            "common_mistakes": ["手抖糊片", "脸上只有顶光导致眼窝一片黑", "闪光灯直打脸太硬"],
        },
    }

    position_tips = {
        "standing": {
            "model": "重心均匀分布在双脚，微收腹，肩膀下沉放松",
            "steps": ["双脚与肩同宽站立", "肩膀向后下沉，挺直背部", "下巴微收，眼神看向镜头或远方", "双手自然垂放或轻触衣物"],
            "voice": ["站直了", "肩膀放下来", "下巴收一点点", "好，看镜头"],
        },
        "cross-leg": {
            "model": "重心放后腿，前腿微弯脚尖点地，形成优雅S曲线",
            "steps": ["重心移向后腿", "前腿膝盖微弯，脚尖轻轻点地", "胯部向一侧微送", "手自然垂放或轻插口袋"],
            "voice": ["重心放后脚", "前脚点地", "胯部放松", "好的，看镜头"],
        },
        "profile-lookback": {
            "model": "身体转45度侧对镜头，头转回来看向镜头，下巴微收",
            "steps": ["身体转45度，侧对镜头方向", "重心放后脚", "头转向镜头，下巴微收", "眼神柔和，带一点点笑意"],
            "voice": ["身体侧过去", "回头看镜头", "下巴低一点", "眼神放松"],
        },
        "jump": {
            "model": "起跳时收腹收紧核心，手臂自然上扬，落地前抓拍",
            "steps": ["微蹲蓄力，手臂后摆", "向上跳起，手臂顺势上扬", "在空中停顿瞬间抓拍", "落地轻缓，膝盖微弯缓冲"],
            "voice": ["蹲下准备", "跳！", "手臂打开", "漂亮！"],
        },
        "sitting": {
            "model": "坐姿挺直背部，双腿自然摆放，手轻放腿上或身体两侧",
            "steps": ["自然坐下，背部挺直", "双腿摆放自然，膝盖微弯", "双手轻放腿上或自然垂放", "抬头，眼神看镜头或远方"],
            "voice": ["坐直了", "腿放松", "手自然放", "看镜头"],
        },
        "walk": {
            "model": "自然走路姿势，步幅适中，手臂自然摆动，不看镜头更自然",
            "steps": ["设定行走路线（约5-8步距离）", "自然步伐，不要刻意大步", "手臂随步伐自然摆动", "眼神看前方或回头看向镜头"],
            "voice": ["开始走", "步伐自然", "回头看镜头", "好的，完美"],
        },
        "spin": {
            "model": "轻轻旋转身体，裙摆自然展开，手臂微张保持平衡",
            "steps": ["站立放松，手臂微张", "以单脚为轴心轻轻旋转", "让裙摆随转身自然展开", "在最佳角度抓拍"],
            "voice": ["准备", "轻轻转", "手臂张开", "漂亮"],
        },
        "crouching": {
            "model": "蹲低身体，保持背部挺直，手自然放膝盖或触地",
            "steps": ["缓慢下蹲，保持背部挺直", "膝盖向两侧打开", "手自然放膝盖上或轻触地面", "抬头看镜头或45度看远方"],
            "voice": ["慢慢蹲下", "背挺直", "抬头看镜头", "好的"],
        },
        "kneeling": {
            "model": "单膝或双膝跪地，上身挺直，手臂自然摆放",
            "steps": ["膝盖轻轻触地", "上身保持挺直", "手自然放腿上或身体两侧", "表情放松，看镜头或远方"],
            "voice": ["膝盖触地", "上身挺直", "手放自然", "看镜头"],
        },
    }

    t = scene_tips.get(scene_key, scene_tips["outdoor"])
    # Match position tips flexibly
    pos_key = "standing"
    for key in position_tips:
        if key in position:
            pos_key = key
            break
    tp = position_tips.get(pos_key, position_tips["standing"])

    # Dynamic pose common mistakes
    dynamic_mistakes = []
    if any(kw in position for kw in ("jump", "walk", "spin", "run", "splash", "kick", "twirl")):
        dynamic_mistakes = ["动作太快导致糊片", "表情没控制好"]

    return {
        "photographer_tips": {"zh": t["photographer"]},
        "model_tips": {"zh": tp.get("model", "保持自然放松的状态")},
        "step_by_step": tp["steps"],
        "voice_guidance": tp["voice"],
        "common_mistakes": t["common_mistakes"] + dynamic_mistakes,
        "key_muscles": ["shoulders_down", "back_straight", "core_engaged"],
    }


def make_camera_params(scene_key: str, position: str, style_tags: list) -> dict:
    """Generate camera parameter suggestions."""
    params = {
        "outdoor": {
            "beginner": {"mode": "portrait", "hdr": "auto", "flash": "off"},
            "advanced": {"iso": 100, "shutter_speed": "1/500", "ev_compensation": -0.3,
                         "white_balance": 5500, "metering_mode": "matrix", "metering_target": "face",
                         "focus_mode": "af-s", "focus_point": "eye"},
        },
        "street": {
            "beginner": {"mode": "portrait", "hdr": "on", "flash": "off"},
            "advanced": {"iso": 200, "shutter_speed": "1/250", "ev_compensation": 0,
                         "white_balance": 5300, "metering_mode": "center", "metering_target": "face",
                         "focus_mode": "af-s", "focus_point": "eye"},
        },
        "indoor": {
            "beginner": {"mode": "portrait", "hdr": "off", "flash": "off"},
            "advanced": {"iso": 400, "shutter_speed": "1/125", "ev_compensation": 0,
                         "white_balance": 4500, "metering_mode": "spot", "metering_target": "face",
                         "focus_mode": "af-s", "focus_point": "eye", "color_profile": "portrait"},
        },
        "beach": {
            "beginner": {"mode": "portrait", "hdr": "on", "flash": "off"},
            "advanced": {"iso": 100, "shutter_speed": "1/500", "ev_compensation": -0.3,
                         "white_balance": 5500, "metering_mode": "matrix", "metering_target": "face",
                         "focus_mode": "af-s", "focus_point": "eye"},
        },
        "night": {
            "beginner": {"mode": "night", "hdr": "auto", "flash": "off"},
            "advanced": {"iso": 800, "shutter_speed": "1/30", "ev_compensation": 0,
                         "white_balance": 4000, "metering_mode": "center", "metering_target": "face",
                         "focus_mode": "af-s", "focus_point": "face", "raw": True},
        },
    }

    base = params.get(scene_key, params["outdoor"])

    # Adjust for dynamic poses
    if any(kw in position for kw in ("jump", "walk", "spin", "run", "splash", "kick", "twirl")):
        base = deepcopy(base)
        base["beginner"]["mode"] = "pro"
        base["advanced"]["shutter_speed"] = "1/1000"
        base["advanced"]["iso"] = min(base["advanced"]["iso"] * 2, 800)
        base["advanced"]["focus_mode"] = "af-c"
        if "jump" in position:
            base["advanced"]["burst"] = True

    return base


# ── Main Generator ───────────────────────────────────────────────

def generate_poses() -> list:
    poses = []

    for seq, (pose_id, body_pos, sub_pos, template, styles, difficulty) in enumerate(POSE_RECIPES, 1):
        scene_key = pose_id.split("-")[0]
        scene_cn = SCENES.get(scene_key, scene_key)
        sub_pos_cn = SUB_POSITION_CN.get(sub_pos, sub_pos)

        skeleton_3d = skeleton_from_template(template)

        # Scene-specific template overrides
        if "mirror" in pose_id and template != "mirror_selfie":
            skeleton_3d = skeleton_from_template("mirror_selfie")
        if "silhouette" in pose_id:
            skeleton_3d = skeleton_from_template("standing_profile")

        guidance = make_guidance(scene_key, sub_pos, styles, difficulty, pose_id)
        camera_params = make_camera_params(scene_key, sub_pos, styles)

        pose_entry = {
            "pose_id": f"{pose_id}-{seq:03d}",
            "version": 1,
            "status": "published",
            "name": {
                "zh": f"{scene_cn}·{sub_pos_cn}",
            },
            "description": {
                "zh": guidance["model_tips"]["zh"],
            },
            "taxonomy": {
                "person_count": "single",
                "body_position": body_pos,
                "sub_position": sub_pos,
                "style": styles,
                "scene_type": [scene_key],
                "difficulty": difficulty,
            },
            "skeleton_3d": {
                "format": "mediapipe_33",
                "keypoints": skeleton_3d,
                "normalization": "body_height_relative",
                "anchor_point": "mid_hip",
            },
            "reference_images": [],
            "guidance": guidance,
            "suitability": {
                "body_types": ["petite", "average", "tall"],
                "clothing": ["dress-skirt", "pants", "shorts", "casual"],
                "lighting": ["front-light", "side-light", "golden-hour"],
                "time_of_day": ["morning", "afternoon", "golden-hour"],
                "focal_length": ["portrait-mode", "standard"],
            },
            "camera_params": camera_params,
            "metadata": {
                "created_at": "2026-05-25T00:00:00Z",
                "created_by": "pose_generator_v2",
                "quality_score": 4.0,
                "popularity_score": 0,
                "usage_count": 0,
                "source": "ai_generated",
                "tags": [scene_key, body_pos, sub_pos] + styles,
            },
        }
        poses.append(pose_entry)

    return poses


# ── Output ───────────────────────────────────────────────────────

def main():
    output_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        "flutter_app", "assets", "poses",
    )
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "local_pose_db.json")

    poses = generate_poses()
    print(f"Generated {len(poses)} poses.")

    from collections import Counter
    scene_counts = Counter(p["taxonomy"]["scene_type"][0] for p in poses)
    for scene, count in sorted(scene_counts.items()):
        print(f"  {scene}: {count} poses")
    body_counts = Counter(p["taxonomy"]["body_position"] for p in poses)
    for pos, count in sorted(body_counts.items()):
        print(f"  {pos}: {count}")
    diff_counts = Counter(p["taxonomy"]["difficulty"] for p in poses)
    print(f"  beginner: {diff_counts.get('beginner', 0)}, intermediate: {diff_counts.get('intermediate', 0)}")

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump({"version": "1.0", "total": len(poses), "poses": poses}, f,
                  ensure_ascii=False, indent=2)

    print(f"Written to {output_path}")
    print(f"File size: {os.path.getsize(output_path) / 1024:.1f} KB")


if __name__ == "__main__":
    main()
