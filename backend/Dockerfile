# ============================================================
# SmartAttend — Backend Production Dockerfile
# Python 3.12 · FastAPI · Uvicorn (multi-worker)
# Connects to AWS RDS MySQL — no bundled database
# ============================================================

FROM python:3.12-slim

# ─── Build args ──────────────────────────────────────────────
ARG PORT=8000

# ─── System dependencies ─────────────────────────────────────
# We install compiler tools (build-essential, gcc, g++, cmake, python3-dev)
# required to compile insightface Cython extensions, and graphics
# run-time libraries (libglib2.0-0, libgl1) for OpenCV.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    cmake \
    python3-dev \
    default-libmysqlclient-dev \
    pkg-config \
    curl \
    libglib2.0-0 \
    libgl1 \
    && rm -rf /var/lib/apt/lists/*

# ─── Working directory ───────────────────────────────────────
WORKDIR /app

# ─── Install Python dependencies first (for layer caching) ──
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y opencv-python opencv-python-headless && \
    pip install --no-cache-dir opencv-python-headless==4.10.0.84

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
CMD ["sh", "-c", "alembic upgrade head && uvicorn main:app --host 0.0.0.0 --port $PORT --log-level info"]
