"""Generate 10 LUT presets for Phase 1 post-processing engine.

Produces for each preset:
  - .cube file (33³ 3D LUT, standard format)
  - Hald CLUT .png (level 8, 64×64 pixels)
  - JSON metadata file

All output goes to: src/flutter_app/assets/presets/
"""

import json
import math
import os
import struct
from pathlib import Path

import numpy as np
from PIL import Image

OUT_DIR = Path(__file__).resolve().parent.parent.parent / "flutter_app" / "assets" / "presets"

# ── Hald CLUT helpers ─────────────────────────────────────────────

def generate_identity_hald(level: int = 8) -> np.ndarray:
    """Generate an identity Hald CLUT image (level³ × level³ pixels, 3 channels)."""
    size = level ** 3  # 512 for level 8
    # Image dimensions: level³ × level³ = 512 × 512 for level 8
    # Each row has level³ pixels = 512 pixels, but organized as level² blocks
    # Standard Hald layout: width = level³, height = level³
    # Actually: the standard is width = level² * level, height = level² * level
    # But the most common representation: 512×512 for level 8
    # Actually let me use the standard layout:
    # width = level³ = 512
    # height = level³ = 512
    # Each pixel (x, y) encodes an RGB value
    # x = r * level² + g * level + b (for each r, g, b in 0..level-1)
    # This creates level³ unique RGB combinations

    total = size  # level³
    img = np.zeros((total, total, 3), dtype=np.float32)

    for r in range(level):
        for g in range(level):
            for b in range(level):
                # Input color (normalized)
                x_in = r * level * level + g * level + b
                # Output positions spread across the image
                for r2 in range(level):
                    for g2 in range(level):
                        for b2 in range(level):
                            x_out = r2 * level * level + g2 * level + b2
                            if x_in < total and x_out < total:
                                img[x_out, x_in] = [
                                    r2 / (level - 1),
                                    g2 / (level - 1),
                                    b2 / (level - 1),
                                ]
    return img


def generate_identity_hald_compact(level: int = 8) -> np.ndarray:
    """Generate identity Hald CLUT in standard compact layout.

    The standard format: width = level², height = level²
    Each pixel at (x, y) maps:
      red_idx   = x % level
      green_idx = (x // level) % level
      blue_idx  = y % level
    Total unique colors: level³ spread across a level² × level² grid.
    For level 8: 64×64 image with 512 unique colors.
    """
    l2 = level * level  # 64
    img = np.zeros((l2, l2, 3), dtype=np.float32)

    idx = 0
    for r in range(level):
        for g in range(level):
            for b in range(level):
                y = idx // l2
                x = idx % l2
                if y < l2:
                    img[y, x] = [
                        r / (level - 1),
                        g / (level - 1),
                        b / (level - 1),
                    ]
                idx += 1

    return img


# ── Color transform functions ─────────────────────────────────────

def apply_color_transform(img: np.ndarray, fn) -> np.ndarray:
    """Apply a color transform function to each pixel of the Hald CLUT."""
    result = np.zeros_like(img)
    h, w, _ = img.shape
    for y in range(h):
        for x in range(w):
            r, g, b = img[y, x]
            result[y, x] = fn(r, g, b)
    return np.clip(result, 0.0, 1.0)


def rgb_to_hsl(r: float, g: float, b: float) -> tuple:
    mx = max(r, g, b)
    mn = min(r, g, b)
    l = (mx + mn) / 2.0
    if mx == mn:
        return 0.0, 0.0, l
    d = mx - mn
    s = d / (2.0 - mx - mn) if l > 0.5 else d / (mx + mn) if (mx + mn) > 0 else 0.0
    if mx == r:
        h = ((g - b) / d) % 6.0
    elif mx == g:
        h = (b - r) / d + 2.0
    else:
        h = (r - g) / d + 4.0
    h /= 6.0
    return h % 1.0, s, l


def hsl_to_rgb(h: float, s: float, l: float) -> tuple:
    if s == 0:
        return l, l, l

    def hue_to_rgb(p, q, t):
        if t < 0:
            t += 1.0
        if t > 1.0:
            t -= 1.0
        if t < 1.0 / 6.0:
            return p + (q - p) * 6.0 * t
        if t < 0.5:
            return q
        if t < 2.0 / 3.0:
            return p + (q - p) * (2.0 / 3.0 - t) * 6.0
        return p

    q = l * (1.0 + s) if l < 0.5 else l + s - l * s
    p = 2.0 * l - q
    return (
        hue_to_rgb(p, q, h + 1.0 / 3.0),
        hue_to_rgb(p, q, h),
        hue_to_rgb(p, q, h - 1.0 / 3.0),
    )


# ── Preset definitions ────────────────────────────────────────────

def preset_natural(r, g, b):
    """Natural — slight exposure bump, gentle contrast."""
    return r * 1.05, g * 1.05, b * 1.05


def preset_jp_fresh(r, g, b):
    """Japanese Fresh — lower saturation, higher brightness, cool cyan cast."""
    h, s, l = rgb_to_hsl(r, g, b)
    s *= 0.72          # reduce saturation
    l = l * 1.12 + 0.05  # lift brightness
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Cool tint: reduce red, boost blue slightly
    return out_r * 0.92, out_g * 1.02, out_b * 1.08


def preset_film_warm(r, g, b):
    """Film Warm — warm tone, faded shadows, slight grain feel."""
    # Warm shift: boost red and green, reduce blue
    r2 = r * 1.08 + 0.03
    g2 = g * 1.04 + 0.02
    b2 = b * 0.90
    # Fade shadows (lift blacks)
    h, s, l = rgb_to_hsl(max(r2, 0), max(g2, 0), max(b2, 0))
    l = l * 0.95 + 0.06
    out_r, out_g, out_b = hsl_to_rgb(h, s * 0.90, min(l, 1.0))
    return out_r, out_g, out_b


def preset_bw_high(r, g, b):
    """B&W High Contrast — desaturate, strong contrast curve."""
    # Luminance weights (perceptual)
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    # S-curve for high contrast
    if lum < 0.5:
        lum = 2.0 * lum * lum
    else:
        lum = 1.0 - 2.0 * (1.0 - lum) * (1.0 - lum)
    lum = lum * 1.1 - 0.05  # push extremes
    lum = max(0.0, min(1.0, lum))
    return lum, lum, lum


def preset_warm_portrait(r, g, b):
    """Warm Portrait — smooth skin tones, warm ambiance, slight softness."""
    h, s, l = rgb_to_hsl(r, g, b)
    # Push hue slightly toward warm (reduce blues, boost reds)
    # Warm means shift toward orange/red
    h = (h - 0.03) % 1.0  # slight warm shift
    s *= 0.85             # desaturate slightly for skin smoothness
    l = l * 1.05          # slight brightness lift
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Warm cast
    return out_r * 1.06, out_g * 1.03, out_b * 0.92


def preset_cool_mood(r, g, b):
    """Cool Mood — blue-gray tone, low saturation, moody atmosphere."""
    h, s, l = rgb_to_hsl(r, g, b)
    # Push toward cool (blue/cyan)
    h = (h + 0.05) % 1.0
    s *= 0.65             # lowered saturation
    l = l * 0.92 + 0.02   # slightly darker
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Cool cast: reduce red, boost blue
    return out_r * 0.88, out_g * 0.98, out_b * 1.12


def preset_hk_retro(r, g, b):
    """HK Retro — red-green toning, soft glow, lowered clarity feel."""
    h, s, l = rgb_to_hsl(r, g, b)
    # Vintage warm green-red shift
    h = (h - 0.02) % 1.0
    s *= 0.80
    l = l * 0.95 + 0.04
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Red-green vintage cast
    return out_r * 1.10, out_g * 1.06, out_b * 0.85


def preset_moody_gray(r, g, b):
    """Moody Gray — very low saturation, rich gray scale, premium feel."""
    lum = 0.299 * r + 0.587 * g + 0.114 * b
    h, s, l = rgb_to_hsl(r, g, b)
    s *= 0.28  # significantly desaturate
    l = l * 0.93 + 0.03
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Subtle warm-gray cast
    return out_r * 1.02, out_g * 1.00, out_b * 0.98


def preset_hdr_pop(r, g, b):
    """HDR Pop — enhanced clarity, vivid colors, strong micro-contrast."""
    h, s, l = rgb_to_hsl(r, g, b)
    s *= 1.25   # boost saturation
    # Contrast stretch
    l = (l - 0.5) * 1.20 + 0.5
    out_r, out_g, out_b = hsl_to_rgb(h, min(s, 1.0), max(0.0, min(1.0, l)))
    return out_r, out_g, out_b


def preset_clean_white(r, g, b):
    """Clean White — high-key, bright whites, low contrast, clean and airy."""
    h, s, l = rgb_to_hsl(r, g, b)
    s *= 0.78  # reduce saturation
    l = l * 1.08 + 0.08  # significant brightness lift
    out_r, out_g, out_b = hsl_to_rgb(h, s, min(l, 1.0))
    # Slight cool-blue clean tint
    return out_r * 0.97, out_g * 1.01, out_b * 1.04


PRESETS = {
    "natural":        ("自然",        "Natural",         preset_natural),
    "jp-fresh":       ("日系清新",    "Japanese Fresh",  preset_jp_fresh),
    "film-warm":      ("暖调胶片",    "Warm Film",       preset_film_warm),
    "bw-high":        ("高对比黑白",  "B&W High Contrast", preset_bw_high),
    "warm-portrait":  ("暖调人像",    "Warm Portrait",   preset_warm_portrait),
    "cool-mood":      ("冷调情绪",    "Cool Mood",       preset_cool_mood),
    "hk-retro":       ("复古港风",    "HK Retro",        preset_hk_retro),
    "moody-gray":     ("高级灰",      "Moody Gray",      preset_moody_gray),
    "hdr-pop":        ("HDR强化",     "HDR Pop",         preset_hdr_pop),
    "clean-white":    ("素颜白",      "Clean White",     preset_clean_white),
}

PRESET_METADATA = {
    "natural": {
        "style_tags": ["natural", "clean"],
        "scene_types": ["outdoor-nature", "street", "indoor", "beach"],
        "lighting": ["front-light", "overcast", "soft-light", "golden-hour"],
        "skin_tones": ["fair", "light", "medium", "tan", "dark"],
        "styles": ["natural", "casual", "elegant"],
        "adjustments": {"exposure": 0.05, "contrast": 2, "highlights": -5, "shadows": 5,
            "whites": 0, "blacks": 0, "saturation": 0, "vibrance": 3, "temperature": 0,
            "tint": 0, "sharpness": 2, "noise_reduction": 0, "vignette": -3, "grain": 0},
    },
    "jp-fresh": {
        "style_tags": ["fresh", "clean", "bright", "low-saturation", "cool"],
        "scene_types": ["outdoor-nature", "garden", "beach", "indoor-cafe"],
        "lighting": ["front-light", "overcast", "soft-light"],
        "skin_tones": ["fair", "light", "medium"],
        "styles": ["fresh", "sweet", "natural"],
        "adjustments": {"exposure": 0.20, "contrast": -8, "highlights": -15, "shadows": 12,
            "whites": -5, "blacks": 5, "saturation": -12, "vibrance": -5, "temperature": -300,
            "tint": 5, "sharpness": 0, "noise_reduction": 2, "vignette": -5, "grain": 0},
    },
    "film-warm": {
        "style_tags": ["warm", "vintage", "faded", "grain", "film"],
        "scene_types": ["street", "indoor-cafe", "indoor-home", "night-neon"],
        "lighting": ["back-light", "warm-light", "golden-hour"],
        "skin_tones": ["fair", "light", "medium", "tan"],
        "styles": ["cool", "elegant", "casual"],
        "adjustments": {"exposure": 0.0, "contrast": -5, "highlights": -20, "shadows": 15,
            "whites": -10, "blacks": 10, "saturation": -8, "vibrance": -3, "temperature": 400,
            "tint": 8, "sharpness": -3, "noise_reduction": 0, "vignette": -15, "grain": 8},
    },
    "bw-high": {
        "style_tags": ["black-and-white", "high-contrast", "dramatic", "classic"],
        "scene_types": ["street", "indoor", "night-scene", "urban"],
        "lighting": ["side-light", "hard-light", "back-light"],
        "skin_tones": ["all"],
        "styles": ["cool", "elegant"],
        "adjustments": {"exposure": 0.0, "contrast": 15, "highlights": 10, "shadows": -10,
            "whites": 5, "blacks": -5, "saturation": -100, "vibrance": 0, "temperature": 0,
            "tint": 0, "sharpness": 8, "noise_reduction": 0, "vignette": -10, "grain": 5},
    },
    "warm-portrait": {
        "style_tags": ["warm", "soft", "portrait", "smooth", "glowing"],
        "scene_types": ["indoor", "indoor-home", "indoor-cafe", "golden-hour"],
        "lighting": ["front-light", "soft-light", "warm-light", "window-light"],
        "skin_tones": ["fair", "light", "medium", "tan"],
        "styles": ["sweet", "elegant", "natural"],
        "adjustments": {"exposure": 0.10, "contrast": -5, "highlights": -8, "shadows": 8,
            "whites": -3, "blacks": 3, "saturation": -5, "vibrance": 5, "temperature": 250,
            "tint": 10, "sharpness": -5, "noise_reduction": 5, "vignette": -8, "grain": 0},
    },
    "cool-mood": {
        "style_tags": ["cool", "moody", "blue", "dark", "emotional"],
        "scene_types": ["night-scene", "urban-street", "indoor", "rainy"],
        "lighting": ["low-light", "night", "overcast", "neon"],
        "skin_tones": ["fair", "light", "medium"],
        "styles": ["cool", "elegant"],
        "adjustments": {"exposure": -0.10, "contrast": 5, "highlights": -10, "shadows": -5,
            "whites": -8, "blacks": -3, "saturation": -15, "vibrance": -8, "temperature": -500,
            "tint": -5, "sharpness": 3, "noise_reduction": 2, "vignette": -12, "grain": 3},
    },
    "hk-retro": {
        "style_tags": ["retro", "vintage", "hong-kong", "film", "nostalgic"],
        "scene_types": ["street", "night-neon", "indoor-cafe", "urban"],
        "lighting": ["warm-light", "neon", "night", "back-light"],
        "skin_tones": ["fair", "light", "medium", "tan"],
        "styles": ["cool", "elegant"],
        "adjustments": {"exposure": 0.0, "contrast": -3, "highlights": -15, "shadows": 10,
            "whites": -10, "blacks": 8, "saturation": -10, "vibrance": -5, "temperature": 200,
            "tint": 15, "sharpness": -8, "noise_reduction": 0, "vignette": -10, "grain": 10},
    },
    "moody-gray": {
        "style_tags": ["desaturated", "moody", "gray", "minimal", "premium"],
        "scene_types": ["street", "urban", "indoor", "industrial"],
        "lighting": ["overcast", "soft-light", "side-light"],
        "skin_tones": ["all"],
        "styles": ["cool", "elegant", "casual"],
        "adjustments": {"exposure": 0.0, "contrast": 3, "highlights": -10, "shadows": 10,
            "whites": -5, "blacks": 8, "saturation": -30, "vibrance": -15, "temperature": -100,
            "tint": 0, "sharpness": 5, "noise_reduction": 0, "vignette": -8, "grain": 2},
    },
    "hdr-pop": {
        "style_tags": ["vivid", "sharp", "detailed", "punchy", "dynamic"],
        "scene_types": ["outdoor-nature", "beach", "landscape", "street"],
        "lighting": ["front-light", "golden-hour", "bright-sun"],
        "skin_tones": ["all"],
        "styles": ["natural", "casual"],
        "adjustments": {"exposure": 0.10, "contrast": 10, "highlights": -20, "shadows": 15,
            "whites": 5, "blacks": -5, "saturation": 15, "vibrance": 10, "temperature": 100,
            "tint": 0, "sharpness": 12, "noise_reduction": 0, "vignette": 0, "grain": 0},
    },
    "clean-white": {
        "style_tags": ["bright", "clean", "airy", "soft", "minimal"],
        "scene_types": ["indoor", "indoor-home", "beach", "minimalist"],
        "lighting": ["front-light", "soft-light", "bright", "window-light"],
        "skin_tones": ["fair", "light"],
        "styles": ["fresh", "sweet", "natural"],
        "adjustments": {"exposure": 0.25, "contrast": -10, "highlights": -5, "shadows": 15,
            "whites": 0, "blacks": -10, "saturation": -10, "vibrance": -5, "temperature": -150,
            "tint": 3, "sharpness": -2, "noise_reduction": 3, "vignette": 0, "grain": 0},
    },
}


# ── .cube file generation ─────────────────────────────────────────

def generate_cube_33(preset_fn, filepath: Path):
    """Generate a 33³ .cube LUT file."""
    lines = [
        "# PoseCraft LUT preset",
        "# Generated automatically for Phase 1",
        "",
        "TITLE \"PoseCraft Preset\"",
        "",
        "LUT_3D_SIZE 33",
        "",
        "DOMAIN_MIN 0.0 0.0 0.0",
        "DOMAIN_MAX 1.0 1.0 1.0",
        "",
    ]

    for r_idx in range(33):
        for g_idx in range(33):
            for b_idx in range(33):
                r = r_idx / 32.0
                g = g_idx / 32.0
                b = b_idx / 32.0
                out_r, out_g, out_b = preset_fn(r, g, b)
                lines.append(f"{out_r:.6f} {out_g:.6f} {out_b:.6f}")

    filepath.write_text("\n".join(lines), encoding="utf-8")


def generate_hald_png(preset_fn, filepath: Path, level: int = 8):
    """Generate a Hald CLUT PNG (level² × level² pixels)."""
    identity = generate_identity_hald_compact(level)
    transformed = apply_color_transform(identity, preset_fn)
    # Convert to 8-bit
    img_8bit = (transformed * 255).astype(np.uint8)
    img = Image.fromarray(img_8bit, mode="RGB")
    img.save(filepath, "PNG")


# ── JSON metadata ──────────────────────────────────────────────────

def generate_metadata(preset_id: str, filepath: Path):
    """Generate the JSON metadata file for a preset."""
    name_zh, name_en, _ = PRESETS[preset_id]
    meta = PRESET_METADATA[preset_id]

    doc = {
        "preset_id": preset_id,
        "name": {"zh": name_zh, "en": name_en},
        "version": 1,
        "status": "published",
        "category": "style",
        "style_tags": meta["style_tags"],
        "lut_files": {
            "cube_33": f"assets/presets/{preset_id}.cube",
            "hald_8": f"assets/presets/{preset_id}_hald.png",
        },
        "adjustments": meta["adjustments"],
        "best_for": {
            "scene_types": meta["scene_types"],
            "lighting": meta["lighting"],
            "skin_tones": meta["skin_tones"],
            "styles": meta["styles"],
        },
        "preview_image": f"assets/presets/{preset_id}_preview.jpg",
        "metadata": {
            "author": "posecraft_team",
            "created_at": "2026-05-25T00:00:00Z",
            "usage_count": 0,
            "avg_rating": 0.0,
            "is_premium": False,
            "price": None,
        },
    }

    filepath.write_text(json.dumps(doc, ensure_ascii=False, indent=2), encoding="utf-8")


# ── Preset bundle JSON (all presets index) ─────────────────────────

def generate_bundle_json(filepath: Path):
    """Generate the preset bundle index file (all presets in one JSON)."""
    presets_list = []
    for preset_id, (name_zh, name_en, _) in PRESETS.items():
        meta = PRESET_METADATA[preset_id]
        presets_list.append({
            "preset_id": preset_id,
            "name": {"zh": name_zh, "en": name_en},
            "style_tags": meta["style_tags"],
            "best_for": {
                "scene_types": meta["scene_types"],
                "lighting": meta["lighting"],
                "skin_tones": meta["skin_tones"],
                "styles": meta["styles"],
            },
            "adjustments": meta["adjustments"],
            "lut_files": {
                "cube_33": f"assets/presets/{preset_id}.cube",
                "hald_8": f"assets/presets/{preset_id}_hald.png",
            },
            "metadata": {
                "author": "posecraft_team",
                "is_premium": False,
            },
        })

    bundle = {
        "version": 1,
        "generated_at": "2026-05-25T00:00:00Z",
        "total_presets": len(presets_list),
        "presets": presets_list,
    }

    filepath.write_text(json.dumps(bundle, ensure_ascii=False, indent=2), encoding="utf-8")


# ── Main ───────────────────────────────────────────────────────────

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    print(f"Generating presets → {OUT_DIR}")

    for preset_id, (name_zh, name_en, fn) in PRESETS.items():
        print(f"  {preset_id}: {name_zh} ({name_en})")

        # .cube LUT (33³)
        cube_path = OUT_DIR / f"{preset_id}.cube"
        generate_cube_33(fn, cube_path)
        print(f"    .cube → {cube_path.stat().st_size:,} bytes")

        # Hald CLUT PNG (level 8, 64×64)
        hald_path = OUT_DIR / f"{preset_id}_hald.png"
        generate_hald_png(fn, hald_path)
        print(f"    .png  → {hald_path.stat().st_size:,} bytes")

        # JSON metadata
        meta_path = OUT_DIR / f"{preset_id}.json"
        generate_metadata(preset_id, meta_path)
        print(f"    .json → {meta_path.stat().st_size:,} bytes")

    # Bundle index
    bundle_path = OUT_DIR / "presets_bundle.json"
    generate_bundle_json(bundle_path)
    print(f"  bundle → {bundle_path.stat().st_size:,} bytes")

    print(f"\nDone! {len(PRESETS)} presets generated in {OUT_DIR}")


if __name__ == "__main__":
    main()
