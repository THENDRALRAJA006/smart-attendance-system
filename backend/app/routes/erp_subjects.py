# ============================================================
# SmartAttend — ERP Subjects API (v13)
#
# GET    /api/erp/subjects          — List subjects (filterable by dept/year)
# POST   /api/erp/subjects          — Create subject
# PUT    /api/erp/subjects/{id}     — Update subject
# DELETE /api/erp/subjects/{id}     — Delete subject
# ============================================================

import logging
from typing import Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.models.models import Admin, ErpSubject, ErpDepartment

router = APIRouter(prefix="/api/erp/subjects", tags=["ERP Subjects"])
logger = logging.getLogger(__name__)


# ─── Schemas ─────────────────────────────────────────────────

class SubjectCreate(BaseModel):
    subject_name: str
    subject_code: Optional[str] = None
    department_id: int
    year: Optional[int] = None
    credits: Optional[int] = 3
    subject_type: str = "Theory"  # Theory | Lab | Elective | Tutorial
    is_active: bool = True


class SubjectUpdate(BaseModel):
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    department_id: Optional[int] = None
    year: Optional[int] = None
    credits: Optional[int] = None
    subject_type: Optional[str] = None
    is_active: Optional[bool] = None


# ─── Helpers ─────────────────────────────────────────────────

def _subject_dict(s: ErpSubject) -> dict:
    return {
        "id":            s.id,
        "subject_name":  s.subject_name,
        "subject_code":  s.subject_code,
        "department_id": s.department_id,
        "department_name": s.department.name if s.department else None,
        "department_short": s.department.short_name if s.department else None,
        "year":          s.year,
        "credits":       s.credits,
        "subject_type":  s.subject_type,
        "is_active":     s.is_active,
        "created_at":    s.created_at.isoformat() if s.created_at else None,
    }


# ─── Routes ──────────────────────────────────────────────────

@router.get("", summary="List all ERP subjects")
def list_subjects(
    department_id: Optional[int] = Query(None),
    year: Optional[int] = Query(None),
    search: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(ErpSubject)
    if department_id:
        q = q.filter(ErpSubject.department_id == department_id)
    if year:
        q = q.filter(ErpSubject.year == year)
    if is_active is not None:
        q = q.filter(ErpSubject.is_active == is_active)
    if search:
        q = q.filter(
            ErpSubject.subject_name.ilike(f"%{search}%") |
            ErpSubject.subject_code.ilike(f"%{search}%")
        )
    subjects = q.order_by(ErpSubject.subject_name).all()
    return {"total": len(subjects), "subjects": [_subject_dict(s) for s in subjects]}


@router.post("", summary="Create ERP subject")
def create_subject(
    body: SubjectCreate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == body.department_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")

    subject = ErpSubject(
        subject_name=body.subject_name,
        subject_code=body.subject_code,
        department_id=body.department_id,
        year=body.year,
        credits=body.credits,
        subject_type=body.subject_type,
        is_active=body.is_active,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return {"success": True, "subject": _subject_dict(subject)}


@router.put("/{subject_id}", summary="Update ERP subject")
def update_subject(
    subject_id: int,
    body: SubjectUpdate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    subject = db.query(ErpSubject).filter(ErpSubject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    for field, val in body.model_dump(exclude_none=True).items():
        setattr(subject, field, val)
    subject.updated_at = datetime.now()
    db.commit()
    db.refresh(subject)
    return {"success": True, "subject": _subject_dict(subject)}


@router.delete("/{subject_id}", summary="Delete ERP subject")
def delete_subject(
    subject_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    subject = db.query(ErpSubject).filter(ErpSubject.id == subject_id).first()
    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    db.delete(subject)
    db.commit()
    return {"success": True, "message": f"Subject {subject_id} deleted"}
