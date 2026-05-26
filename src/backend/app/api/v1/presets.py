"""Preset recommendation API endpoints.

Phase 1: returns ranked presets based on scene type and photo features.
Uses the local preset bundle (10 built-in presets) for matching.
"""

import json
from pathlib import Path

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/presets", tags=["presets"])

# Resolve preset bundle path
_PRESET_BUNDLE_PATH = (
    Path(__file__).resolve().parent.parent.parent.parent.parent
    / "flutter_app"
    / "assets"
    / "presets"
    / "presets_bundle.json"
)

_presets_cache: list[dict] | None = None


def _load_presets() -> list[dict]:
    global _presets_cache
    if _presets_cache is not None:
        return _presets_cache
    try:
        data = json.loads(_PRESET_BUNDLE_PATH.read_text(encoding="utf-8"))
        _presets_cache = data.get("presets", [])
        return _presets_cache
    except Exception:
        _presets_cache = []
        return _presets_cache


# ── Schemas ──────────────────────────────────────────────────────


class PhotoFeatures(BaseModel):
    brightness_mean: float = Field(default=0.5, ge=0.0, le=1.0)
    saturation_mean: float = Field(default=0.5, ge=0.0, le=1.0)
    contrast_rms: float = Field(default=0.3, ge=0.0, le=1.0)
    color_temp_hint: str = Field(default="neutral", description="One of: warm, cool, neutral")
    skin_tone: str = Field(default="medium", description="One of: fair, light, medium, tan, dark")
    scene_class: str = Field(default="outdoor-nature")
    lighting: str = Field(default="front-light")


class PresetRecommendRequest(BaseModel):
    request_id: str = Field(default="preset-001")
    photo_features: PhotoFeatures = Field(default_factory=PhotoFeatures)
    user_styles: list[str] = Field(default_factory=lambda: ["natural"])
    top_k: int = Field(default=3, ge=1, le=10)


class PresetOut(BaseModel):
    preset_id: str
    name: dict
    style_tags: list[str]
    adjustments: dict
    score: float
    match_reason: str


class PresetRecommendResponse(BaseModel):
    request_id: str
    recommendations: list[PresetOut]
    total_available: int


# ── Matching logic ───────────────────────────────────────────────


def _match_presets(
    features: PhotoFeatures,
    user_styles: list[str],
    top_k: int,
) -> list[PresetOut]:

    presets = _load_presets()
    if not presets:
        return []

    scored = []
    for p in presets:
        score = 0.0
        reasons = []

        bf = p.get("best_for", {})

        # 1. Scene match (40%)
        if features.scene_class in bf.get("scene_types", []):
            score += 0.40
            reasons.append("场景匹配")
        elif any(
            features.scene_class in st or st in features.scene_class
            for st in bf.get("scene_types", [])
        ):
            score += 0.25
            reasons.append("场景部分匹配")

        # 2. Lighting match (20%)
        if features.lighting in bf.get("lighting", []):
            score += 0.20
            reasons.append("光线匹配")

        # 3. Skin tone match (15%)
        if features.skin_tone in bf.get("skin_tones", []) or "all" in bf.get("skin_tones", []):
            score += 0.15
            reasons.append("肤色匹配")

        # 4. Color temperature alignment (15%)
        adj = p.get("adjustments", {})
        temp = adj.get("temperature", 0)
        if features.color_temp_hint == "cool" and temp < -100:
            score += 0.15
            reasons.append("冷调一致")
        elif features.color_temp_hint == "warm" and temp > 100:
            score += 0.15
            reasons.append("暖调一致")
        elif features.color_temp_hint == "neutral" and abs(temp) < 150:
            score += 0.15
            reasons.append("中性调匹配")

        # 5. User style preference (10%)
        for us in user_styles:
            if us in p.get("style_tags", []) or us in bf.get("styles", []):
                score += 0.10
                reasons.append(f"偏好:{us}")
                break

        if score > 0:
            scored.append((p, score, ", ".join(reasons)))

    scored.sort(key=lambda x: x[1], reverse=True)
    top = scored[:top_k]

    return [
        PresetOut(
            preset_id=p["preset_id"],
            name=p["name"],
            style_tags=p.get("style_tags", []),
            adjustments=p.get("adjustments", {}),
            score=round(s, 3),
            match_reason=r,
        )
        for p, s, r in top
    ]


# ── Routes ───────────────────────────────────────────────────────


@router.post("/recommend", response_model=PresetRecommendResponse)
def recommend_presets(req: PresetRecommendRequest):
    """Recommend top-k presets for a given photo and user context."""
    results = _match_presets(req.photo_features, req.user_styles, req.top_k)
    return PresetRecommendResponse(
        request_id=req.request_id,
        recommendations=results,
        total_available=len(_load_presets()),
    )


@router.get("", response_model=dict)
def list_presets(
    scene: str | None = None,
    style: str | None = None,
):
    """List all available presets, optionally filtered by scene or style."""
    presets = _load_presets()
    filtered = presets

    if scene:
        filtered = [p for p in filtered if scene in p.get("best_for", {}).get("scene_types", [])]
    if style:
        filtered = [p for p in filtered if style in p.get("style_tags", [])]

    return {
        "total": len(filtered),
        "presets": [
            {
                "preset_id": p["preset_id"],
                "name": p["name"],
                "style_tags": p.get("style_tags", []),
                "best_for": p.get("best_for", {}),
            }
            for p in filtered
        ],
    }


@router.get("/health")
def health():
    return {"status": "ok", "total_presets": len(_load_presets())}


@router.get("/{preset_id}", response_model=dict)
def get_preset(preset_id: str):
    """Get full details for a single preset."""
    presets = _load_presets()
    for p in presets:
        if p["preset_id"] == preset_id:
            return p
    raise HTTPException(status_code=404, detail=f"Preset '{preset_id}' not found")
