# ============================================================
# SmartAttend — FastAPI Application Entry Point
# ============================================================

import logging
import traceback
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.database import init_db
from app.services.rekognition_service import rekognition_service
from app.routes import auth, student, faculty, admin, attendance

# ─── Logging ─────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO if settings.APP_ENV == "production" else logging.DEBUG,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


# ─── Startup / Shutdown ──────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize services on startup."""
    logger.info("🚀 SmartAttend API starting...")
    
    # Create DB tables
    init_db()
    logger.info("✅ Database tables initialized")
    
    # Ensure AWS Rekognition collection exists
    try:
        rekognition_service.ensure_collection()
        logger.info("✅ AWS Rekognition collection ready")
    except Exception as e:
        logger.warning(f"⚠ Rekognition init warning: {e}")
    
    logger.info("✅ SmartAttend API ready")
    yield
    
    logger.info("👋 SmartAttend API shutting down...")


# ─── FastAPI App ─────────────────────────────────────────────
app = FastAPI(
    title="SmartAttend API",
    description="""
    ## SmartAttend — Intelligent Attendance System
    
    A secure, multi-factor attendance system using:
    - **BLE** (ESP32 beacons) for proximity verification
    - **AWS Rekognition** for face verification
    - **JWT** for authentication
    
    ### Roles
    - **Student**: Register, mark attendance, view history
    - **Faculty**: Create sessions, generate codes, view reports
    - **Admin**: System management, analytics
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
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
