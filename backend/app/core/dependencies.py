# ============================================================
# SmartAttend — FastAPI Dependencies
# JWT auth guard + role-based access control
# ============================================================

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from sqlalchemy.orm import Session
from typing import Optional

from .database import get_db
from .security import decode_token
from app.models.models import Student, Faculty, Admin

# ─── Bearer scheme ──────────────────────────────────────────
bearer_scheme = HTTPBearer(auto_error=False)


def _extract_payload(
    credentials: Optional[HTTPAuthorizationCredentials],
) -> dict:
    """Extract and validate JWT payload from Bearer token."""
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    try:
        payload = decode_token(credentials.credentials)
        return payload
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ─── Generic current user ───────────────────────────────────
def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    """Returns the authenticated user (student, faculty, or admin)."""
    payload = _extract_payload(credentials)
    role = payload.get("role")
    user_id = int(payload.get("sub"))

    if role == "student":
        user = db.query(Student).filter(Student.id == user_id).first()
    elif role == "faculty":
        user = db.query(Faculty).filter(Faculty.id == user_id).first()
    elif role == "admin":
        user = db.query(Admin).filter(Admin.id == user_id).first()
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid role in token",
        )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user


# ─── Student guard ───────────────────────────────────────────
def get_current_student(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Student:
    """Require authenticated student."""
    payload = _extract_payload(credentials)
    if payload.get("role") != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Student access required",
        )
    student = db.query(Student).filter(
        Student.id == int(payload["sub"])
    ).first()
    if not student:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )
    return student


# ─── Faculty guard ───────────────────────────────────────────
def get_current_faculty(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Faculty:
    """Require authenticated faculty member."""
    payload = _extract_payload(credentials)
    if payload.get("role") != "faculty":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Faculty access required",
        )
    faculty = db.query(Faculty).filter(
        Faculty.id == int(payload["sub"])
    ).first()
    if not faculty:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Faculty not found",
        )
    return faculty


# ─── Admin guard ─────────────────────────────────────────────
def get_current_admin(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
) -> Admin:
    """Require authenticated admin."""
    payload = _extract_payload(credentials)
    if payload.get("role") != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required",
        )
    admin = db.query(Admin).filter(
        Admin.id == int(payload["sub"])
    ).first()
    if not admin:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Admin not found",
        )
    return admin


# ─── Any-role guard (returns user + role tuple) ──────────────
def get_current_user_any_role(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer_scheme),
    db: Session = Depends(get_db),
):
    """
    Return (user_object, role_string) for any authenticated user.
    Used by /auth/me to support students, faculty, and admin.
    """
    payload = _extract_payload(credentials)
    role    = payload.get("role")
    user_id = int(payload.get("sub"))

    if role == "student":
        user = db.query(Student).filter(Student.id == user_id).first()
    elif role == "faculty":
        user = db.query(Faculty).filter(Faculty.id == user_id).first()
    elif role == "admin":
        user = db.query(Admin).filter(Admin.id == user_id).first()
    else:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid role in token",
        )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )
    return user, role
