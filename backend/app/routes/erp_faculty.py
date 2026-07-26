# ============================================================
# SmartAttend — ERP Faculty Management API (v13)
#
# GET    /api/erp/faculty          — List all faculty with ERP fields
# POST   /api/erp/faculty          — Create faculty
# PUT    /api/erp/faculty/{id}     — Update faculty
# DELETE /api/erp/faculty/{id}     — Delete faculty
# ============================================================

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.core.security import hash_password
from app.models.models import Admin, Faculty

router = APIRouter(prefix="/api/erp/faculty", tags=["ERP Faculty"])
logger = logging.getLogger(__name__)


# ─── Schemas ─────────────────────────────────────────────────

class FacultyCreate(BaseModel):
    name: str
    email: str
    password: Optional[str] = "faculty123"
    department: Optional[str] = None
    phone_number: Optional[str] = None
    employee_id: Optional[str] = None
    designation: Optional[str] = None
    is_active: bool = True


class FacultyUpdate(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    department: Optional[str] = None
    phone_number: Optional[str] = None
    employee_id: Optional[str] = None
    designation: Optional[str] = None
    is_active: Optional[bool] = None
    password: Optional[str] = None


# ─── Helpers ─────────────────────────────────────────────────

def _faculty_dict(f: Faculty) -> dict:
    return {
        "id":           f.id,
        "name":         f.name,
        "email":        f.email,
        "department":   f.department,
        "phone_number": f.phone_number,
        "employee_id":  f.employee_id,
        "designation":  f.designation,
        "is_active":    f.is_active,
        "created_at":   f.created_at.isoformat() if f.created_at else None,
    }


# ─── Routes ──────────────────────────────────────────────────

@router.get("", summary="List faculty members")
def list_faculty(
    department: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(Faculty)
    if department:
        q = q.filter(Faculty.department == department)
    if is_active is not None:
        q = q.filter(Faculty.is_active == is_active)
    if search:
        q = q.filter(
            Faculty.name.ilike(f"%{search}%") |
            Faculty.email.ilike(f"%{search}%") |
            Faculty.employee_id.ilike(f"%{search}%")
        )
    faculty_list = q.order_by(Faculty.name).all()
    return {"total": len(faculty_list), "faculty": [_faculty_dict(f) for f in faculty_list]}


@router.post("", summary="Create faculty member")
def create_faculty(
    body: FacultyCreate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(Faculty).filter(Faculty.email == body.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Faculty email already exists")

    pwd = body.password or "faculty123"
    faculty = Faculty(
        name=body.name,
        email=body.email,
        password_hash=hash_password(pwd),
        department=body.department,
        phone_number=body.phone_number,
        employee_id=body.employee_id,
        designation=body.designation,
        is_active=body.is_active,
    )
    db.add(faculty)
    db.commit()
    db.refresh(faculty)
    return {"success": True, "faculty": _faculty_dict(faculty)}


@router.put("/{faculty_id}", summary="Update faculty member")
def update_faculty(
    faculty_id: int,
    body: FacultyUpdate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    data = body.model_dump(exclude_none=True)
    if "password" in data:
        pwd = data.pop("password")
        if pwd:
            faculty.password_hash = hash_password(pwd)

    for field, val in data.items():
        setattr(faculty, field, val)

    db.commit()
    db.refresh(faculty)
    return {"success": True, "faculty": _faculty_dict(faculty)}


@router.delete("/{faculty_id}", summary="Delete faculty member")
def delete_faculty(
    faculty_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")

    db.delete(faculty)
    db.commit()
    return {"success": True, "message": f"Faculty {faculty_id} deleted"}
