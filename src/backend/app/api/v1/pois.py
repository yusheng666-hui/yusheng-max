"""POI (Points of Interest) endpoint — nearby photo spots.

Phase 1: static seed dataset. Phase 2: real geospatial queries via PostGIS.
"""

import math
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

router = APIRouter()

# ── Seed POI dataset (20 iconic Chinese photo spots) ─────────────

_SEED_POIS = [
    {"poi_id": "poi-001", "name_zh": "西湖断桥", "latitude": 30.2592, "longitude": 120.1460, "category": "scenic", "style_tags": ["natural", "elegant"], "best_times": ["sunrise", "sunset"], "scene_types": ["outdoor", "beach"], "photo_tips_zh": "清晨或黄昏时分拍摄最佳，利用湖面倒影构图", "rating": 4.8},
    {"poi_id": "poi-002", "name_zh": "上海外滩", "latitude": 31.2400, "longitude": 121.4900, "category": "urban", "style_tags": ["cool", "elegant"], "best_times": ["night", "sunset"], "scene_types": ["urban", "night"], "photo_tips_zh": "夜景拍摄建议使用三脚架，以陆家嘴天际线为背景", "rating": 4.7},
    {"poi_id": "poi-003", "name_zh": "故宫太和殿", "latitude": 39.9160, "longitude": 116.3970, "category": "landmark", "style_tags": ["elegant", "cool"], "best_times": ["morning", "afternoon"], "scene_types": ["outdoor"], "photo_tips_zh": "站在太和殿前广场利用对称构图，穿汉服效果更佳", "rating": 4.9},
    {"poi_id": "poi-004", "name_zh": "成都宽窄巷子", "latitude": 30.6640, "longitude": 104.0510, "category": "urban", "style_tags": ["casual", "natural"], "best_times": ["afternoon", "sunset"], "scene_types": ["street"], "photo_tips_zh": "巷子里的青砖灰瓦很适合清新文艺风格", "rating": 4.5},
    {"poi_id": "poi-005", "name_zh": "厦门鼓浪屿", "latitude": 24.4480, "longitude": 118.0680, "category": "scenic", "style_tags": ["fresh", "sweet"], "best_times": ["morning", "sunset"], "scene_types": ["beach", "outdoor"], "photo_tips_zh": "日光岩上可拍全岛风光，小巷里的老别墅适合清新风", "rating": 4.6},
    {"poi_id": "poi-006", "name_zh": "桂林漓江", "latitude": 25.2740, "longitude": 110.2900, "category": "nature", "style_tags": ["natural", "fresh"], "best_times": ["sunrise", "morning"], "scene_types": ["outdoor"], "photo_tips_zh": "清晨薄雾时分最适合拍摄山水倒影", "rating": 4.7},
    {"poi_id": "poi-007", "name_zh": "丽江古城", "latitude": 26.8720, "longitude": 100.2330, "category": "urban", "style_tags": ["natural", "casual"], "best_times": ["sunset", "night"], "scene_types": ["street", "night"], "photo_tips_zh": "四方街和木府是经典取景地，傍晚灯笼亮起时很有氛围", "rating": 4.5},
    {"poi_id": "poi-008", "name_zh": "三亚亚龙湾", "latitude": 18.2260, "longitude": 109.6460, "category": "scenic", "style_tags": ["fresh", "sweet"], "best_times": ["morning", "sunset"], "scene_types": ["beach"], "photo_tips_zh": "逆光拍摄剪影效果，顺光则适合拍蓝天碧海", "rating": 4.4},
    {"poi_id": "poi-009", "name_zh": "西安大雁塔", "latitude": 34.2190, "longitude": 108.9590, "category": "landmark", "style_tags": ["elegant", "cool"], "best_times": ["sunset", "night"], "scene_types": ["outdoor", "night"], "photo_tips_zh": "音乐喷泉广场适合广角拍摄，夜晚有灯光秀", "rating": 4.6},
    {"poi_id": "poi-010", "name_zh": "哈尔滨冰雪大世界", "latitude": 45.7770, "longitude": 126.6170, "category": "landmark", "style_tags": ["cool", "elegant"], "best_times": ["night"], "scene_types": ["night"], "photo_tips_zh": "冰雕在灯光下最出彩，注意相机保暖和曝光补偿", "rating": 4.3},
    {"poi_id": "poi-011", "name_zh": "苏州园林拙政园", "latitude": 31.3260, "longitude": 120.6240, "category": "landmark", "style_tags": ["elegant", "natural"], "best_times": ["morning", "afternoon"], "scene_types": ["outdoor"], "photo_tips_zh": "利用框景构图，透过花窗拍摄别有韵味", "rating": 4.7},
    {"poi_id": "poi-012", "name_zh": "张家界天门山", "latitude": 29.1270, "longitude": 110.4770, "category": "nature", "style_tags": ["cool", "natural"], "best_times": ["sunrise", "morning"], "scene_types": ["outdoor"], "photo_tips_zh": "云海天气时拍摄如入仙境，玻璃栈道上俯拍效果震撼", "rating": 4.6},
    {"poi_id": "poi-013", "name_zh": "重庆洪崖洞", "latitude": 29.5650, "longitude": 106.5830, "category": "urban", "style_tags": ["cool", "elegant"], "best_times": ["night"], "scene_types": ["night", "urban"], "photo_tips_zh": "从千厮门大桥对面拍摄洪崖洞全景最为壮观", "rating": 4.8},
    {"poi_id": "poi-014", "name_zh": "大理洱海", "latitude": 25.6080, "longitude": 100.2490, "category": "scenic", "style_tags": ["fresh", "natural"], "best_times": ["sunrise", "sunset"], "scene_types": ["outdoor", "beach"], "photo_tips_zh": "环海公路上的白色桌椅是经典打卡点", "rating": 4.6},
    {"poi_id": "poi-015", "name_zh": "青岛八大关", "latitude": 36.0580, "longitude": 120.3420, "category": "urban", "style_tags": ["elegant", "fresh"], "best_times": ["morning", "afternoon"], "scene_types": ["street"], "photo_tips_zh": "秋天银杏落叶时最出片，欧式建筑群做背景很有格调", "rating": 4.4},
    {"poi_id": "poi-016", "name_zh": "拉萨布达拉宫", "latitude": 29.6580, "longitude": 91.1170, "category": "landmark", "style_tags": ["cool", "elegant"], "best_times": ["sunrise", "sunset"], "scene_types": ["outdoor"], "photo_tips_zh": "从药王山观景台拍摄布宫正面全景，50元人民币同款角度", "rating": 4.9},
    {"poi_id": "poi-017", "name_zh": "北京798艺术区", "latitude": 39.9840, "longitude": 116.4950, "category": "urban", "style_tags": ["cool", "casual"], "best_times": ["afternoon"], "scene_types": ["street"], "photo_tips_zh": "工业风背景搭配涂鸦墙，适合酷帅和个性风格", "rating": 4.3},
    {"poi_id": "poi-018", "name_zh": "黄山迎客松", "latitude": 30.1360, "longitude": 118.1670, "category": "nature", "style_tags": ["natural", "elegant"], "best_times": ["sunrise", "morning"], "scene_types": ["outdoor"], "photo_tips_zh": "日出时云海翻涌，迎客松作为前景构图极为经典", "rating": 4.8},
    {"poi_id": "poi-019", "name_zh": "广州塔", "latitude": 23.1060, "longitude": 113.3240, "category": "landmark", "style_tags": ["cool", "elegant"], "best_times": ["night"], "scene_types": ["night", "urban"], "photo_tips_zh": "花城广场正面拍摄塔身全貌，彩色灯光变幻时最出彩", "rating": 4.5},
    {"poi_id": "poi-020", "name_zh": "南京夫子庙", "latitude": 32.0230, "longitude": 118.7900, "category": "urban", "style_tags": ["elegant", "natural"], "best_times": ["night", "sunset"], "scene_types": ["street", "night"], "photo_tips_zh": "秦淮河夜游船只与灯火楼阁构成绝美画面", "rating": 4.4},
]


class POIOut(BaseModel):
    poi_id: str
    name_zh: str
    latitude: float
    longitude: float
    category: str
    style_tags: list[str]
    best_times: list[str]
    scene_types: list[str]
    photo_tips_zh: str
    rating: float
    distance_km: float = 0.0


class NearbyPOIResponse(BaseModel):
    center: dict
    radius_km: float
    total: int
    pois: list[POIOut]


class POIListResponse(BaseModel):
    total: int
    pois: list[POIOut]


# ── Helpers ───────────────────────────────────────────────────────


def _haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Haversine distance in km."""
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


# ── Endpoints ─────────────────────────────────────────────────────


@router.get("/poi/nearby", response_model=NearbyPOIResponse)
async def get_nearby_pois(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude"),
    radius_km: float = Query(default=50.0, ge=0.1, le=10000.0, description="Search radius in km"),
    category: str = Query(default="", description="Filter by category"),
    style: str = Query(default="", description="Filter by style tag"),
    limit: int = Query(default=10, ge=1, le=50),
):
    """Return nearby photo spots sorted by distance."""
    scored = []
    for poi in _SEED_POIS:
        dist = _haversine(lat, lon, poi["latitude"], poi["longitude"])
        if dist <= radius_km:
            if category and poi["category"] != category:
                continue
            if style and style not in poi["style_tags"]:
                continue
            scored.append((dist, poi))

    scored.sort(key=lambda x: x[0])

    return {
        "center": {"lat": lat, "lon": lon},
        "radius_km": radius_km,
        "total": len(scored),
        "pois": [
            POIOut(
                poi_id=p["poi_id"],
                name_zh=p["name_zh"],
                latitude=p["latitude"],
                longitude=p["longitude"],
                category=p["category"],
                style_tags=p["style_tags"],
                best_times=p["best_times"],
                scene_types=p["scene_types"],
                photo_tips_zh=p["photo_tips_zh"],
                rating=p["rating"],
                distance_km=round(d, 1),
            )
            for d, p in scored[:limit]
        ],
    }


@router.get("/poi/{poi_id}")
async def get_poi_detail(poi_id: str):
    """Get full detail for a single POI."""
    for poi in _SEED_POIS:
        if poi["poi_id"] == poi_id:
            return poi
    raise HTTPException(status_code=404, detail=f"POI '{poi_id}' not found")


@router.get("/poi", response_model=POIListResponse)
async def list_pois(
    category: str = Query(default=""),
    style: str = Query(default=""),
):
    """List all POIs with optional filters."""
    filtered = _SEED_POIS
    if category:
        filtered = [p for p in filtered if p["category"] == category]
    if style:
        filtered = [p for p in filtered if style in p["style_tags"]]
    return {
        "total": len(filtered),
        "pois": [
            POIOut(
                poi_id=p["poi_id"],
                name_zh=p["name_zh"],
                latitude=p["latitude"],
                longitude=p["longitude"],
                category=p["category"],
                style_tags=p["style_tags"],
                best_times=p["best_times"],
                scene_types=p["scene_types"],
                photo_tips_zh=p["photo_tips_zh"],
                rating=p["rating"],
                distance_km=0.0,
            )
            for p in filtered
        ],
    }
