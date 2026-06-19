# ============================================================
# SmartAttend — App Configuration (Pydantic Settings)
# ============================================================

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # ─── App ──────────────────────────────────────────────
    APP_NAME: str = "SmartAttend"
    APP_ENV: str = "development"
    APP_BASE_URL: str = "http://localhost:8000"

    # ─── Database ──────────────────────────────────────────
    DB_HOST: str = "localhost"
    DB_PORT: int = 3306
    DB_NAME: str = "smart_attendance"
    DB_USER: str = "root"
    DB_PASSWORD: str = ""

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
    FACE_CONFIDENCE_THRESHOLD: float = 90.0

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache()
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
