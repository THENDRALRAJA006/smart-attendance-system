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
    pool_size=10,
    max_overflow=20,
    pool_recycle=3600,           # Recycle connections every hour
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
