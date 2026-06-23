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

    # ─── AWS ───────────────────────────────────────────────
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    AWS_REGION: str = "ap-southeast-2"
    AWS_REKOGNITION_COLLECTION_ID: str = "smart-attendance-faces"

    # ─── S3 ────────────────────────────────────────────────
    S3_BUCKET_NAME: str = "smart-attendance-faces-thendral"
    S3_FACE_PREFIX: str = "faces"

    # ─── CORS ──────────────────────────────────────────────
    ALLOWED_ORIGINS: str = "http://localhost:3000,http://localhost:8080"

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    # ─── Face Recognition ──────────────────────────────────
    FACE_MATCH_THRESHOLD: float = 90.0

    @field_validator("FACE_MATCH_THRESHOLD")
    @classmethod
    def validate_threshold(cls, v: float) -> float:
        if v not in (80.0, 85.0, 90.0):
            raise ValueError("FACE_MATCH_THRESHOLD must be 80.0, 85.0, or 90.0")
        return v

    @property
    def FACE_CONFIDENCE_THRESHOLD(self) -> float:
        return self.FACE_MATCH_THRESHOLD

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
