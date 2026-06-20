# ============================================================
# SmartAttend — Faculty Routes (v3)
# Dashboard, session management, attendance link, reports, exports
# ============================================================

import logging
import urllib.parse
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_faculty
from app.core.config import settings
from app.models.models import (
    Faculty, Classroom, Subject, Session as AttendanceSession,
    Attendance, Student, FacultySubject, AttendanceLink
)
from app.schemas.schemas import CreateSessionRequest, AttendanceLinkResponse
from app.services.attendance_service import create_attendance_link
from app.services.report_service import (
    _get_attendance_data, generate_csv, generate_excel, generate_pdf
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/faculty", tags=["Faculty"])


# ─── GET /faculty/dashboard ──────────────────────────────────

@router.get("/dashboard")
async def faculty_dashboard(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Return faculty dashboard: sessions, classrooms, subjects."""
    sessions = (
        db.query(AttendanceSession, Classroom.room_name, Subject.subject_name, Subject.subject_code)
        .join(Classroom, AttendanceSession.classroom_id == Classroom.id)
        .join(Subject, AttendanceSession.subject_id == Subject.id)
        .filter(AttendanceSession.faculty_id == current_faculty.id)
        .order_by(AttendanceSession.start_time.desc())
        .limit(20)
        .all()
    )

    classrooms = db.query(Classroom).all()

    # Query subjects via junction table (many-to-many)
    subjects = (
        db.query(Subject)
        .join(FacultySubject, FacultySubject.subject_id == Subject.id)
        .filter(FacultySubject.faculty_id == current_faculty.id)
        .all()
    )

    return {
        "faculty_name": current_faculty.name,
        "department":   getattr(current_faculty, "department", None),
        "sessions": [
            {
                "id":             s.AttendanceSession.id,
                "classroom_id":   s.AttendanceSession.classroom_id,
                "classroom_name": s.room_name,
                "subject_id":     s.AttendanceSession.subject_id,
                "subject_name":   s.subject_name,
                "subject_code":   s.subject_code,
                # attendance_code intentionally omitted — internal only
                "start_time":     s.AttendanceSession.start_time.isoformat(),
                "end_time":       s.AttendanceSession.end_time.isoformat() if s.AttendanceSession.end_time else None,
                "is_active":      s.AttendanceSession.is_active,
            }
            for s in sessions
        ],
        "classrooms": [
            {"id": c.id, "room_name": c.room_name, "ble_uuid": c.ble_uuid}
            for c in classrooms
        ],
        "subjects": [
            {
                "id":           s.id,
                "subject_name": s.subject_name,
                "subject_code": s.subject_code,
                "department":   s.department,
                "faculty_id":   s.faculty_id,
            }
            for s in subjects
        ],
    }


# ─── POST /faculty/create-session ────────────────────────────

@router.post("/create-session", status_code=status.HTTP_201_CREATED)
async def create_session(
    request: CreateSessionRequest,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Create a new attendance session.
    Automatically generates and persists an attendance link.
    Returns session info + shareable links (no attendance code in response).
    """
    # Validate classroom and subject exist
    classroom = db.query(Classroom).filter(
        Classroom.id == request.classroom_id
    ).first()
    if not classroom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Classroom not found",
        )

    # Validate subject is assigned to this faculty via junction table
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
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Subject not found or not assigned to you",
        )

    # Deactivate any other active sessions in this classroom
    db.query(AttendanceSession).filter(
        AttendanceSession.classroom_id == request.classroom_id,
        AttendanceSession.is_active == True,
    ).update({"is_active": False})

    # Create new session
    session = AttendanceSession(
        classroom_id=request.classroom_id,
        subject_id=request.subject_id,
        faculty_id=current_faculty.id,
        attendance_code=request.attendance_code,  # stored internally
        is_active=True,
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Generate and store attendance link
    link = create_attendance_link(
        db=db,
        session=session,
        classroom_name=classroom.room_name,
        subject_name=subject.subject_name,
        faculty_name=current_faculty.name,
        base_url=settings.APP_BASE_URL,
    )

    return {
        "id":             session.id,
        "classroom_id":   session.classroom_id,
        "classroom_name": classroom.room_name,
        "subject_id":     session.subject_id,
        "subject_name":   subject.subject_name,
        "start_time":     session.start_time.isoformat(),
        "end_time":       None,
        "is_active":      True,
        # Link info — NO attendance code
        "deep_link":      link.deep_link,
        "web_link":       link.web_link,
        "whatsapp_url":   link.whatsapp_url,
    }


# ─── PUT /faculty/end-session/{session_id} ───────────────────

@router.put("/end-session/{session_id}")
async def end_session(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """End an active session and deactivate its attendance link."""
    from datetime import datetime
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == session_id,
        AttendanceSession.faculty_id == current_faculty.id,
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    session.is_active = False
    session.end_time  = datetime.now()

    # Deactivate associated links
    db.query(AttendanceLink).filter(
        AttendanceLink.session_id == session_id
    ).update({"is_active": False})

    db.commit()
    return {"message": "Session ended successfully"}


# ─── POST /faculty/stop-session ──────────────────────────────
# POST alias as required by spec

@router.post("/stop-session/{session_id}")
async def stop_session(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Stop (end) an active session. POST alias of PUT /faculty/end-session."""
    return await end_session(session_id, current_faculty, db)


# ─── GET /faculty/whatsapp-link ──────────────────────────────

@router.get("/whatsapp-link", response_model=AttendanceLinkResponse)
async def get_whatsapp_link(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Get or regenerate the WhatsApp attendance link for a session.

    The message does NOT include the attendance code — only the deep link.
    BLE + Face Verification are the attendance methods.
    """
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == session_id,
        AttendanceSession.faculty_id == current_faculty.id,
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()

    classroom_name = classroom.room_name if classroom else "Unknown"
    subject_name   = subject.subject_name if subject else "Unknown"

    # Check for existing active link
    link = db.query(AttendanceLink).filter(
        AttendanceLink.session_id == session_id,
        AttendanceLink.is_active == True,
    ).first()

    if not link:
        # Re-generate
        link = create_attendance_link(
            db=db,
            session=session,
            classroom_name=classroom_name,
            subject_name=subject_name,
            faculty_name=current_faculty.name,
            base_url=settings.APP_BASE_URL,
        )

    return AttendanceLinkResponse(
        session_id=session.id,
        token=link.token,
        deep_link=link.deep_link,
        web_link=link.web_link,
        whatsapp_url=link.whatsapp_url,
        message=(
            f"📚 *SmartAttend — Attendance Open*\n\n"
            f"Subject: *{subject_name}*\n"
            f"Classroom: *{classroom_name}*\n"
            f"Faculty: *{current_faculty.name}*\n\n"
            f"Tap the link below to mark your attendance:\n"
            f"{link.web_link}\n\n"
            f"_Make sure Bluetooth is ON and you are inside the classroom._\n"
            f"_BLE + Face Verification required._"
        ),
        classroom=classroom_name,
        subject=subject_name,
        faculty=current_faculty.name,
        is_active=session.is_active,
    )


# ─── POST /faculty/share-link ─────────────────────────────────
# Required by spec as a POST endpoint

@router.post("/share-link", response_model=AttendanceLinkResponse)
async def share_link(
    session_id: int,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    POST version of link generation (spec requirement).
    Same behaviour as GET /faculty/whatsapp-link but as a POST.
    Regenerates the link and returns it.
    """
    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == session_id,
        AttendanceSession.faculty_id == current_faculty.id,
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session not found",
        )

    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()

    classroom_name = classroom.room_name if classroom else "Unknown"
    subject_name   = subject.subject_name if subject else "Unknown"

    link = create_attendance_link(
        db=db,
        session=session,
        classroom_name=classroom_name,
        subject_name=subject_name,
        faculty_name=current_faculty.name,
        base_url=settings.APP_BASE_URL,
    )

    return AttendanceLinkResponse(
        session_id=session.id,
        token=link.token,
        deep_link=link.deep_link,
        web_link=link.web_link,
        whatsapp_url=link.whatsapp_url,
        message=(
            f"📚 *SmartAttend — Attendance Open*\n\n"
            f"Subject: *{subject_name}*\n"
            f"Classroom: *{classroom_name}*\n"
            f"Faculty: *{current_faculty.name}*\n\n"
            f"Tap the link below to mark your attendance:\n"
            f"{link.web_link}\n\n"
            f"_Make sure Bluetooth is ON and you are inside the classroom._\n"
            f"_BLE + Face Verification required._"
        ),
        classroom=classroom_name,
        subject=subject_name,
        faculty=current_faculty.name,
        is_active=session.is_active,
    )


# ─── GET /faculty/attendance-report ──────────────────────────

@router.get("/attendance-report")
async def get_attendance_report(
    period: str = "weekly",
    session_id: Optional[int] = None,
    subject_id: Optional[int] = None,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Return attendance records for the faculty's sessions."""
    data = _get_attendance_data(
        db=db,
        faculty_id=current_faculty.id,
        period=period,
        session_id=session_id,
        subject_id=subject_id,
    )

    return [
        {
            "id":             r["id"],
            "student_name":   r["student_name"],
            "classroom_name": r["classroom"],
            "subject_name":   r["subject"],
            "date":           r["date"],
            "time":           r["time"],
            "status":         r["status"],
            "rssi":           r["rssi"],
        }
        for r in data
    ]


# ─── Period-based report aliases (spec requirement) ───────────

@router.get("/reports/daily")
async def reports_daily(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/reports/daily — daily attendance report."""
    return await get_attendance_report("daily", None, None, current_faculty, db)


@router.get("/reports/weekly")
async def reports_weekly(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/reports/weekly — weekly attendance report."""
    return await get_attendance_report("weekly", None, None, current_faculty, db)


@router.get("/reports/monthly")
async def reports_monthly(
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/reports/monthly — monthly attendance report."""
    return await get_attendance_report("monthly", None, None, current_faculty, db)


# ─── GET /faculty/live-attendance ────────────────────────────

@router.get("/live-attendance")
async def live_attendance(
    session_id: Optional[int] = None,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Return real-time list of students who have marked attendance
    for an active session. If session_id is omitted, uses the
    most recent active session for this faculty.
    """
    if session_id:
        session = db.query(SessionModel).filter(
            SessionModel.id == session_id,
            SessionModel.faculty_id == current_faculty.id,
        ).first()
    else:
        session = db.query(AttendanceSession).filter(
            AttendanceSession.faculty_id == current_faculty.id,
            AttendanceSession.is_active == True,
        ).order_by(AttendanceSession.start_time.desc()).first()

    if not session:
        return {
            "session_id":       None,
            "is_active":        False,
            "attendance_count": 0,
            "students":         [],
        }

    rows = (
        db.query(Attendance, Student.name.label("student_name"), Student.reg_no)
        .join(Student, Attendance.student_id == Student.id)
        .filter(Attendance.session_id == session.id)
        .order_by(Attendance.marked_at.asc())
        .all()
    )

    return {
        "session_id":       session.id,
        "is_active":        session.is_active,
        "start_time":       session.start_time.isoformat(),
        "attendance_count": len(rows),
        "students": [
            {
                "student_id":     r.Attendance.student_id,
                "student_name":   r.student_name,
                "reg_no":         r.reg_no,
                "time":           r.Attendance.time,
                "rssi":           r.Attendance.rssi,
                "face_confidence": r.Attendance.face_confidence,
                "status":         r.Attendance.status,
            }
            for r in rows
        ],
    }


# ─── GET /faculty/export/{format} ────────────────────────────

@router.get("/export/{fmt}")
async def export_report(
    fmt: str,
    period: str = "monthly",
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Export attendance report. Supported formats: csv, xlsx, pdf"""
    return await _do_export(fmt, period, current_faculty, db)


# ─── Spec top-level export aliases ───────────────────────────

@router.get("/export/excel")
async def export_excel(
    period: str = "monthly",
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/export/excel — export as XLSX."""
    return await _do_export("xlsx", period, current_faculty, db)


@router.get("/export/pdf")
async def export_pdf(
    period: str = "monthly",
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/export/pdf — export as PDF."""
    return await _do_export("pdf", period, current_faculty, db)


@router.get("/export/csv")
async def export_csv(
    period: str = "monthly",
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """GET /faculty/export/csv — export as CSV."""
    return await _do_export("csv", period, current_faculty, db)


async def _do_export(
    fmt: str,
    period: str,
    faculty: Faculty,
    db: Session,
) -> Response:
    """Internal helper: build and return export response."""
    fmt = fmt.lower()
    if fmt not in ["csv", "xlsx", "pdf"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported format. Use csv, xlsx, or pdf.",
        )

    data = _get_attendance_data(db=db, faculty_id=faculty.id, period=period)

    if fmt == "csv":
        content   = generate_csv(data)
        media_type = "text/csv"
        filename  = "attendance_report.csv"
    elif fmt == "xlsx":
        content   = generate_excel(data)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename  = "attendance_report.xlsx"
    else:
        content   = generate_pdf(data, title=f"{period.title()} Report")
        media_type = "application/pdf"
        filename  = "attendance_report.pdf"

    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ─── POST /faculty/subjects ──────────────────────────────────

@router.post("/subjects", status_code=status.HTTP_201_CREATED)
async def create_subject(
    request: dict,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """Allow faculty to create their own subjects."""
    subject = Subject(
        subject_name=request.get("subject_name", ""),
        subject_code=request.get("subject_code"),
        department=request.get("department"),
        faculty_id=current_faculty.id,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)

    # Automatically associate the subject to the faculty in the junction table
    link = FacultySubject(faculty_id=current_faculty.id, subject_id=subject.id)
    db.add(link)
    db.commit()

    return {
        "id":           subject.id,
        "subject_name": subject.subject_name,
        "subject_code": subject.subject_code,
        "department":   subject.department,
        "faculty_id":   subject.faculty_id,
    }


# ─── POST /faculty/generate-qr ───────────────────────────────

@router.post("/generate-qr")
async def generate_qr_token(
    request: dict,
    current_faculty: Faculty = Depends(get_current_faculty),
    db: Session = Depends(get_db),
):
    """
    Generate a time-limited QR token for a session.

    The token is a signed JWT containing session_id, faculty_id, and expiry.
    Students scan this QR code as a BLE fallback to mark attendance.
    Token expires in 10 minutes.
    """
    import jwt
    from datetime import datetime, timedelta

    session_id = request.get("session_id")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="session_id is required",
        )

    session = db.query(AttendanceSession).filter(
        AttendanceSession.id == session_id,
        AttendanceSession.faculty_id == current_faculty.id,
        AttendanceSession.is_active == True,
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Active session not found or you are not the session owner",
        )

    # Build token payload
    expires_at = datetime.utcnow() + timedelta(minutes=10)
    payload = {
        "session_id": session_id,
        "faculty_id": current_faculty.id,
        "type": "qr_attendance",
        "exp": expires_at,
        "iat": datetime.utcnow(),
    }

    # Sign with app secret
    secret = getattr(settings, "SECRET_KEY", "smartattend_qr_secret")
    token = jwt.encode(payload, secret, algorithm="HS256")

    logger.info(
        f"QR token generated: faculty={current_faculty.id}, session={session_id}, "
        f"expires={expires_at.isoformat()}"
    )

    return {
        "token": token,
        "session_id": session_id,
        "expires_at": expires_at.isoformat() + "Z",
        "valid_for_seconds": 600,
    }

