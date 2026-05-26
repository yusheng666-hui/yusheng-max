"""User profile service — JSON file store for Phase 1.

Phase 2 will migrate to PostgreSQL with async SQLAlchemy.
"""

import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from app.schemas.user import UserCreate, UserPreferences, UserOut

_DATA_DIR = Path(__file__).resolve().parent.parent.parent.parent.parent / "data"
_USERS_FILE = _DATA_DIR / "users.json"

# In-memory index for fast access
_users: dict[str, dict] = {}
_loaded = False


def _ensure_loaded():
    global _users, _loaded
    if _loaded:
        return
    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    if _USERS_FILE.exists():
        try:
            data = json.loads(_USERS_FILE.read_text(encoding="utf-8"))
            _users = data.get("users", {})
        except Exception:
            _users = {}
    _loaded = True


def _save():
    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    _USERS_FILE.write_text(
        json.dumps({"users": _users, "updated_at": _now()}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _default_user() -> dict:
    return {
        "username": "",
        "display_name": "",
        "gender": "unspecified",
        "age_range": "18-25",
        "height_cm": 165.0,
        "body_type": "average",
        "face_shape": "oval",
        "skin_tone": "medium",
        "preferred_styles": ["natural", "fresh"],
        "preferred_difficulty": "beginner",
        "photography_level": "beginner",
        "quality_score": 5.0,
        "total_sessions": 0,
        "total_photos": 0,
        "created_at": _now(),
        "updated_at": _now(),
    }


def create_user(data: UserCreate) -> UserOut:
    """Register a new user."""
    _ensure_loaded()
    user_id = f"u{ uuid.uuid4().hex[:12]}"
    record = _default_user()
    record.update({
        "user_id": user_id,
        "username": data.username or user_id,
        "display_name": data.display_name or f"用户_{user_id[-4:]}",
        "gender": data.gender,
        "age_range": data.age_range,
        "height_cm": data.height_cm,
        "body_type": data.body_type,
        "face_shape": data.face_shape,
        "skin_tone": data.skin_tone,
        "preferred_styles": data.preferred_styles,
        "preferred_difficulty": data.preferred_difficulty,
        "photography_level": data.photography_level,
        "created_at": _now(),
        "updated_at": _now(),
    })
    _users[user_id] = record
    _save()
    return UserOut(**record)


def get_user(user_id: str) -> Optional[UserOut]:
    """Fetch a user by ID."""
    _ensure_loaded()
    record = _users.get(user_id)
    if record is None:
        return None
    return UserOut(**record)


def update_preferences(user_id: str, prefs: UserPreferences) -> Optional[UserOut]:
    """Update user style/difficulty preferences."""
    _ensure_loaded()
    record = _users.get(user_id)
    if record is None:
        return None

    if prefs.preferred_styles is not None:
        record["preferred_styles"] = prefs.preferred_styles
    if prefs.preferred_difficulty is not None:
        record["preferred_difficulty"] = prefs.preferred_difficulty
    if prefs.photography_level is not None:
        record["photography_level"] = prefs.photography_level

    record["updated_at"] = _now()
    _users[user_id] = record
    _save()
    return UserOut(**record)


def increment_session(user_id: str):
    """Increment the user's session counter."""
    _ensure_loaded()
    record = _users.get(user_id)
    if record:
        record["total_sessions"] = record.get("total_sessions", 0) + 1
        record["updated_at"] = _now()
        _save()


def increment_photos(user_id: str, count: int = 1):
    """Increment the user's photo counter."""
    _ensure_loaded()
    record = _users.get(user_id)
    if record:
        record["total_photos"] = record.get("total_photos", 0) + count
        record["updated_at"] = _now()
        _save()


def update_quality_score(user_id: str, new_score: float):
    """Update the rolling average quality score."""
    _ensure_loaded()
    record = _users.get(user_id)
    if record:
        old = record.get("quality_score", 5.0)
        total = record.get("total_photos", 1) or 1
        # Exponential moving average: 70% old + 30% new
        record["quality_score"] = round(old * 0.7 + new_score * 0.3, 2)
        _save()
