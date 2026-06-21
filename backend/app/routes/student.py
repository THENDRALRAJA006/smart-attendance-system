# ============================================================
# SmartAttend — Student Routes
# GET /student/dashboard          — Attendance analytics
# GET /student/attendance-history — Filtered history by period
#
# NOTE: Attendance marking routes live in attendance.py:
#   POST /attendance/verify  — Pre-check BLE + eligibility
#   POST /attendance/mark    — Face verify (v4 tiers) + liveness
# ============================================================

import logging
from datetime import date, timedelta
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.models.models import Student, Attendance, Subject, Classroom, Faculty

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Student"])


# ─── GET /student/dashboard ──────────────────────────────────

@router.get("/student/dashboard", operation_id="student_get_dashboard")
async def student_dashboard(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Return student's attendance analytics for dashboard."""
    all_records = (
        db.query(Attendance)
        .filter(Attendance.student_id == current_student.id)
        .all()
    )

    total      = len(all_records)
    attended   = sum(1 for r in all_records if r.status == "present")
    percentage = (attended / total * 100) if total > 0 else 0.0

    # Subject-wise breakdown
    subject_map: dict = {}
    for r in all_records:
        sid = r.subject_id
        if sid not in subject_map:
            subject      = db.query(Subject).filter(Subject.id == sid).first()
            faculty_name = None
            if subject and subject.faculty_id:
                faculty      = db.query(Faculty).filter(Faculty.id == subject.faculty_id).first()
                faculty_name = faculty.name if faculty else None
            subject_map[sid] = {
                "subject_name": subject.subject_name if subject else "Unknown",
                "subject_code": subject.subject_code if subject else None,
                "faculty_name": faculty_name,
                "total":        0,
                "attended":     0,
            }
        subject_map[sid]["total"] += 1
        if r.status == "present":
            subject_map[sid]["attended"] += 1

    subject_wise = []
    for data in subject_map.values():
        t   = data["total"]
        a   = data["attended"]
        pct = (a / t * 100) if t > 0 else 0.0
        subject_wise.append({
            "subject_name": data["subject_name"],
            "subject_code": data["subject_code"],
            "faculty_name": data["faculty_name"],
            "total":        t,
            "attended":     a,
            "percentage":   round(pct, 2),
        })

    # Recent history (last 5)
    recent = (
        db.query(Attendance, Subject.subject_name, Classroom.room_name)
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .filter(Attendance.student_id == current_student.id)
        .order_by(Attendance.marked_at.desc())
        .limit(5)
        .all()
    )

    recent_history = [
        {
            "id":             r.Attendance.id,
            "student_id":     current_student.id,
            "student_name":   current_student.name,
            "classroom_id":   r.Attendance.classroom_id,
            "classroom_name": r.room_name,
            "subject_id":     r.Attendance.subject_id,
            "subject_name":   r.subject_name,
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
        }
        for r in recent
    ]

    return {
        "total_classes":         total,
        "attended_classes":      attended,
        "attendance_percentage": round(percentage, 2),
        "subject_wise":          subject_wise,
        "recent_history":        recent_history,
    }


# ─── GET /student/attendance-history ─────────────────────────

@router.get("/student/attendance-history", operation_id="student_get_attendance_history")
async def student_attendance_history(
    period: str = "monthly",
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Return filtered attendance history for the student (daily/weekly/monthly)."""
    today = date.today()
    if period == "daily":
        start_date = today
    elif period == "weekly":
        start_date = today - timedelta(days=7)
    else:  # monthly
        start_date = today.replace(day=1)

    rows = (
        db.query(Attendance, Subject.subject_name, Classroom.room_name)
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .filter(
            Attendance.student_id == current_student.id,
            Attendance.date >= start_date,
        )
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

    return [
        {
            "id":              r.Attendance.id,
            "student_id":      current_student.id,
            "student_name":    current_student.name,
            "classroom_id":    r.Attendance.classroom_id,
            "classroom_name":  r.room_name,
            "subject_id":      r.Attendance.subject_id,
            "subject_name":    r.subject_name,
            "date":            r.Attendance.date.isoformat(),
            "time":            r.Attendance.time,
            "status":          r.Attendance.status,
            "rssi":            r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
        }
        for r in rows
    ]
