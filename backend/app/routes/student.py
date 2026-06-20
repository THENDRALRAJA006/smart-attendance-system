# ============================================================
# SmartAttend — Student Routes (v3)
# GET /student/dashboard, /student/attendance-history
# POST /attendance/verify, /attendance/mark
# ============================================================

import logging
from typing import Optional
from datetime import date, timedelta
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.models.models import (
    Student, Attendance, Subject, Classroom, Session as SessionModel, Faculty
)
from app.services.rekognition_service import rekognition_service
from app.services.attendance_service import (
    get_session_by_id, get_active_session,
    check_duplicate_attendance, validate_rssi,
    validate_student_eligibility, mark_attendance,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Student"])


# ─── GET /student/dashboard ──────────────────────────────────

@router.get("/student/dashboard")
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

    total    = len(all_records)
    attended = sum(1 for r in all_records if r.status == "present")
    percentage = (attended / total * 100) if total > 0 else 0.0

    # Subject-wise breakdown
    subject_map: dict = {}
    for r in all_records:
        sid = r.subject_id
        if sid not in subject_map:
            subject = db.query(Subject).filter(Subject.id == sid).first()
            faculty_name = None
            if subject and subject.faculty_id:
                faculty = db.query(Faculty).filter(Faculty.id == subject.faculty_id).first()
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
            "time":           str(r.Attendance.time) if r.Attendance.time else None,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
        }
        for r in recent
    ]

    return {
        "total_classes":        total,
        "attended_classes":     attended,
        "attendance_percentage": round(percentage, 2),
        "subject_wise":         subject_wise,
        "recent_history":       recent_history,
    }


# ─── GET /student/attendance-history ─────────────────────────

@router.get("/student/attendance-history")
async def attendance_history(
    period: str = "monthly",
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Return filtered attendance history for the student."""
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
            "time":            str(r.Attendance.time) if r.Attendance.time else None,
            "status":          r.Attendance.status,
            "rssi":            r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
        }
        for r in rows
    ]


# ─── POST /attendance/verify ─────────────────────────────────

@router.post("/attendance/verify")
async def verify_attendance(
    session_id: int = Form(...),
    rssi: int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Pre-check step: verify session, BLE range, and eligibility
    WITHOUT marking attendance.

    Steps:
    1. Validate session exists and is active
    2. Validate RSSI (BLE proximity)
    3. Check student eligibility (department match)
    4. Check face is registered
    5. Check no duplicate

    Returns eligibility status — does NOT mark attendance.
    """
    # ─── 1. Session lookup ──────────────────────────────────
    session = get_session_by_id(db, session_id)

    # ─── 2. RSSI validation ─────────────────────────────────
    validate_rssi(rssi)

    # ─── 3. Student eligibility ─────────────────────────────
    validate_student_eligibility(db, current_student, session)

    # ─── 4. Face registered check ───────────────────────────
    if not current_student.face_id:
        return {
            "eligible":  False,
            "step":      "face_check",
            "message":   "No face registered. Please register your face first.",
        }

    # ─── 5. Duplicate check ─────────────────────────────────
    from app.models.models import Attendance as AttendanceModel
    existing = (
        db.query(AttendanceModel)
        .filter(
            AttendanceModel.student_id == current_student.id,
            AttendanceModel.session_id == session_id,
        )
        .first()
    )
    if existing:
        return {
            "eligible":  False,
            "step":      "duplicate",
            "message":   "Attendance already marked for this session.",
        }

    # Get session details for response
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()

    return {
        "eligible":        True,
        "step":            "ready",
        "message":         "All checks passed. Proceed with face verification.",
        "session_id":      session.id,
        "classroom_name":  classroom.room_name if classroom else "Unknown",
        "classroom_uuid":  classroom.ble_uuid if classroom else None,
        "subject_name":    subject.subject_name if subject else "Unknown",
        "rssi":            rssi,
    }


# ─── POST /attendance/mark ───────────────────────────────────

@router.post("/attendance/mark")
async def mark_student_attendance(
    file:       UploadFile = File(...),
    session_id: int = Form(...),
    rssi:       int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Complete attendance flow via deep-link session ID:
    1. Look up active session by session_id (from WhatsApp deep link)
    2. Validate RSSI (BLE range check)
    3. Check student eligibility (department)
    4. Check face is registered
    5. Check duplicate attendance
    6. Verify face via AWS Rekognition (90% threshold)
    7. Mark attendance
    """
    # ─── 1. Session lookup (deep link flow) ─────────────────
    session = get_session_by_id(db, session_id)

    # ─── 2. RSSI Validation ─────────────────────────────────
    validate_rssi(rssi)

    # ─── 3. Student eligibility ─────────────────────────────
    validate_student_eligibility(db, current_student, session)

    # ─── 4. Face registered check ───────────────────────────
    if not current_student.face_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face not registered. Please register your face first.",
        )

    # ─── 5. Duplicate check ──────────────────────────────────
    check_duplicate_attendance(db, current_student.id, session.id)

    # ─── 6. Face verification ────────────────────────────────
    image_bytes = await file.read()
    face_result = rekognition_service.verify_face(image_bytes, current_student.face_id)

    if not face_result["match"]:
        return {
            "match":      False,
            "confidence": face_result["confidence"],
            "message":    face_result["message"],
        }

    # ─── 7. Mark attendance ──────────────────────────────────
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=rssi,
        face_confidence=face_result["confidence"],
    )

    return {
        "match":         True,
        "confidence":    face_result["confidence"],
        "message":       "Attendance marked successfully ✅",
        "attendance_id": record.id,
        "time":          str(record.time) if record.time else None,
        "date":          record.date.isoformat(),
    }
