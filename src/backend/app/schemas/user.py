"""User Pydantic schemas for request/response validation."""

from pydantic import BaseModel, Field


class UserCreate(BaseModel):
    """Registration / first-time setup."""

    username: str = Field(default="", max_length=50)
    display_name: str = Field(default="", max_length=50)
    gender: str = Field(default="unspecified", pattern=r"^(male|female|unspecified)$")
    age_range: str = Field(default="18-25")
    height_cm: float = Field(default=165.0, ge=100.0, le=250.0)
    body_type: str = Field(default="average")
    face_shape: str = Field(default="oval")
    skin_tone: str = Field(default="medium")
    preferred_styles: list[str] = Field(default_factory=lambda: ["natural", "fresh"])
    preferred_difficulty: str = Field(default="beginner")
    photography_level: str = Field(
        default="beginner", description="One of: beginner, hobbyist, advanced, professional"
    )


class UserPreferences(BaseModel):
    """Updateable style/difficulty preferences."""

    preferred_styles: list[str] | None = None
    preferred_difficulty: str | None = None
    photography_level: str | None = None


class UserOut(BaseModel):
    """Public user profile response."""

    user_id: str
    username: str
    display_name: str
    gender: str
    age_range: str
    height_cm: float
    body_type: str
    face_shape: str
    skin_tone: str
    preferred_styles: list[str]
    preferred_difficulty: str
    photography_level: str
    quality_score: float
    total_sessions: int
    total_photos: int
    created_at: str
    updated_at: str

    class Config:
        from_attributes = True


class UserSummary(BaseModel):
    """Minimal user info for recommendation context."""

    user_id: str
    preferred_styles: list[str]
    preferred_difficulty: str
    photography_level: str
    height_cm: float
    skin_tone: str
