import logging
import secrets
from datetime import datetime
from urllib.parse import quote

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.models import (
    Attendance,
    AttendanceDeviceLog,
    AttendanceLink,
    BleBeacon,
    Session as SessionModel,
    Student,
    Subject,
)

logger = logging.getLogger(__name__)

RSSI_THRESHOLD = -80


def create_attendance_link(
    db: Session,
    session: SessionModel,
    classroom_name: str,
    subject_name: str,
    faculty_name: str,
    base_url: str,
) -> AttendanceLink:
    """Create and store a shareable attendance link."""

    token = secrets.token_urlsafe(32)
    base_url = base_url.rstrip("/")

    deep_link = f"smartattend://attendance/{session.id}"
    web_link = f"{base_url}/attendance?session_id={session.id}"

    message = (
        f"SmartAttend Attendance Link\n"
        f"Subject: {subject_name}\n"
        f"Classroom: {classroom_name}\n"
        f"Faculty: {faculty_name}\n"
        f"Open link: {web_link}"
    )

    whatsapp_url = f"https://wa.me/?text={quote(message)}"

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

    logger.info(
        "[ATTENDANCE_LINK] Created link_id=%s for session_id=%s",
        link.id,
        session.id,
    )

    return link


def get_session_by_id(
    db: Session,
    session_id: int,
) -> SessionModel:
    """Return an active attendance session."""

    logger.info("[SESSION] Looking up session_id=%s", session_id)

    attendance_session = (
        db.query(SessionModel)
        .filter(SessionModel.id == session_id)
        .first()
    )

    if attendance_session is None:
        logger.warning(
            "[SESSION] NOT FOUND: session_id=%s",
            session_id,
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found. The link may be invalid.",
        )

    if not attendance_session.is_active:
        logger.warning(
            "[SESSION] INACTIVE: session_id=%s, end_time=%s",
            session_id,
            attendance_session.end_time,
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This attendance session has ended. Contact your faculty.",
        )

    logger.info(
        "[SESSION] Found: session_id=%s, classroom_id=%s, "
        "subject_id=%s, faculty_id=%s, start_time=%s",
        attendance_session.id,
        attendance_session.classroom_id,
        attendance_session.subject_id,
        attendance_session.faculty_id,
        attendance_session.start_time,
    )

    return attendance_session


def check_duplicate_attendance(
    db: Session,
    student_id: int,
    session_id: int,
) -> None:
    """Prevent duplicate attendance for the same session."""

    existing_record = (
        db.query(Attendance)
        .filter(
            Attendance.student_id == student_id,
            Attendance.session_id == session_id,
        )
        .first()
    )

    if existing_record is not None:
        logger.warning(
            "[ATTENDANCE] Duplicate: student_id=%s, session_id=%s",
            student_id,
            session_id,
        )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Attendance has already been marked for this session.",
        )


def validate_rssi(
    rssi: int,
    threshold: int = RSSI_THRESHOLD,
    classroom_id: int | None = None,
    db: Session | None = None,
) -> None:
    """Validate BLE signal strength."""

    # Bypass value used before BLE scanning and in QR fallback mode.
    if rssi == 0:
        logger.info(
            "[BLE] RSSI=0 bypass for classroom_id=%s",
            classroom_id,
        )
        return

    effective_threshold = threshold

    if classroom_id is not None and db is not None:
        beacon = (
            db.query(BleBeacon)
            .filter(
                BleBeacon.classroom_id == classroom_id,
                BleBeacon.is_active.is_(True),
            )
            .first()
        )

        if beacon is not None:
            effective_threshold = beacon.rssi_threshold
            logger.debug(
                "[BLE] Classroom threshold=%s for classroom_id=%s",
                effective_threshold,
                classroom_id,
            )

    if rssi < effective_threshold:
        logger.warning(
            "[BLE] OUT OF RANGE: rssi=%s, threshold=%s, classroom_id=%s",
            rssi,
            effective_threshold,
            classroom_id,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Out of classroom range "
                f"(RSSI {rssi} dBm < threshold "
                f"{effective_threshold} dBm). "
                "Please move closer to the classroom."
            ),
        )

    logger.info(
        "[BLE] IN RANGE: rssi=%s, threshold=%s, classroom_id=%s",
        rssi,
        effective_threshold,
        classroom_id,
    )


def validate_student_eligibility(
    db: Session,
    student: Student,
    session: SessionModel,
) -> None:
    """Verify that the student belongs to the subject's department."""

    logger.info(
        "[ELIGIBILITY] ========== ELIGIBILITY CHECK ==========\n"
        "  Student ID:     %s\n"
        "  Student Name:   %s\n"
        "  Student Dept:   '%s'\n"
        "  Student Year:   %s\n"
        "  Student Section: '%s'\n"
        "  Session ID:     %s\n"
        "  Subject ID:     %s\n"
        "  ===================================================",
        student.id,
        student.name,
        student.department,
        getattr(student, 'year', 'N/A'),
        getattr(student, 'section', 'N/A'),
        session.id,
        session.subject_id,
    )

    subject = (
        db.query(Subject)
        .filter(Subject.id == session.subject_id)
        .first()
    )

    if subject is None:
        logger.warning(
            "[ELIGIBILITY] ❌ Subject id=%s not found; skipping check",
            session.subject_id,
        )
        return

    logger.info(
        "[ELIGIBILITY] Subject found: id=%s, name='%s', dept='%s'",
        subject.id,
        subject.subject_name,
        subject.department,
    )

    if not subject.department or not subject.department.strip():
        logger.info(
            "[ELIGIBILITY] No department restriction: subject_id=%s, "
            "student_id=%s — allowing all students",
            subject.id,
            student.id,
        )
        return

    student_department = (
        student.department.strip().casefold()
        if student.department
        else ""
    )
    subject_department = subject.department.strip().casefold()

    logger.info(
        "[ELIGIBILITY] Comparing departments: student='%s' vs subject='%s' "
        "(casefold: '%s' vs '%s')",
        student.department,
        subject.department,
        student_department,
        subject_department,
    )

    # Allow missing student department, but reject a clear mismatch.
    if student_department and student_department != subject_department:
        logger.warning(
            "[ELIGIBILITY] ❌ REJECTED: student_id=%s (dept='%s') "
            "not eligible for session_id=%s (dept='%s')",
            student.id,
            student.department,
            session.id,
            subject.department,
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"You are not eligible for this session. "
                f"Session is for '{subject.department}' department, "
                f"but your department is '{student.department}'. "
                "Contact your faculty if this is incorrect."
            ),
        )

    logger.info(
        "[ELIGIBILITY] ✅ APPROVED: student_id=%s, session_id=%s "
        "(dept='%s' matched)",
        student.id,
        session.id,
        subject.department,
    )


def mark_attendance(
    db: Session,
    student_id: int,
    session: SessionModel,
    rssi: int,
    face_confidence: float,
    liveness_verified: bool = False,
    confidence_tier: str = "present",
    attendance_method: str = "ble_face",
) -> Attendance:
    """Create and return an attendance record."""

    valid_tiers = {"present", "manual_review", "rejected"}
    valid_methods = {"ble_face", "qr", "qr_face"}

    if confidence_tier not in valid_tiers:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid confidence tier: {confidence_tier}",
        )

    if attendance_method not in valid_methods:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Invalid attendance method: {attendance_method}",
        )

    now = datetime.now()

    record = Attendance(
        student_id=student_id,
        classroom_id=session.classroom_id,
        subject_id=session.subject_id,
        session_id=session.id,
        date=now.date(),
        time=now.strftime("%H:%M"),
        status=confidence_tier,
        rssi=rssi,
        face_confidence=face_confidence,
        liveness_verified=liveness_verified,
        confidence_tier=confidence_tier,
        attendance_method=attendance_method,
    )

    db.add(record)
    db.commit()
    db.refresh(record)

    logger.info(
        "[ATTENDANCE] Created: student_id=%s, session_id=%s, "
        "confidence=%.1f%%, tier=%s, liveness=%s, rssi=%s, method=%s",
        student_id,
        session.id,
        face_confidence,
        confidence_tier,
        liveness_verified,
        rssi,
        attendance_method,
    )

    return record


# ─── Session-scoped Device ID validation ─────────────────────────────────────

def check_device_in_session(
    db: Session,
    session_id: int,
    device_id: str,
    current_student_id: int,
) -> None:
    """
    Reject attendance if this Android device has ALREADY been used to mark
    attendance in the SAME session by a DIFFERENT student.

    Scope: per-session only. The phone is free to be used again in any
    OTHER session (morning vs afternoon class are independent).

    Args:
        db:                 SQLAlchemy session.
        session_id:         The current attendance session.
        device_id:          Android ANDROID_ID string from the device.
        current_student_id: The student currently trying to mark attendance.

    Raises:
        HTTPException 403: If the device was already used by a different student.
    """
    existing = (
        db.query(AttendanceDeviceLog)
        .filter(
            AttendanceDeviceLog.session_id == session_id,
            AttendanceDeviceLog.device_id  == device_id,
        )
        .first()
    )

    if existing is None:
        # No record → this device has not been used in this session yet. Allow.
        return

    if existing.student_id == current_student_id:
        # Same student re-attempting (e.g., retry after network failure). Allow;
        # the duplicate-attendance check will catch the actual duplicate.
        return

    # A DIFFERENT student already used this device in this session → reject.
    logger.warning(
        "[DEVICE_LOG] Device reuse blocked: session=%s, device=%s, "
        "previous_student=%s, current_student=%s",
        session_id,
        device_id,
        existing.student_id,
        current_student_id,
    )
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="This device has already been used to mark attendance for this attendance session.",
    )


def log_device_attendance(
    db: Session,
    session_id: int,
    student_id: int,
    device_id: str,
) -> AttendanceDeviceLog:
    """
    Write a device log entry after successful attendance is marked.
    Uses INSERT IGNORE semantics via a try/except so retries don't crash.
    """
    try:
        log_entry = AttendanceDeviceLog(
            session_id=session_id,
            student_id=student_id,
            device_id=device_id,
        )
        db.add(log_entry)
        db.commit()
        db.refresh(log_entry)
        logger.info(
            "[DEVICE_LOG] Logged: session=%s, student=%s, device=%s",
            session_id, student_id, device_id,
        )
        return log_entry
    except Exception as exc:
        # Unique constraint violation on retry — safe to swallow.
        db.rollback()
        logger.debug(
            "[DEVICE_LOG] Already exists (retry?): session=%s device=%s — %s",
            session_id, device_id, exc,
        )
        return (
            db.query(AttendanceDeviceLog)
            .filter(
                AttendanceDeviceLog.session_id == session_id,
                AttendanceDeviceLog.device_id  == device_id,
            )
            .first()
        )