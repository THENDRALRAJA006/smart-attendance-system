# ============================================================
# SmartAttend — Period Timings API (v13 — Admin & Teacher Custom)
#
# GET    /api/erp/period-timings          — List all timings (Admin & Faculty)
# POST   /api/erp/period-timings          — Create timing (Admin & Faculty)
# PUT    /api/erp/period-timings/{id}     — Update timing
# PUT    /api/erp/period-timings/bulk     — Bulk update all default timings
# DELETE /api/erp/period-timings/{id}     — Delete timing
# POST   /api/erp/period-timings/seed     — Reset/Seed default period timings
# ============================================================

import logging
from typing import List, Optional, Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin, get_current_user
from app.models.models import Admin, Faculty, PeriodTiming

router = APIRouter(prefix="/api/erp/period-timings", tags=["Period Timings"])
logger = logging.getLogger(__name__)

DEFAULT_TIMINGS = [
    {"label": "Period 1", "start_time": "08:00", "end_time": "08:50", "period_type": "Theory", "order_index": 1},
    {"label": "Period 2", "start_time": "08:50", "end_time": "09:40", "period_type": "Theory", "order_index": 2},
    {"label": "Break",    "start_time": "09:40", "end_time": "10:30", "period_type": "Break",  "order_index": 3},
    {"label": "Period 3", "start_time": "10:30", "end_time": "11:20", "period_type": "Theory", "order_index": 4},
    {"label": "Period 4", "start_time": "11:20", "end_time": "12:10", "period_type": "Theory", "order_index": 5},
    {"label": "Lunch",    "start_time": "12:10", "end_time": "13:00", "period_type": "Lunch",  "order_index": 6},
    {"label": "Period 5", "start_time": "13:00", "end_time": "13:50", "period_type": "Theory", "order_index": 7},
    {"label": "Period 6", "start_time": "13:50", "end_time": "14:40", "period_type": "Theory", "order_index": 8},
    {"label": "Period 7", "start_time": "14:40", "end_time": "15:30", "period_type": "Theory", "order_index": 9},
]


# ─── Schemas ─────────────────────────────────────────────────

class PeriodCreate(BaseModel):
    label: str
    start_time: str
    end_time: str
    period_type: str = "Theory"
    order_index: Optional[int] = None
    is_active: bool = True


class PeriodUpdate(BaseModel):
    id: Optional[int] = None
    label: Optional[str] = None
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    period_type: Optional[str] = None
    order_index: Optional[int] = None
    is_active: Optional[bool] = None


class BulkTimingSave(BaseModel):
    timings: List[PeriodUpdate]


# ─── Helpers ─────────────────────────────────────────────────

def _period_dict(p: PeriodTiming) -> dict:
    return {
        "id":          p.id,
        "label":       p.label,
        "start_time":  p.start_time,
        "end_time":    p.end_time,
        "period_type": p.period_type,
        "order_index": p.order_index,
        "is_active":   p.is_active,
        "created_at":  p.created_at.isoformat() if p.created_at else None,
    }


# ─── Routes ──────────────────────────────────────────────────

@router.get("", summary="List period timings")
def list_period_timings(
    is_active: Optional[bool] = Query(None),
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List all period timings (accessible by both Admin and Faculty)."""
    q = db.query(PeriodTiming)
    if is_active is not None:
        q = q.filter(PeriodTiming.is_active == is_active)
    timings = q.order_by(PeriodTiming.order_index).all()
    return {"total": len(timings), "period_timings": [_period_dict(p) for p in timings]}


@router.post("", summary="Create period timing (Admin & Teacher custom timing)")
def create_period_timing(
    body: PeriodCreate,
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a new period timing (Admin or Faculty for custom extra class timings)."""
    order = body.order_index
    if order is None:
        max_order = db.query(PeriodTiming).order_by(PeriodTiming.order_index.desc()).first()
        order = (max_order.order_index + 1) if max_order else 1

    # Check for order collision
    existing = db.query(PeriodTiming).filter(PeriodTiming.order_index == order).first()
    if existing:
        # Auto-shift order index
        order = (db.query(PeriodTiming).order_by(PeriodTiming.order_index.desc()).first().order_index + 1)

    period = PeriodTiming(
        label=body.label,
        start_time=body.start_time,
        end_time=body.end_time,
        period_type=body.period_type,
        order_index=order,
        is_active=body.is_active,
    )
    db.add(period)
    db.commit()
    db.refresh(period)
    return {"success": True, "period_timing": _period_dict(period)}


@router.put("/bulk", summary="Bulk update default period timings")
def bulk_update_period_timings(
    body: BulkTimingSave,
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update all period timings at once."""
    updated = 0
    for item in body.timings:
        if item.id:
            pt = db.query(PeriodTiming).filter(PeriodTiming.id == item.id).first()
            if pt:
                for field, val in item.model_dump(exclude_none=True).items():
                    setattr(pt, field, val)
                updated += 1
    db.commit()
    return {"success": True, "updated": updated, "message": f"Updated {updated} period timings"}


@router.put("/{period_id}", summary="Update period timing")
def update_period_timing(
    period_id: int,
    body: PeriodUpdate,
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    period = db.query(PeriodTiming).filter(PeriodTiming.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Period timing not found")

    for field, val in body.model_dump(exclude_none=True).items():
        setattr(period, field, val)

    db.commit()
    db.refresh(period)
    return {"success": True, "period_timing": _period_dict(period)}


@router.delete("/{period_id}", summary="Delete period timing")
def delete_period_timing(
    period_id: int,
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    period = db.query(PeriodTiming).filter(PeriodTiming.id == period_id).first()
    if not period:
        raise HTTPException(status_code=404, detail="Period timing not found")

    db.delete(period)
    db.commit()
    return {"success": True, "message": f"Period timing {period_id} deleted"}


@router.post("/seed", summary="Seed / Reset default period timings (idempotent)")
def seed_period_timings(
    current_user: Any = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    created = 0
    for t in DEFAULT_TIMINGS:
        existing = db.query(PeriodTiming).filter(PeriodTiming.order_index == t["order_index"]).first()
        if not existing:
            pt = PeriodTiming(**t)
            db.add(pt)
            created += 1
    db.commit()
    return {"success": True, "created": created, "message": f"Seeded {created} period timings"}
