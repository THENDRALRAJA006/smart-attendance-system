# ============================================================
# SmartAttend — Attendance Routes (v3)
# POST /attendance/verify   — Pre-check: session active + RSSI
# POST /attendance/mark     — Face verify + mark attendance
# GET  /attendance/session/{session_id} — Session info
# ============================================================

import logging
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.models.models import Student, Session as SessionModel, Classroom, Subject, Faculty, Attendance
from app.services.attendance_service import (
    get_session_by_id,
    check_duplicate_attendance,
    validate_rssi,
    validate_student_eligibility,
    mark_attendance,
)
from app.services.rekognition_service import rekognition_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/attendance", tags=["Attendance"])


# ─── POST /attendance/verify ─────────────────────────────────
@router.post("/verify")
async def verify_attendance_eligibility(
    session_id: int = Form(...),
    rssi: int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Pre-check attendance eligibility before face capture.

    Validates:
    1. Session exists and is active
    2. Student hasn't already marked attendance
    3. BLE RSSI is above threshold (student is physically in range)

    Returns session info so the app can display subject/classroom.
    """
    # 1. Fetch active session
    session = get_session_by_id(db, session_id)

    # 2. Duplicate check
    existing = db.query(Attendance).filter_by(
        student_id=current_student.id, session_id=session_id
    ).first()
    if existing:
        return {
            "eligible": False,
            "step": "duplicate",
            "message": "Attendance already marked for this session.",
        }

    # 3. RSSI threshold check — skip if rssi == 0 (initial fetch before BLE scan)
    if rssi != 0 and rssi < -70:
        return {
            "eligible": False,
            "step": "out_of_range",
            "message": f"Out of classroom range (RSSI {rssi} dBm). Move closer to the classroom.",
        }

    # Fetch classroom + subject info for display
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()

    return {
        "eligible": True,
        "step": "face_capture",
        "session_id": session.id,
        "subject_name": subject.subject_name if subject else "",
        "subject_code": subject.subject_code if subject else "",
        "classroom_name": classroom.room_name if classroom else "",
        "classroom_uuid": classroom.ble_uuid if classroom else "",
        "message": "Eligible. Please capture your face.",
    }


# ─── POST /attendance/mark ────────────────────────────────────
@router.post("/mark")
async def mark_student_attendance(
    file: UploadFile = File(...),
    session_id: int = Form(...),
    rssi: int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Mark attendance for an authenticated student.

    Flow:
    1. Validate session is active
    2. Check for duplicate attendance (409 if already marked)
    3. Validate BLE RSSI (student must be in classroom range)
    4. Validate student eligibility for this subject/department
    5. Verify face via AWS Rekognition
    6. Mark attendance record in DB

    Returns face match result and attendance confirmation.
    """
    # 1. Validate session
    session = get_session_by_id(db, session_id)

    # 2. Duplicate check → 409
    check_duplicate_attendance(db, current_student.id, session_id)

    # 3. RSSI check
    validate_rssi(rssi)

    # 4. Student eligibility
    validate_student_eligibility(db, current_student, session)

    # 5. Face not registered check
    if not current_student.face_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face not registered. Please register your face first via the app.",
        )

    # 6. Read image and verify face
    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image file. Please capture again.",
        )

    face_result = rekognition_service.verify_face(image_bytes, current_student.face_id)

    if not face_result.get("match"):
        confidence = face_result.get("confidence", 0.0)
        logger.warning(
            f"Face mismatch: student={current_student.id}, "
            f"session={session_id}, confidence={confidence:.1f}%"
        )
        return {
            "match": False,
            "confidence": confidence,
            "message": f"Face not recognized ({confidence:.1f}% confidence). Please try again in better lighting.",
        }

    confidence = face_result.get("confidence", 0.0)

    # 7. Mark attendance
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=rssi,
        face_confidence=confidence,
    )

    # Fetch display info
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    faculty = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()

    logger.info(
        f"✅ Attendance marked: student={current_student.id} ({current_student.name}), "
        f"session={session_id}, subject={subject.subject_name if subject else 'N/A'}, "
        f"confidence={confidence:.1f}%"
    )

    return {
        "match": True,
        "confidence": confidence,
        "attendance_id": record.id,
        "message": "Attendance marked successfully! ✅",
        "student_name": current_student.name,
        "subject_name": subject.subject_name if subject else "",
        "subject_code": subject.subject_code if subject else "",
        "classroom_name": classroom.room_name if classroom else "",
        "faculty_name": faculty.name if faculty else "",
        "date": record.date.isoformat(),
        "time": str(record.time) if record.time else None,
        "status": record.status,
    }


# ─── GET /attendance/session/{session_id} ────────────────────
@router.get("/session/{session_id}")
async def get_session_info(
    session_id: int,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Get session info by ID (used when deep link arrives).
    Returns classroom UUID so BLE matching can be validated client-side.
    """
    session = get_session_by_id(db, session_id)
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    faculty = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()

    return {
        "session_id": session.id,
        "subject_name": subject.subject_name if subject else "",
        "subject_code": subject.subject_code if subject else "",
        "classroom_name": classroom.room_name if classroom else "",
        "classroom_uuid": classroom.ble_uuid if classroom else "",
        "faculty_name": faculty.name if faculty else "",
        "is_active": session.is_active,
        "start_time": session.start_time.isoformat(),
    }


# ─── POST /attendance/mark-qr ────────────────────────────────
@router.post("/mark-qr")
async def mark_attendance_via_qr(
    request: dict,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Mark attendance using a QR token scanned from the faculty's screen.

    Flow:
    1. Decode + verify the JWT QR token (signed by faculty's generate-qr endpoint)
    2. Confirm token type == 'qr_attendance'
    3. Check session is still active
    4. Check for duplicate attendance (409 if already marked)
    5. Mark attendance with status='present', rssi=0 (QR mode)

    This is the BLE fallback — no face verification required for QR mode.
    """
    import jwt
    from datetime import datetime
    from app.core.config import settings

    qr_token = request.get("qr_token", "")
    if not qr_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="qr_token is required",
        )

    # 1. Decode and verify the JWT
    secret = getattr(settings, "SECRET_KEY", "smartattend_qr_secret")
    try:
        payload = jwt.decode(qr_token, secret, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="QR code has expired. Ask your faculty to generate a new one.",
        )
    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid QR code: {str(e)}",
        )

    # 2. Validate token type
    if payload.get("type") != "qr_attendance":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid QR token type",
        )

    session_id = payload.get("session_id")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="QR token missing session_id",
        )

    # 3. Check session is active
    session = db.query(SessionModel).filter(
        SessionModel.id == session_id,
        SessionModel.is_active == True,
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Session is no longer active",
        )

    # 4. Duplicate check
    check_duplicate_attendance(db, current_student.id, session_id)

    # 5. Mark attendance (QR mode — no face, rssi=0)
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=0,           # QR mode — no BLE
        face_confidence=0.0,  # No face verification in QR fallback
    )

    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    faculty = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()

    logger.info(
        f"✅ QR Attendance marked: student={current_student.id} ({current_student.name}), "
        f"session={session_id}, subject={subject.subject_name if subject else 'N/A'}"
    )

    return {
        "marked": True,
        "attendance_id": record.id,
        "message": "QR Attendance marked successfully! ✅",
        "student_name": current_student.name,
        "subject_name": subject.subject_name if subject else "",
        "classroom_name": classroom.room_name if classroom else "",
        "faculty_name": faculty.name if faculty else "",
        "date": record.date.isoformat(),
        "time": str(record.time) if record.time else None,
        "method": "qr",
    }

