# ============================================================
# SmartAttend — ERP Classrooms API (v13)
#
# GET    /api/erp/classrooms          — List classrooms
# POST   /api/erp/classrooms          — Create classroom
# PUT    /api/erp/classrooms/{id}     — Update classroom
# DELETE /api/erp/classrooms/{id}     — Delete classroom
# POST   /api/erp/classrooms/seed     — Seed default classrooms
# ============================================================

import logging
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.models.models import Admin, Classroom

router = APIRouter(prefix="/api/erp/classrooms", tags=["ERP Classrooms"])
logger = logging.getLogger(__name__)

DEFAULT_CLASSROOMS = [
    "A101", "A102", "A103", "A104", "A201", "A202", "A203",
    "Lab 1", "Lab 2", "Lab 3", "Seminar Hall", "Auditorium"
]


# ─── Schemas ─────────────────────────────────────────────────

class ClassroomCreate(BaseModel):
    room_name: str
    ble_uuid: Optional[str] = None


class ClassroomUpdate(BaseModel):
    room_name: Optional[str] = None
    ble_uuid: Optional[str] = None


# ─── Helpers ─────────────────────────────────────────────────

def _classroom_dict(c: Classroom) -> dict:
    return {
        "id":          c.id,
        "room_name":   c.room_name,
        "ble_uuid":    c.ble_uuid,
        "created_at":  c.created_at.isoformat() if c.created_at else None,
    }


# ─── Routes ──────────────────────────────────────────────────

@router.get("", summary="List classrooms")
def list_classrooms(
    search: Optional[str] = Query(None),
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    q = db.query(Classroom)
    if search:
        q = q.filter(Classroom.room_name.ilike(f"%{search}%"))
    classrooms = q.order_by(Classroom.room_name).all()
    return {"total": len(classrooms), "classrooms": [_classroom_dict(c) for c in classrooms]}


@router.post("", summary="Create classroom")
def create_classroom(
    body: ClassroomCreate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(Classroom).filter(Classroom.room_name == body.room_name).first()
    if existing:
        raise HTTPException(status_code=400, detail="Classroom name already exists")

    classroom = Classroom(
        room_name=body.room_name,
        ble_uuid=body.ble_uuid,
    )
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    return {"success": True, "classroom": _classroom_dict(classroom)}


@router.put("/{classroom_id}", summary="Update classroom")
def update_classroom(
    classroom_id: int,
    body: ClassroomUpdate,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    classroom = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="Classroom not found")

    for field, val in body.model_dump(exclude_none=True).items():
        setattr(classroom, field, val)

    db.commit()
    db.refresh(classroom)
    return {"success": True, "classroom": _classroom_dict(classroom)}


@router.delete("/{classroom_id}", summary="Delete classroom")
def delete_classroom(
    classroom_id: int,
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    classroom = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="Classroom not found")

    db.delete(classroom)
    db.commit()
    return {"success": True, "message": f"Classroom {classroom_id} deleted"}


@router.post("/seed", summary="Seed default classrooms (idempotent)")
def seed_classrooms(
    current_user: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    created = 0
    for name in DEFAULT_CLASSROOMS:
        existing = db.query(Classroom).filter(Classroom.room_name == name).first()
        if not existing:
            c = Classroom(room_name=name)
            db.add(c)
            created += 1
    db.commit()
    return {"success": True, "created": created, "message": f"Seeded {created} classrooms"}
