# ============================================================
# SmartAttend — App Configuration (Pydantic Settings)
# ============================================================

from pydantic_settings import BaseSettings
from pydantic import field_validator
from functools import lru_cache


class Settings(BaseSettings):
    # ─── App ──────────────────────────────────────────────
    APP_NAME: str = "SmartAttend"
    APP_ENV: str = "development"
    APP_BASE_URL: str = "http://localhost:8000"

    # ─── Database ──────────────────────────────────────────
    # Values are read from environment variables or backend/.env file.
    # Defaults below are safe fallbacks — override via Render Dashboard for production.
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "smart_attendance"
    DB_USER: str = "root"
    DB_PASSWORD: str = ""     # ← set in Render Dashboard → Environment (never hardcode)

    @property
    def DATABASE_URL(self) -> str:
        return (
            f"mysql+pymysql://{self.DB_USER}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
        )

    # ─── JWT ───────────────────────────────────────────────
    JWT_SECRET_KEY: str = "change-me-in-production"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_HOURS: int = 24

    JWT_REFRESH_SECRET_KEY: str = "change-me-refresh-in-production"
    JWT_REFRESH_EXPIRE_DAYS: int = 7

    # ─── CORS ──────────────────────────────────────────────
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    # ─── ArcFace (InsightFace) ─────────────────────────────
    # Cosine similarity thresholds (0.0–1.0 range, NOT percentages)
    # >= ARCFACE_SIMILARITY_THRESHOLD → "present"
    # >= ARCFACE_REVIEW_THRESHOLD     → "manual_review"
    # <  ARCFACE_REVIEW_THRESHOLD     → "rejected"
    ARCFACE_SIMILARITY_THRESHOLD: float = 0.75
    ARCFACE_REVIEW_THRESHOLD: float = 0.65
    ARCFACE_MODEL_PATH: str = "~/.insightface"

    @field_validator("ARCFACE_SIMILARITY_THRESHOLD", "ARCFACE_REVIEW_THRESHOLD")
    @classmethod
    def validate_similarity_threshold(cls, v: float) -> float:
        if not (0.0 <= v <= 1.0):
            raise ValueError("ArcFace similarity thresholds must be between 0.0 and 1.0")
        return v

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
