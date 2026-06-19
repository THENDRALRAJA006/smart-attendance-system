# ============================================================
# SmartAttend — Security: JWT + Password Hashing
# ============================================================

from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from .config import settings

# ─── Password Hashing ───────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    """Hash a plain-text password using bcrypt."""
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify plain-text password against stored hash."""
    return pwd_context.verify(plain_password, hashed_password)


# ─── Access Token ────────────────────────────────────────────
def create_access_token(
    subject: Any,
    role: str,
    expires_delta: Optional[timedelta] = None,
) -> str:
    """
    Create a signed JWT access token.

    Args:
        subject: User ID (int or str)
        role: 'student' | 'faculty' | 'admin'
        expires_delta: Override default expiry

    Returns:
        Signed JWT string
    """
    expire = datetime.now(timezone.utc) + (
        expires_delta or timedelta(hours=settings.JWT_EXPIRE_HOURS)
    )
    payload = {
        "sub": str(subject),
        "role": role,
        "type": "access",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(
        payload,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


# ─── Refresh Token ───────────────────────────────────────────
def create_refresh_token(
    subject: Any,
    role: str,
) -> str:
    """
    Create a signed JWT refresh token (long-lived).

    Args:
        subject: User ID
        role: 'student' | 'faculty' | 'admin'

    Returns:
        Signed refresh JWT string
    """
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.JWT_REFRESH_EXPIRE_DAYS
    )
    payload = {
        "sub": str(subject),
        "role": role,
        "type": "refresh",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(
        payload,
        settings.JWT_REFRESH_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


# ─── Decode Access Token ─────────────────────────────────────
def decode_token(token: str) -> dict:
    """
    Decode and verify a JWT access token.

    Raises:
        JWTError: If token is invalid or expired

    Returns:
        Token payload dict with 'sub' and 'role'
    """
    return jwt.decode(
        token,
        settings.JWT_SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
    )


# ─── Decode Refresh Token ────────────────────────────────────
def decode_refresh_token(token: str) -> dict:
    """
    Decode and verify a JWT refresh token.

    Raises:
        JWTError: If token is invalid or expired

    Returns:
        Token payload dict with 'sub' and 'role'
    """
    payload = jwt.decode(
        token,
        settings.JWT_REFRESH_SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
    )
    if payload.get("type") != "refresh":
        raise JWTError("Not a refresh token")
    return payload
