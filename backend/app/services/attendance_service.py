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

from app.models.models import Attendance, Session as SessionModel, Classroom, Student, AttendanceLink, BleBeacon

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
    logger.info(f"[SESSION] Looking up session_id={session_id}")

    session = db.query(SessionModel).filter(
        SessionModel.id == session_id
    ).first()

    if not session:
        logger.warning(
            f"[SESSION] NOT FOUND: session_id={session_id} — "
            f"no row in sessions table"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found. The link may be invalid.",
        )

    logger.info(
        f"[SESSION] Found: session_id={session_id}, "
        f"classroom_id={session.classroom_id}, "
        f"subject_id={session.subject_id}, "
        f"faculty_id={session.faculty_id}, "
        f"is_active={session.is_active}, "
        f"start_time={session.start_time}"
    )

    if not session.is_active:
        logger.warning(
            f"[SESSION] INACTIVE: session_id={session_id}, "
            f"end_time={session.end_time}"
        )
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

def validate_rssi(
    rssi: int,
    threshold: int = RSSI_THRESHOLD,
    classroom_id: int | None = None,
    db: Session | None = None,
) -> None:
    """
    Validate BLE signal strength.

    rssi == 0 is a special bypass value used during pre-check (before BLE scan)
    or QR fallback mode — skip threshold enforcement in that case.

    Args:
        rssi: Received signal strength (dBm)
        threshold: Fallback minimum RSSI (default -70 dBm)
        classroom_id: If provided + db given, loads per-beacon threshold from DB
        db: SQLAlchemy session — required for per-beacon threshold lookup

    Raises:
        HTTPException 403: Out of range
    """
    # rssi == 0 is the bypass sentinel value (QR mode / pre-BLE scan)
    if rssi == 0:
        logger.info(
            f"[BLE] RSSI=0 bypass — skipping threshold check "
            f"(classroom_id={classroom_id})"
        )
        return

    # Load per-classroom threshold from BleBeacon table if available
    effective_threshold = threshold
    if classroom_id and db:
        beacon = db.query(BleBeacon).filter(
            BleBeacon.classroom_id == classroom_id,
            BleBeacon.is_active == True,
        ).first()
        if beacon:
            effective_threshold = beacon.rssi_threshold
            logger.debug(
                f"[BLE] Per-beacon threshold for classroom_id={classroom_id}: "
                f"{effective_threshold} dBm"
            )
        else:
            logger.debug(
                f"[BLE] No beacon config for classroom_id={classroom_id}, "
                f"using global threshold {effective_threshold} dBm"
            )

    if rssi < effective_threshold:
        logger.warning(
            f"[BLE] OUT OF RANGE: rssi={rssi} dBm < threshold={effective_threshold} dBm, "
            f"classroom_id={classroom_id}"
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Out of classroom range (RSSI {rssi} dBm < threshold {effective_threshold} dBm). "
                "Please move closer to the classroom."
            ),
        )

    logger.info(
        f"[BLE] IN RANGE: rssi={rssi} dBm >= threshold={effective_threshold} dBm, "
        f"classroom_id={classroom_id}"
    )


# ─── Student Eligibility ─────────────────────────────────────

def validate_student_eligibility(
    db: Session,
    student: Student,
    session: SessionModel,
) -> None:
    """
    Verify that the student is eligible for this attendance session.

    Department check:
    - Only enforced when subject.department is non-empty
    - Comparison is case-insensitive and whitespace-stripped
    - Logs a warning but does NOT reject if department is null/empty
      (supports cross-department electives)

    Raises:
        HTTPException 403: Student clearly not eligible (department mismatch)
    """
    from app.models.models import Subject

    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()

    if not subject:
        # Subject was deleted after session was created — allow attendance
        logger.warning(
            f"[ELIGIBILITY] Subject id={session.subject_id} not found — "
            f"skipping department check for student_id={student.id}"
        )
        return

    # Only enforce department check if the subject has a non-empty department set
    if subject.department and subject.department.strip():
        student_dept = student.department.strip().lower() if student.department else ""
        subject_dept = subject.department.strip().lower()

        logger.info(
            f"[ELIGIBILITY] student_id={student.id} ({student.name}), "
            f"student_dept='{student.department}', "
            f"subject_dept='{subject.department}', "
            f"session_id={session.id}"
        )

        if student_dept and subject_dept and student_dept != subject_dept:
            logger.warning(
                f"[ELIGIBILITY] REJECTED: student_id={student.id} "
                f"dept='{student.department}' != subject dept='{subject.department}' "
                f"for session_id={session.id}"
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    f"You are not eligible for this session. "
                    f"Session is for '{subject.department}' department, "
                    f"but your department is '{student.department}'. "
                    f"Contact your faculty if this is incorrect."
                ),
            )

        logger.info(
            f"[ELIGIBILITY] APPROVED: student_id={student.id} "
            f"matches dept='{subject.department}'"
        )
    else:
        # No department restriction configured — allow all students
        logger.info(
            f"[ELIGIBILITY] No department restriction on "
            f"subject_id={session.subject_id} ('{getattr(subject, 'subject_name', '')}'), "
            f"student_id={student.id} approved"
        )


# ─── Mark Attendance ─────────────────────────────────────────

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
    """
    Create an attendance record after all validations pass.

    v4 args:
        liveness_verified: True if student passed blink/smile/movement challenge
        confidence_tier: 'present' | 'manual_review' | 'rejected'
        attendance_method: 'ble_face' | 'qr'

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
        status=confidence_tier,           # v4: status reflects tier
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
        f"[ATTENDANCE_MARKING] Attendance record created: student={student_id}, "
        f"session={session.id}, confidence={face_confidence:.1f}%, "
        f"tier={confidence_tier}, liveness={liveness_verified}, "
        f"classroom_id={session.classroom_id}, subject_id={session.subject_id}, "
        f"rssi={rssi} dBm, method={attendance_method}"
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
