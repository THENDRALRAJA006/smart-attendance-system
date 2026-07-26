# ============================================================
# SmartAttend — ERP Departments API (v13)
#
# GET    /api/erp/departments              — List all
# POST   /api/erp/departments              — Create
# PUT    /api/erp/departments/{id}         — Update
# DELETE /api/erp/departments/{id}         — Delete
# PATCH  /api/erp/departments/{id}/toggle  — Toggle active
# GET    /api/erp/departments/{id}/sections          — Sections list
# POST   /api/erp/departments/{id}/sections          — Add section
# DELETE /api/erp/departments/{id}/sections/{sec_id} — Remove section
# POST   /api/erp/departments/seed         — Seed default departments
# ============================================================

import logging
from typing import List, Optional
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.models.models import Admin, ErpDepartment, ErpDepartmentSection, Classroom

router = APIRouter(prefix="/api/erp/departments", tags=["ERP Departments"])
logger = logging.getLogger(__name__)


# ─── Default Departments ─────────────────────────────────────

DEFAULT_DEPARTMENTS = [
    {"name": "B.E. Computer Science and Engineering",
     "short_name": "CSE", "degree_type": "B.E."},
    {"name": "B.Tech. Artificial Intelligence and Data Science",
     "short_name": "AI&DS", "degree_type": "B.Tech."},
    {"name": "B.E. Electronics and Communication Engineering",
     "short_name": "ECE", "degree_type": "B.E."},
    {"name": "B.E. Computer and Communication Engineering",
     "short_name": "CCE", "degree_type": "B.E."},
    {"name": "B.E. Mechanical Engineering",
     "short_name": "MECH", "degree_type": "B.E."},
    {"name": "B.Tech. Computer Science and Business Systems",
     "short_name": "CSBS", "degree_type": "B.Tech."},
    {"name": "B.E. Computer Science and Engineering (Artificial Intelligence and Machine Learning)",
     "short_name": "AIML", "degree_type": "B.E."},
    {"name": "B.Tech. Biotechnology",
     "short_name": "BT", "degree_type": "B.Tech."},
    {"name": "B.E. Electronics Engineering (VLSI Design and Technology)",
     "short_name": "VLSI", "degree_type": "B.E."},
    {"name": "M.Tech. Data Science",
     "short_name": "M.Tech DS", "degree_type": "M.Tech."},
    {"name": "M.E. Electronics and Communication Engineering (VLSI Design)",
     "short_name": "M.E. ECE", "degree_type": "M.E."},
]


# ─── Schemas ─────────────────────────────────────────────────

class DeptCreate(BaseModel):
    name: str
    short_name: str
    degree_type: str = "B.E."
    is_active: bool = True


class DeptUpdate(BaseModel):
    name: Optional[str] = None
    short_name: Optional[str] = None
    degree_type: Optional[str] = None
    is_active: Optional[bool] = None


class SectionCreate(BaseModel):
    year: int
    section: str
    classroom_id: Optional[int] = None
    student_count: Optional[int] = 0


class SectionUpdate(BaseModel):
    classroom_id: Optional[int] = None
    student_count: Optional[int] = None


# ─── Helpers ─────────────────────────────────────────────────

def _dept_dict(d: ErpDepartment) -> dict:
    return {
        "id":          d.id,
        "name":        d.name,
        "short_name":  d.short_name,
        "degree_type": d.degree_type,
        "is_active":   d.is_active,
        "created_at":  d.created_at.isoformat() if d.created_at else None,
        "updated_at":  d.updated_at.isoformat() if d.updated_at else None,
    }


def _section_dict(s: ErpDepartmentSection) -> dict:
    return {
        "id":            s.id,
        "department_id": s.department_id,
        "year":          s.year,
        "section":       s.section,
        "classroom_id":  s.classroom_id,
        "student_count": s.student_count,
        "classroom_name": s.classroom.room_name if s.classroom else None,
    }


# ─── Routes ──────────────────────────────────────────────────

@router.get("", summary="List all departments")
def list_departments(
    search: Optional[str] = Query(None),
    is_active: Optional[bool] = Query(None),
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(ErpDepartment)
    if is_active is not None:
        q = q.filter(ErpDepartment.is_active == is_active)
    if search:
        q = q.filter(
            ErpDepartment.name.ilike(f"%{search}%") |
            ErpDepartment.short_name.ilike(f"%{search}%")
        )
    depts = q.order_by(ErpDepartment.name).all()
    return {"total": len(depts), "departments": [_dept_dict(d) for d in depts]}


@router.post("", summary="Create department")
def create_department(
    body: DeptCreate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = ErpDepartment(
        name=body.name,
        short_name=body.short_name,
        degree_type=body.degree_type,
        is_active=body.is_active,
    )
    db.add(dept)
    db.commit()
    db.refresh(dept)
    return {"success": True, "department": _dept_dict(dept)}


@router.put("/{dept_id}", summary="Update department")
def update_department(
    dept_id: int,
    body: DeptUpdate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(dept, field, val)
    dept.updated_at = datetime.now()
    db.commit()
    db.refresh(dept)
    return {"success": True, "department": _dept_dict(dept)}


@router.delete("/{dept_id}", summary="Delete department")
def delete_department(
    dept_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    db.delete(dept)
    db.commit()
    return {"success": True, "message": f"Department {dept_id} deleted"}


@router.patch("/{dept_id}/toggle", summary="Toggle department active state")
def toggle_department(
    dept_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")
    dept.is_active = not dept.is_active
    dept.updated_at = datetime.now()
    db.commit()
    return {"success": True, "is_active": dept.is_active}


# ─── Sections ────────────────────────────────────────────────

@router.get("/{dept_id}/sections", summary="Get sections for a department")
def get_sections(
    dept_id: int,
    year: Optional[int] = Query(None),
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")

    q = db.query(ErpDepartmentSection).filter(
        ErpDepartmentSection.department_id == dept_id
    )
    if year:
        q = q.filter(ErpDepartmentSection.year == year)

    sections = q.order_by(ErpDepartmentSection.year, ErpDepartmentSection.section).all()
    # Group by year
    grouped: dict = {}
    for s in sections:
        yr = str(s.year)
        if yr not in grouped:
            grouped[yr] = []
        grouped[yr].append(_section_dict(s))

    return {
        "department_id": dept_id,
        "department_name": dept.name,
        "sections": [_section_dict(s) for s in sections],
        "grouped_by_year": grouped,
    }


@router.post("/{dept_id}/sections", summary="Add a section to a department year")
def add_section(
    dept_id: int,
    body: SectionCreate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    dept = db.query(ErpDepartment).filter(ErpDepartment.id == dept_id).first()
    if not dept:
        raise HTTPException(status_code=404, detail="Department not found")

    # Check duplicate
    existing = db.query(ErpDepartmentSection).filter(
        ErpDepartmentSection.department_id == dept_id,
        ErpDepartmentSection.year == body.year,
        ErpDepartmentSection.section == body.section.upper(),
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail="Section already exists for this year")

    sec = ErpDepartmentSection(
        department_id=dept_id,
        year=body.year,
        section=body.section.upper(),
        classroom_id=body.classroom_id,
        student_count=body.student_count or 0,
    )
    db.add(sec)
    db.commit()
    db.refresh(sec)
    return {"success": True, "section": _section_dict(sec)}


@router.put("/{dept_id}/sections/{section_id}", summary="Update a section")
def update_section(
    dept_id: int,
    section_id: int,
    body: SectionUpdate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    sec = db.query(ErpDepartmentSection).filter(
        ErpDepartmentSection.id == section_id,
        ErpDepartmentSection.department_id == dept_id,
    ).first()
    if not sec:
        raise HTTPException(status_code=404, detail="Section not found")
    for field, val in body.model_dump(exclude_none=True).items():
        setattr(sec, field, val)
    db.commit()
    db.refresh(sec)
    return {"success": True, "section": _section_dict(sec)}


@router.delete("/{dept_id}/sections/{section_id}", summary="Remove a section")
def delete_section(
    dept_id: int,
    section_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    sec = db.query(ErpDepartmentSection).filter(
        ErpDepartmentSection.id == section_id,
        ErpDepartmentSection.department_id == dept_id,
    ).first()
    if not sec:
        raise HTTPException(status_code=404, detail="Section not found")
    db.delete(sec)
    db.commit()
    return {"success": True, "message": "Section deleted"}


# ─── Seed Endpoint ───────────────────────────────────────────

@router.post("/seed", summary="Seed default departments (idempotent)")
def seed_departments(
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Seed the 11 default departments. Safe to call multiple times."""
    created = 0
    for d in DEFAULT_DEPARTMENTS:
        existing = db.query(ErpDepartment).filter(
            ErpDepartment.short_name == d["short_name"]
        ).first()
        if not existing:
            dept = ErpDepartment(**d)
            db.add(dept)
            created += 1
    db.commit()
    return {
        "success": True,
        "created": created,
        "message": f"Seeded {created} new departments",
    }
