# ============================================================
# SmartAttend — Database Engine & Session Factory
# ============================================================

from sqlalchemy import create_engine, event
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator
from .config import settings

# ─── Engine ─────────────────────────────────────────────────
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,          # Reconnect dropped connections
    pool_size=3,                 # Reduced: Render 1-worker + RDS free tier
    max_overflow=5,              # Reduced: max 8 total connections
    pool_recycle=300,            # Recycle every 5min (handles Render restarts)
    pool_timeout=30,             # Wait max 30s for a connection
    echo=settings.APP_ENV == "development",
)

# ─── Session Factory ─────────────────────────────────────────
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ─── Base Model ──────────────────────────────────────────────
Base = declarative_base()


# ─── Dependency: get_db ──────────────────────────────────────
def get_db() -> Generator[Session, None, None]:
    """FastAPI dependency that yields a database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db() -> None:
    """Create all tables (called on startup)."""
    # Import all models so they register with Base
    from app.models import models  # noqa: F401
    Base.metadata.create_all(bind=engine)
