# ============================================================
# SmartAttend — Alembic Environment Configuration
# Reads DATABASE_URL from app settings (AWS RDS MySQL)
# ============================================================

from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os, sys

# Add parent directory to path so we can import our app
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Import all models so Alembic can detect them
from app.core.database import Base
from app.core.config import settings
import app.models.models  # noqa: F401 — ensures all tables are registered

# ─── Alembic Config ──────────────────────────────────────────
config = context.config

# Inject the database URL from our settings (overrides alembic.ini)
config.set_main_option("sqlalchemy.url", settings.DATABASE_URL + "?charset=utf8mb4")

# ─── Logging ─────────────────────────────────────────────────
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# ─── Target metadata ─────────────────────────────────────────
target_metadata = Base.metadata


# ─── Offline migration ───────────────────────────────────────
def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode (generates SQL without connecting)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


# ─── Online migration ────────────────────────────────────────
def run_migrations_online() -> None:
    """Run migrations in 'online' mode (connects to live database)."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


# ─── Entry point ─────────────────────────────────────────────
if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
