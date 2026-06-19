# ============================================================
# SmartAttend — Attendance Business Logic Service (v3)
# Duplicate checking, session validation, marking, link creation
# ============================================================

import logging
import urllib.parse
import uuid
from datetime import date, datetime
from sqlalchemy.orm import Session
from fastapi import HTTPException, status

from app.models.models import Attendance, Session as SessionModel, Classroom, Student, AttendanceLink

logger = logging.getLogger(__name__)

# RSSI threshold — must be above this to mark attendance
RSSI_THRESHOLD = -70


# ─── Session Lookup ──────────────────────────────────────────

def get_active_session(db: Session, classroom_name: str) -> SessionModel:
    """
    Find the active session for the given classroom name.

    Args:
        db: Database session
        classroom_name: e.g. 'CLASSROOM_A101'

    Returns:
        Active SessionModel

    Raises:
        HTTPException 404: No active session
    """
    classroom = db.query(Classroom).filter(
        Classroom.room_name == classroom_name
    ).first()

    if not classroom:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Classroom '{classroom_name}' not found",
        )

    active_session = (
        db.query(SessionModel)
        .filter(
            SessionModel.classroom_id == classroom.id,
            SessionModel.is_active == True,
        )
        .order_by(SessionModel.start_time.desc())
        .first()
    )

    if not active_session:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="No active session in this classroom. Please ask faculty to start a session.",
        )

    return active_session


def get_session_by_id(db: Session, session_id: int) -> SessionModel:
    """
    Look up a session by its ID (used in deep-link flow).

    Args:
        db: Database session
        session_id: The session ID from the deep link / WhatsApp link

    Returns:
        Active SessionModel

    Raises:
        HTTPException 404: Session not found
        HTTPException 409: Session no longer active
    """
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found. The link may be invalid.",
        )

    if not session.is_active:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This attendance session has ended. Contact your faculty.",
        )

    return session


# ─── Duplicate Check ──────────────────────────────────────────

def check_duplicate_attendance(
    db: Session, student_id: int, session_id: int
) -> None:
    """
    Ensure student hasn't already marked attendance for this session.

    Raises:
        HTTPException 409: Already marked
    """
    existing = (
        db.query(Attendance)
        .filter(
            Attendance.student_id == student_id,
            Attendance.session_id == session_id,
        )
        .first()
    )

    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Attendance already marked for this session",
        )


# ─── RSSI Validation ─────────────────────────────────────────

def validate_rssi(rssi: int, threshold: int = RSSI_THRESHOLD) -> None:
    """
    Validate BLE signal strength.

    Args:
        rssi: Received signal strength (dBm)
        threshold: Minimum acceptable RSSI (default -70 dBm)

    Raises:
        HTTPException 403: Out of range
    """
    if rssi < threshold:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Out of classroom range (RSSI {rssi} dBm < threshold {threshold} dBm). "
                   "Please move closer to the classroom.",
        )


# ─── Student Eligibility ─────────────────────────────────────

def validate_student_eligibility(
    db: Session,
    student: Student,
    session: SessionModel,
) -> None:
    """
    Verify that the student belongs to the correct department/year/section
    for this attendance session.

    Uses the subject's department field for cross-checking.

    Raises:
        HTTPException 403: Student not eligible for this session
    """
    from app.models.models import Subject

    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()

    if subject and subject.department:
        # Only enforce if the subject has a department set
        if student.department.strip().lower() != subject.department.strip().lower():
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"You are not eligible for this session. "
                    f"Session is for '{subject.department}', "
                    f"but your department is '{student.department}'."
                ),
            )


# ─── Mark Attendance ─────────────────────────────────────────

def mark_attendance(
    db: Session,
    student_id: int,
    session: SessionModel,
    rssi: int,
    face_confidence: float,
) -> Attendance:
    """
    Create an attendance record after all validations pass.

    Returns:
        Created Attendance object
    """
    now = datetime.now()

    record = Attendance(
        student_id=student_id,
        classroom_id=session.classroom_id,
        subject_id=session.subject_id,
        session_id=session.id,
        date=now.date(),
        time=now.strftime("%H:%M"),
        status="present",
        rssi=rssi,
        face_confidence=face_confidence,
    )

    db.add(record)
    db.commit()
    db.refresh(record)

    logger.info(
        f"Attendance marked: student={student_id}, "
        f"session={session.id}, confidence={face_confidence:.1f}%"
    )
    return record


# ─── Attendance Link Creation ─────────────────────────────────

def create_attendance_link(
    db: Session,
    session: SessionModel,
    classroom_name: str,
    subject_name: str,
    faculty_name: str,
    base_url: str = "https://smartattend.app",
) -> AttendanceLink:
    """
    Generate and persist a unique attendance link for a session.

    The link is the PRIMARY attendance method. The WhatsApp message
    does NOT include the internal attendance code — only BLE + face
    verification is required.

    Returns:
        Persisted AttendanceLink object
    """
    token = uuid.uuid4().hex
    deep_link = f"smartattend://attendance/{session.id}"
    web_link  = f"{base_url}/attendance/{session.id}"

    message = (
        f"📚 *SmartAttend — Attendance Open*\n\n"
        f"Subject: *{subject_name}*\n"
        f"Classroom: *{classroom_name}*\n"
        f"Faculty: *{faculty_name}*\n\n"
        f"Tap the link below to mark your attendance:\n"
        f"{web_link}\n\n"
        f"_Make sure Bluetooth is ON and you are inside the classroom._\n"
        f"_BLE + Face Verification required._"
    )

    whatsapp_url = f"https://wa.me/?text={urllib.parse.quote(message)}"

    # Deactivate any previous links for this session
    db.query(AttendanceLink).filter(
        AttendanceLink.session_id == session.id
    ).update({"is_active": False})

    link = AttendanceLink(
        session_id=session.id,
        token=token,
        deep_link=deep_link,
        web_link=web_link,
        whatsapp_url=whatsapp_url,
        is_active=True,
    )
    db.add(link)
    db.commit()
    db.refresh(link)

    logger.info(f"Attendance link created: session={session.id}, token={token}")
    return link
