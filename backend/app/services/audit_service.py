"""
SmartAttend — Audit Service
============================
Writes immutable audit trail entries for every admin-initiated mutation.

Usage:
    from app.services.audit_service import log_action

    log_action(
        db=db,
        admin=current_admin,
        action="student.suspend",
        target_type="student",
        target_id=student.id,
        detail={"name": student.name, "reg_no": student.reg_no},
        request=request,        # FastAPI Request — extracts IP + User-Agent
    )
"""
import json
import logging
from typing import Any

from fastapi import Request
from sqlalchemy.orm import Session

from app.models.models import AuditLog

logger = logging.getLogger(__name__)


def log_action(
    db: Session,
    action: str,
    *,
    actor_id: int | None = None,
    actor_name: str | None = None,
    actor_role: str = "admin",
    target_type: str | None = None,
    target_id: int | None = None,
    detail: dict[str, Any] | str | None = None,
    request: Request | None = None,
) -> AuditLog:
    """
    Write one immutable audit log row.

    Parameters
    ----------
    db          : SQLAlchemy session
    action      : Dot-namespaced action string e.g. "student.create", "attendance.delete"
    actor_id    : ID of the admin performing the action
    actor_name  : Denormalized name of the admin (preserved even if admin is deleted)
    actor_role  : Role string (default "admin")
    target_type : Entity type being acted on ("student", "faculty", "session", ...)
    target_id   : PK of the entity being acted on
    detail      : Dict or string with extra context (stored as JSON text)
    request     : FastAPI Request object for IP and User-Agent extraction

    Returns
    -------
    AuditLog — the persisted row
    """
    ip_address: str | None = None
    user_agent: str | None = None

    if request is not None:
        # Respect X-Forwarded-For for proxied deployments
        forwarded_for = request.headers.get("X-Forwarded-For")
        if forwarded_for:
            ip_address = forwarded_for.split(",")[0].strip()
        else:
            ip_address = request.client.host if request.client else None
        user_agent = request.headers.get("User-Agent")

    detail_str: str | None = None
    if detail is not None:
        if isinstance(detail, dict):
            try:
                detail_str = json.dumps(detail, default=str)
            except Exception:
                detail_str = str(detail)
        else:
            detail_str = str(detail)

    entry = AuditLog(
        actor_id    = actor_id,
        actor_name  = actor_name,
        actor_role  = actor_role,
        action      = action,
        target_type = target_type,
        target_id   = target_id,
        detail      = detail_str,
        ip_address  = ip_address,
        user_agent  = user_agent,
    )

    try:
        db.add(entry)
        db.commit()
        db.refresh(entry)
        logger.info(
            "[AUDIT] action=%s actor=%s(%s) target=%s/%s",
            action, actor_name, actor_id, target_type, target_id,
        )
    except Exception as exc:
        # Audit failure must never break the main operation
        db.rollback()
        logger.error("[AUDIT] Failed to write audit log: %s", exc)

    return entry


def log_action_from_admin(
    db: Session,
    admin,           # Admin ORM object
    action: str,
    request: Request | None = None,
    *,
    target_type: str | None = None,
    target_id: int | None = None,
    detail: dict[str, Any] | None = None,
) -> AuditLog:
    """Convenience wrapper — accepts Admin ORM object directly."""
    return log_action(
        db          = db,
        action      = action,
        actor_id    = admin.id,
        actor_name  = admin.name,
        actor_role  = "admin",
        target_type = target_type,
        target_id   = target_id,
        detail      = detail,
        request     = request,
    )
