# ============================================================
# SmartAttend — Attendance Routes (v4)
# POST /attendance/verify   — Pre-check: session active + RSSI
# POST /attendance/mark     — Face verify (tiers) + liveness + mark
# GET  /attendance/session/{session_id} — Session info
# ============================================================

import logging
from typing import Optional
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
from app.services.liveness_service import liveness_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/attendance", tags=["Attendance"])



# ─── POST /attendance/verify ─────────────────────────────────
@router.post("/verify", operation_id="attendance_verify_eligibility")
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
    logger.info(
        f"[VERIFY] student_id={current_student.id} ({current_student.name}), "
        f"session_id={session_id}, rssi={rssi} dBm"
    )

    # 1. Fetch active session
    session = get_session_by_id(db, session_id)

    logger.info(
        f"[VERIFY] session OK: classroom_id={session.classroom_id}, "
        f"subject_id={session.subject_id}"
    )

    # 2. Duplicate check
    existing = db.query(Attendance).filter_by(
        student_id=current_student.id, session_id=session_id
    ).first()
    if existing:
        logger.info(
            f"[VERIFY] DUPLICATE: student_id={current_student.id} "
            f"already marked session_id={session_id}"
        )
        return {
            "eligible": False,
            "step": "duplicate",
            "message": "Attendance already marked for this session.",
        }

    # 3. RSSI threshold check — skip if rssi == 0 (initial fetch before BLE scan)
    if rssi != 0 and rssi < -70:
        logger.warning(
            f"[VERIFY] OUT OF RANGE: student_id={current_student.id}, "
            f"rssi={rssi} dBm < -70 dBm, session_id={session_id}"
        )
        return {
            "eligible": False,
            "step": "out_of_range",
            "message": f"Out of classroom range (RSSI {rssi} dBm). Move closer to the classroom.",
        }

    # Fetch classroom + subject info for display
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()

    logger.info(
        f"[VERIFY] ELIGIBLE: student_id={current_student.id}, "
        f"session_id={session_id}, "
        f"classroom='{classroom.room_name if classroom else 'N/A'}', "
        f"subject='{subject.subject_name if subject else 'N/A'}', "
        f"rssi={rssi} dBm"
    )

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
@router.post("/mark", operation_id="attendance_mark")
async def mark_student_attendance(
    file: UploadFile = File(...),
    session_id: int = Form(...),
    rssi: int = Form(...),
    liveness_token: Optional[str] = Form(None),   # v4: optional liveness verification token
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Mark attendance for an authenticated student. (v4 enhanced)

    Flow:
    1. Validate session is active
    2. Check for duplicate attendance (409 if already marked)
    3. Validate BLE RSSI (student must be in classroom range)
    4. Validate student eligibility for this subject/department
    5. Verify face via AWS Rekognition with confidence tiers:
         >= 95%  -> present (auto-marked)
         90-95%  -> manual_review (marked, flagged for faculty)
         < 90%   -> rejected (not marked)
    6. Optional liveness verification (if liveness_token provided)
    7. Mark attendance record with tier + liveness info

    Returns face match result and attendance confirmation.
    """
    logger.info(
        f"[MARK] ▶ student_id={current_student.id} ({current_student.name}), "
        f"session_id={session_id}, rssi={rssi} dBm, "
        f"liveness_token={'present' if liveness_token else 'absent'}"
    )

    # 1. Validate session
    session = get_session_by_id(db, session_id)

    # 2. Duplicate check → 409
    check_duplicate_attendance(db, current_student.id, session_id)

    # 3. RSSI check — pass classroom_id for per-beacon threshold
    validate_rssi(rssi, classroom_id=session.classroom_id, db=db)

    # 4. Student eligibility
    validate_student_eligibility(db, current_student, session)

    # 5. Face not registered check
    if not current_student.face_id:
        logger.warning(
            f"[MARK] NO FACE: student_id={current_student.id} has no face_id registered"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face not registered. Please register your face first via the app.",
        )

    # 6. Read image and verify face with confidence tiers
    image_bytes = await file.read()
    if not image_bytes:
        logger.warning(f"[MARK] EMPTY IMAGE: student_id={current_student.id}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty image file. Please capture again.",
        )

    logger.info(
        f"[MARK] Running face verification: student_id={current_student.id}, "
        f"image_size={len(image_bytes)} bytes"
    )

    # v4: Use tiered verification (by student_id prefix in collection)
    face_result = rekognition_service.verify_face_with_tiers(
        image_bytes, current_student.id
    )

    tier       = face_result.get("tier", "rejected")
    confidence = face_result.get("confidence", 0.0)
    match      = face_result.get("match", False)

    logger.info(
        f"[MARK] Face result: student_id={current_student.id}, "
        f"match={match}, confidence={confidence:.1f}%, tier='{tier}'"
    )

    if tier == "rejected":
        logger.warning(
            f"[MARK] FACE REJECTED: student_id={current_student.id}, "
            f"session_id={session_id}, confidence={confidence:.1f}%"
        )
        return {
            "match": False,
            "tier": tier,
            "confidence": confidence,
            "message": face_result.get("message", "Face not recognized"),
        }

    # 7. Optional liveness verification
    liveness_verified = False
    if liveness_token:
        try:
            # Quick decode to check it's valid (frames already verified by client)
            liveness_service.decode_challenge_token(liveness_token)
            liveness_verified = True
            logger.info(
                f"[LIVENESS_RESULT] Liveness verified successfully for student_id={current_student.id}"
            )
        except Exception as e:
            liveness_verified = False
            logger.warning(
                f"[LIVENESS_RESULT] Liveness token invalid for student_id={current_student.id}, error={e}"
            )

    # 8. Mark attendance with tier + liveness info
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=rssi,
        face_confidence=confidence,
        liveness_verified=liveness_verified,
        confidence_tier=tier,
        attendance_method="ble_face",
    )

    # Fetch display info
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject   = db.query(Subject).filter(Subject.id == session.subject_id).first()
    faculty   = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()

    logger.info(
        f"[MARK] ✅ ATTENDANCE MARKED: "
        f"student_id={current_student.id} ({current_student.name}), "
        f"session_id={session_id}, "
        f"classroom='{classroom.room_name if classroom else 'N/A'}', "
        f"subject='{subject.subject_name if subject else 'N/A'}', "
        f"tier='{tier}', confidence={confidence:.1f}%, "
        f"liveness={liveness_verified}, rssi={rssi} dBm, "
        f"attendance_id={record.id}"
    )

    return {
        "match": match,
        "tier": tier,
        "confidence": confidence,
        "liveness_verified": liveness_verified,
        "attendance_id": record.id,
        "message": face_result.get("message", "Attendance marked!"),
        "student_name": current_student.name,
        "subject_name": subject.subject_name if subject else "",
        "subject_code": subject.subject_code if subject else "",
        "classroom_name": classroom.room_name if classroom else "",
        "faculty_name": faculty.name if faculty else "",
        "date": record.date.isoformat(),
        "time": record.time,
        "status": record.status,
    }


# ─── GET /attendance/session/{session_id} ────────────────────
@router.get("/session/{session_id}", operation_id="attendance_get_session_info")
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


# ─── GET /attendance/active-session ──────────────────────────
@router.get("/active-session", operation_id="attendance_get_active_session")
async def get_active_session(
    classroom_uuid: Optional[str] = None,
    classroom_name: Optional[str] = None,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Get the currently active session for a classroom by its BLE UUID or Room Name.
    Used as a fallback when the student opens the app directly without a deep link.
    """
    logger.info(
        f"[ACTIVE_SESSION_LOOKUP] Query by student_id={current_student.id}: "
        f"classroom_uuid={classroom_uuid}, classroom_name={classroom_name}"
    )

    classroom = None
    if classroom_uuid:
        # Match case-insensitively or by prefix
        classroom = db.query(Classroom).filter(
            Classroom.ble_uuid.ilike(classroom_uuid)
        ).first()

    if not classroom and classroom_name:
        # Fallback to matching by name (replacing spaces with underscores just in case)
        normalized_name = classroom_name.replace(" ", "_")
        classroom = db.query(Classroom).filter(
            (Classroom.room_name.ilike(classroom_name)) |
            (Classroom.room_name.ilike(normalized_name))
        ).first()

    if not classroom:
        logger.warning(
            f"[ACTIVE_SESSION] Classroom not found: uuid={classroom_uuid}, name={classroom_name}"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Classroom not found",
        )

    # Query active session in this classroom
    session = db.query(SessionModel).filter(
        SessionModel.classroom_id == classroom.id,
        SessionModel.is_active == True,
    ).order_by(SessionModel.start_time.desc()).first()

    if not session:
        logger.warning(
            f"[ACTIVE_SESSION] No active session: classroom={classroom.room_name} (id={classroom.id})"
        )
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"No active session found in classroom '{classroom.room_name}'",
        )

    # Fetch subject and faculty details
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    faculty = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()

    logger.info(
        f"[ACTIVE_SESSION] Found active session: session_id={session.id}, "
        f"classroom={classroom.room_name}, subject={subject.subject_name if subject else 'N/A'}"
    )

    return {
        "session_id": session.id,
        "subject_name": subject.subject_name if subject else "",
        "subject_code": subject.subject_code if subject else "",
        "classroom_name": classroom.room_name,
        "classroom_uuid": classroom.ble_uuid,
        "faculty_name": faculty.name if faculty else "",
        "is_active": session.is_active,
        "start_time": session.start_time.isoformat(),
    }


# ─── POST /attendance/mark-qr ────────────────────────────────
@router.post("/mark-qr", operation_id="attendance_mark_via_qr")
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
    from jose import jwt
    from datetime import datetime
    from app.core.config import settings


    qr_token = request.get("qr_token", "")
    if not qr_token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="qr_token is required",
        )

    # 1. Decode and verify the JWT
    try:
        payload = jwt.decode(qr_token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
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
        "time": record.time,
        "method": "qr",
    }

