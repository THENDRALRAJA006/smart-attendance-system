# ============================================================
# SmartAttend — Backend Production Dockerfile
# Python 3.12 · FastAPI · Uvicorn (multi-worker)
# Connects to AWS RDS MySQL — no bundled database
# ============================================================

FROM python:3.12-slim

# ─── Build args ──────────────────────────────────────────────
ARG PORT=8000

# ─── System dependencies ─────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    && rm -rf /var/lib/apt/lists/*

# ─── Working directory ───────────────────────────────────────
WORKDIR /app

# ─── Install Python dependencies first (for layer caching) ──
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ─── Copy application code ───────────────────────────────────
COPY . .

# ─── Create non-root user (security best practice) ──────────
RUN addgroup --system smartattend \
    && adduser --system --ingroup smartattend smartattend \
    && chown -R smartattend:smartattend /app
USER smartattend

# ─── Expose API port ─────────────────────────────────────────
EXPOSE $PORT

# ─── Health check ────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# ─── Start server ────────────────────────────────────────────
# 4 workers for production; Render sets $PORT automatically
CMD ["sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 4 --log-level info"]
