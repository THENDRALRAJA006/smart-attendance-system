# ============================================================
# SmartAttend — FastAPI Application Entry Point
# ============================================================

import gc
import logging
import traceback
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute

from app.core.config import settings
from app.core.database import init_db
from app.routes import auth, student, faculty, admin, attendance
from fastapi.staticfiles import StaticFiles
import os

# ─── Logging ─────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO if settings.APP_ENV == "production" else logging.DEBUG,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


# ─── Unique OpenAPI Operation ID Generator ─────────────────────────
# Builds operation_id as "{tag}_{function_name}" for every route
# that does NOT already have an explicit operation_id set.
# Falls back to explicit operation_id when present.
def _generate_unique_id(route: APIRoute) -> str:
    if route.operation_id:
        return route.operation_id
    tag = route.tags[0] if route.tags else "default"
    # Normalize: lowercase, spaces → underscores
    tag_slug = tag.lower().replace(" ", "_")
    return f"{tag_slug}_{route.name}"


# ─── Startup / Shutdown ──────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup."""
    logger.info("🚀 SmartAttend API starting...")

    # Create DB tables
    init_db()
    logger.info("✅ Database tables initialized")

    # ── Warm up ArcFace model at startup (not on first request) ──
    # This ensures OOM crash is visible in startup logs, not mid-request.
    # face_service.py already calls get_face_analysis_app() at import time,
    # so this is a no-op if model already loaded, but guarantees warm-up.
    try:
        from app.services.face_service import get_face_analysis_app
        get_face_analysis_app()   # returns existing singleton
        gc.collect()              # reclaim any fragmented init memory
        logger.info("✅ ArcFace model ready")
    except Exception as e:
        logger.error(f"⚠️  ArcFace model warm-up failed: {e}")
        # Don't abort startup — let /health report the error

    logger.info("✅ SmartAttend API ready")
    yield

    logger.info("👋 SmartAttend API shutting down...")


# ─── FastAPI App ─────────────────────────────────────────────
app = FastAPI(
    title="SmartAttend API",
    description="""
    ## SmartAttend AI — Intelligent Attendance System

    A secure, multi-factor attendance system using:
    - **BLE** (ESP32 beacons) for proximity verification
    - **ArcFace (InsightFace)** for local face verification (auto-capture registration, cosine similarity)
    - **Anti-spoofing liveness** (BLINK / SMILE / TURN_LEFT / TURN_RIGHT challenges)
    - **JWT** for authentication
    - **Zero cloud dependency** for face recognition — fully on-device embeddings

    ### Similarity Tiers
    - `>= 0.75` → **present** (auto-marked)
    - `0.65 – 0.74` → **manual_review** (marked, flagged for faculty)
    - `< 0.65` → **rejected**

    ### Roles
    - **Student**: Register, mark attendance, view history
    - **Faculty**: Create sessions, generate QR codes, view reports
    - **Admin**: System management, analytics
    """,
    version="5.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
    generate_unique_id_function=_generate_unique_id,
)


# ─── Middleware ───────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex="https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


# ─── Routers ─────────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(student.router)
app.include_router(faculty.router)
app.include_router(admin.router)
app.include_router(attendance.router)

# Mount static files directory
os.makedirs("static/faces", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")


# ─── Global Exception Handler ────────────────────────────────
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Catch any unhandled exception and return structured JSON + log full traceback."""
    tb = traceback.format_exc()
    logger.error(
        f"Unhandled exception on {request.method} {request.url}\n{tb}"
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "error": type(exc).__name__,
            "message": str(exc),
            "path": str(request.url.path),
        },
    )


# ─── Request Logging Middleware ───────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"→ {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"← {request.method} {request.url.path} [{response.status_code}]")
    return response


# ─── Health Check ────────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health_check():
    """API health check endpoint."""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": "1.0.0",
        "env": settings.APP_ENV,
    }


# ─── Root ────────────────────────────────────────────────────
@app.get("/", tags=["Root"])
async def root():
    return {
        "message": "Welcome to SmartAttend API",
        "docs": "/docs",
        "health": "/health",
    }
