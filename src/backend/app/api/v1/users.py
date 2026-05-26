"""User profile API endpoints — Phase 1 with JSON file store."""

from fastapi import APIRouter, HTTPException

from app.schemas.user import UserCreate, UserPreferences, UserOut
from app.domain.user import service as user_svc

router = APIRouter()


@router.post("/users/register", response_model=UserOut)
def register(data: UserCreate):
    """Register a new user or set up profile for the first time."""
    try:
        return user_svc.create_user(data)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/users/me", response_model=UserOut)
def get_my_profile(user_id: str = "u000000000001"):
    """Fetch the current user's profile.

    Phase 1: user_id is passed as a query param (no auth middleware yet).
    Phase 2: extract from JWT token.
    """
    user = user_svc.get_user(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail=f"User '{user_id}' not found")
    return user


@router.patch("/users/me/preferences", response_model=UserOut)
def update_preferences(prefs: UserPreferences, user_id: str = "u000000000001"):
    """Update user style/difficulty preferences.

    Called when the user fills in or updates the style questionnaire.
    """
    user = user_svc.update_preferences(user_id, prefs)
    if user is None:
        raise HTTPException(status_code=404, detail=f"User '{user_id}' not found")
    return user


@router.post("/users/me/session")
def log_session(user_id: str = "u000000000001"):
    """Increment the user's session count."""
    user_svc.increment_session(user_id)
    return {"status": "ok", "user_id": user_id}
