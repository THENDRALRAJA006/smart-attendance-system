# ============================================================
# SmartAttend — Session Routes (v10)
# Endpoints for Teacher Attendance Session management.
#
# POST /session/start             — start a new session
# POST /session/end/{id}          — end session
# POST /session/extend/{id}       — extend session by N minutes
# GET  /session/active            — teacher's active session
# GET  /session/details/{id}      — full detail + live roster
# GET  /session/history           — teacher's past sessions
# GET  /session/classrooms        — all classrooms for form dropdown
# GET  /session/subjects          — teacher's assigned subjects
# GET  /session/my-classes        — summary of teacher's classes
# GET  /session/export/{id}/{fmt} — export session attendance
# ============================================================

import io
import logging
import random
import string
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy import func as sql_func, distinct
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_faculty
from app.models.models import (
    Faculty, Classroom, Subject, Session as SessionModel,
    Attendance, Student, FacultySubject, AttendanceLink,
)
from app.schemas.schemas import (
    StartSessionRequest, ExtendSessionRequest, TeacherSessionResponse,
)
from app.services.attendance_service import create_attendance_link
from app.services.report_service import (
    _get_attendance_data, generate_csv, generate_excel, generate_pdf,
)
from app.core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/session", tags=["Session"])


# ─── Helpers ─────────────────────────────────────────────────

def _generate_session_name(classroom_name: str, subject_name: str) -> str:
    """Auto-generate a human-readable session label.
    Format: <classroom>_<subject_initials>_YYYY_MM_DD_HH_MM
    Example: A101_AI_2026_07_22_09_00
    """
    now = datetime.now()
    # Sanitise classroom name: strip CLASSROOM_ prefix if present
    room = classroom_name.replace("CLASSROOM_", "").replace(" ", "")
    # Take up to 8 chars of subject (letters/digits only)
    subj = "".join(c for c in subject_name if c.isalnum())[:8].upper()
    return f"{room}_{subj}_{now.strftime('%Y_%m_%d_%H_%M')}"


def _radius_to_rssi(radius_metres: int) -> int:
    """
    Convert teacher-selected radius (metres) to an approximate RSSI threshold.
    Based on free-space path loss with BLE @ 2.4 GHz, Tx=-59 dBm @ 1 m.
    This is an approximation — real-world varies by environment.

    radius  10m → ~-70 dBm
    radius  20m → ~-76 dBm
    radius  30m → ~-80 dBm
    radius  40m → ~-83 dBm
    radius  50m → ~-85 dBm
    """
    import math
    if radius_metres <= 0:
        return -70
    # RSSI = TxPower - 10 * n * log10(d), n=2.5 for indoor
    tx_power = -59  # at 1 m reference
    n = 2.5
    rssi = tx_power - 10 * n * math.log10(max(radius_metres, 1))
    return max(-100, min(-40, int(rssi)))


def _build_session_dict(
    session: SessionModel,
    classroom: Classroom,
    subject: Subject,
    db: Session,
    include_roster: bool = False,
) -> dict:
    """Serialise a session with computed live fields."""
    now = datetime.now()

    # Attendance count
    attendance_count = (
        db.query(sql_func.count(Attendance.id))
        .filter(Attendance.session_id == session.id)
        .scalar()
    ) or 0

    # Total enrolled students for this department/year/section
    q = db.query(sql_func.count(Student.id))
    if session.department:
        q = q.filter(
            sql_func.lower(Student.department) == session.department.lower()
        )
    if session.year:
        q = q.filter(Student.year == session.year)
    if session.section:
        q = q.filter(
            sql_func.lower(Student.section) == session.section.lower()
        )
    total_students = q.scalar() or 0

    # Time remaining
    if session.end_time and session.is_active:
        remaining = max(0, int((session.end_time - now).total_seconds()))
    else:
        remaining = 0

    base = {
        "id":                session.id,
        "session_name":      session.session_name,
        "classroom_id":      session.classroom_id,
        "classroom_name":    classroom.room_name if classroom else "",
        "subject_id":        session.subject_id,
        "subject_name":      subject.subject_name if subject else "",
        "subject_code":      subject.subject_code if subject else None,
        "department":        session.department,
        "year":              session.year,
        "section":           session.section,
        "attendance_radius": session.attendance_radius,
        "duration_minutes":  session.duration_minutes,
        "start_time":        session.start_time.isoformat() if session.start_time else None,
        "end_time":          session.end_time.isoformat() if session.end_time else None,
        "status":            session.status,
        "is_active":         session.is_active,
        "attendance_count":  attendance_count,
        "total_students":    total_students,
        "absent_count":      max(0, total_students - attendance_count),
        "time_remaining_seconds": remaining,
        "created_at":        session.created_at.isoformat() if session.created_at else None,
    }

    if include_roster:
        rows = (
            db.query(
                Attendance,
                Student.name.label("student_name"),
                Student.reg_no.label("reg_no"),
            )
            .join(Student, Attendance.student_id == Student.id)
            .filter(Attendance.session_id == session.id)
            .order_by(Attendance.marked_at.asc())
            .all()
        )
        base["students"] = [
            {
                "student_id":      r.Attendance.student_id,
                "student_name":    r.student_name,
                "reg_no":         r.reg_no,
                "time":           r.Attendance.time,
                "status":         r.Attendance.status,
                "rssi":           r.Attendance.rssi,
                "face_confidence": r.Attendance.face_confidence,
                "liveness_verified": r.Attendance.liveness_verified,
                "marked_at":      r.Attendance.marked_at.isoformat()
                                  if r.Attendance.marked_at else None,
            }
            for r in rows
        ]
    return base


# ─── POST /session/start ─────────────────────────────────────

@router.post("/start", status_code=status.HTTP_201_CREATED)
async def start_session(
    request: StartSessionRequest,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Create a new attendance session for teacher.

    - Validates classroom and subject ownership.
    - Closes any other active sessions in same classroom.
    - Auto-generates session_name and end_time.
    - Stores department/year/section for student routing.
    - Stores attendance_radius for BLE threshold override.
    """
    # Validate classroom
    classroom = db.query(Classroom).filter(
        Classroom.id == request.classroom_id
    ).first()
    if not classroom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Classroom not found",
        )

    # Validate subject belongs to this teacher
    subject = (
        db.query(Subject)
        .join(FacultySubject, FacultySubject.subject_id == Subject.id)
        .filter(
            Subject.id == request.subject_id,
            FacultySubject.faculty_id == current_faculty.id,
        )
        .first()
    )
    if not subject:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Subject not assigned to you. Ask admin to assign it first.",
        )

    # Close any existing active sessions in this classroom
    db.query(SessionModel).filter(
        SessionModel.classroom_id == request.classroom_id,
        SessionModel.is_active == True,
    ).update({"is_active": False, "status": "closed"})

    # Calculate end_time
    now      = datetime.now()
    end_time = now + timedelta(minutes=request.duration_minutes)

    # Generate session name and internal code
    session_name    = _generate_session_name(classroom.room_name, subject.subject_name)
    attendance_code = "".join(random.choices(string.digits, k=6))

    # Create session
    session = SessionModel(
        classroom_id=request.classroom_id,
        subject_id=request.subject_id,
        faculty_id=current_faculty.id,
        attendance_code=attendance_code,
        start_time=now,
        end_time=end_time,
        is_active=True,
        department=request.department,
        year=request.year,
        section=request.section,
        attendance_radius=request.attendance_radius,
        duration_minutes=request.duration_minutes,
        session_name=session_name,
        status="active",
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Generate attendance link (for WhatsApp share / deep link)
    try:
        create_attendance_link(
            db=db,
            session=session,
            classroom_name=classroom.room_name,
            subject_name=subject.subject_name,
            faculty_name=current_faculty.name,
            base_url=settings.APP_BASE_URL,
        )
    except Exception as e:
        logger.warning(f"Attendance link creation failed (non-fatal): {e}")

    logger.info(
        f"[SESSION] Started: id={session.id}, name={session_name}, "
        f"faculty={current_faculty.id}, classroom={classroom.room_name}, "
        f"subject={subject.subject_name}, dept={request.department}, "
        f"year={request.year}, section={request.section}, "
        f"radius={request.attendance_radius}m, duration={request.duration_minutes}min"
    )

    return _build_session_dict(session, classroom, subject, db)


# ─── POST /session/end/{session_id} ─────────────────────────

@router.post("/end/{session_id}")
async def end_session(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """End an active session. Only the owning teacher may call this."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.faculty_id == current_faculty.id,
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found or you do not own it",
        )

    session.is_active = False
    session.status    = "closed"
    session.end_time  = datetime.now()

    # Deactivate attendance links
    db.query(AttendanceLink).filter(
        AttendanceLink.session_id == session_id
    ).update({"is_active": False})

    db.commit()
    logger.info(f"[SESSION] Ended: id={session_id}, faculty={current_faculty.id}")
    return {"message": "Session ended successfully", "session_id": session_id}


# ─── POST /session/extend/{session_id} ──────────────────────

@router.post("/extend/{session_id}")
async def extend_session(
    session_id: int,
    request: ExtendSessionRequest,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Extend an active session's end_time by extra_minutes."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.faculty_id == current_faculty.id,
        SessionModel.is_active == True,
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active session not found or you do not own it",
        )

    # Extend end_time
    if session.end_time:
        session.end_time = session.end_time + timedelta(minutes=request.extra_minutes)
    else:
        session.end_time = datetime.now() + timedelta(minutes=request.extra_minutes)

    session.duration_minutes = (session.duration_minutes or 0) + request.extra_minutes
    db.commit()

    logger.info(
        f"[SESSION] Extended: id={session_id}, +{request.extra_minutes}min, "
        f"new_end={session.end_time.isoformat()}"
    )
    return {
        "message":     f"Session extended by {request.extra_minutes} minutes",
        "new_end_time": session.end_time.isoformat(),
    }


# ─── GET /session/active ─────────────────────────────────────

@router.get("/active")
async def get_active_session(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Get the teacher's current active session (if any)."""
    session = (
        db.query(SessionModel)
        .filter(
            SessionModel.faculty_id == current_faculty.id,
            SessionModel.is_active == True,
        )
        .order_by(SessionModel.start_time.desc())
        .first()
    )
    if not session:
        return {"session": None, "has_active_session": False}

    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()

    return {
        "has_active_session": True,
        "session": _build_session_dict(session, classroom, subject, db, include_roster=True),
    }


# ─── GET /session/details/{session_id} ──────────────────────

@router.get("/details/{session_id}")
async def get_session_details(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Get full session detail + live roster for any of this teacher's sessions."""
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.faculty_id == current_faculty.id,
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()

    return _build_session_dict(session, classroom, subject, db, include_roster=True)


# ─── GET /session/history ────────────────────────────────────

@router.get("/history")
async def session_history(
    limit: int = 30,
    offset: int = 0,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Return paginated list of teacher's past and active sessions."""
    sessions = (
        db.query(SessionModel)
        .filter(SessionModel.faculty_id == current_faculty.id)
        .order_by(SessionModel.start_time.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    total = (
        db.query(sql_func.count(SessionModel.id))
        .filter(SessionModel.faculty_id == current_faculty.id)
        .scalar()
    ) or 0

    items = []
    for s in sessions:
        cls = db.query(Classroom).filter(Classroom.id == s.classroom_id).first()
        sub = db.query(Subject).filter(Subject.id == s.subject_id).first()
        items.append(_build_session_dict(s, cls, sub, db, include_roster=False))

    return {"total": total, "items": items}


# ─── GET /session/classrooms ────────────────────────────────

@router.get("/classrooms")
async def list_classrooms(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """All classrooms available for session creation."""
    classrooms = db.query(Classroom).order_by(Classroom.room_name).all()
    return [
        {"id": c.id, "room_name": c.room_name, "ble_uuid": c.ble_uuid}
        for c in classrooms
    ]


# ─── GET /session/subjects ───────────────────────────────────

@router.get("/subjects")
async def list_subjects(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Subjects assigned to this teacher."""
    subjects = (
        db.query(Subject)
        .join(FacultySubject, FacultySubject.subject_id == Subject.id)
        .filter(FacultySubject.faculty_id == current_faculty.id)
        .all()
    )
    return [
        {
            "id":           s.id,
            "subject_name": s.subject_name,
            "subject_code": s.subject_code,
            "department":   s.department,
        }
        for s in subjects
    ]


# ─── GET /session/my-classes ────────────────────────────────

@router.get("/my-classes")
async def my_classes(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Return a summary of classes (subject + dept + recent session) for the teacher.
    Groups subjects by department/year/section derived from recent sessions.
    """
    subjects = (
        db.query(Subject)
        .join(FacultySubject, FacultySubject.subject_id == Subject.id)
        .filter(FacultySubject.faculty_id == current_faculty.id)
        .all()
    )

    result = []
    for s in subjects:
        # Last session for this subject
        last_session = (
            db.query(SessionModel)
            .filter(
                SessionModel.subject_id == s.id,
                SessionModel.faculty_id == current_faculty.id,
            )
            .order_by(SessionModel.start_time.desc())
            .first()
        )
        total_sessions = (
            db.query(sql_func.count(SessionModel.id))
            .filter(
                SessionModel.subject_id == s.id,
                SessionModel.faculty_id == current_faculty.id,
            )
            .scalar()
        ) or 0

        result.append({
            "subject_id":    s.id,
            "subject_name":  s.subject_name,
            "subject_code":  s.subject_code,
            "department":    s.department,
            "total_sessions": total_sessions,
            "last_session":  {
                "id":         last_session.id,
                "status":     last_session.status,
                "start_time": last_session.start_time.isoformat(),
                "is_active":  last_session.is_active,
                "section":    last_session.section,
                "year":       last_session.year,
            } if last_session else None,
        })

    return result


# ─── GET /session/export/{session_id}/{fmt} ──────────────────

@router.get("/export/{session_id}/{fmt}")
async def export_session_attendance(
    session_id: int,
    fmt: str,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Export attendance for a specific session.
    Supported formats: csv, xlsx, pdf
    """
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.faculty_id == current_faculty.id,
    ).first()
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    fmt = fmt.lower().strip()
    if fmt == "excel":
        fmt = "xlsx"
    if fmt not in ["csv", "xlsx", "pdf"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported format '{fmt}'. Use csv, xlsx, or pdf.",
        )

    data = _get_attendance_data(
        db=db,
        faculty_id=current_faculty.id,
        period="monthly",
        session_id=session_id,
    )

    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    safe_name = (session.session_name or f"session_{session_id}").replace(" ", "_")

    if fmt == "csv":
        content    = generate_csv(data)
        media_type = "text/csv"
        filename   = f"{safe_name}.csv"
    elif fmt == "xlsx":
        content    = generate_excel(data)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename   = f"{safe_name}.xlsx"
    else:
        title   = session.session_name or f"Session #{session_id}"
        content = generate_pdf(data, title=title)
        media_type = "application/pdf"
        filename   = f"{safe_name}.pdf"

    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
