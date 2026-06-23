# ============================================================
# SmartAttend — Attendance Routes (v4)
# POST /attendance/verify      — Pre-check eligibility & range
# POST /attendance/mark        — Face match (ArcFace) + liveness verify
# POST /attendance/mark-qr     — Scan QR code fallback
# GET  /attendance/active-session — Lookup active session by BLE UUID
# ============================================================

import logging
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.core.config import settings
from app.models.models import Student, Classroom, Subject, Session as SessionModel
from app.services.attendance_service import (
    get_session_by_id,
    check_duplicate_attendance,
    validate_rssi,
    validate_student_eligibility,
    mark_attendance,
)
from app.services.face_service import face_service
from app.services.liveness_service import liveness_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/attendance", tags=["Attendance"])


class QrMarkRequest(BaseModel):
    qr_token: str


# ─── GET /attendance/active-session ──────────────────────────
@router.get("/active-session")
async def get_active_session(
    classroom_uuid: str,
    classroom_name: str | None = None,
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student),
):
    """
    Lookup current active attendance session for a classroom.
    Called when student opens the app near a BLE beacon.
    """
    logger.info(f"[ACTIVE_SESSION_LOOKUP] UUID={classroom_uuid}, Name={classroom_name}")

    # Search classroom by UUID or Room Name
    classroom = db.query(Classroom).filter(
        (Classroom.ble_uuid.ilike(f"%{classroom_uuid}%")) |
        (Classroom.room_name.ilike(f"%{classroom_name}%") if classroom_name else False)
    ).first()

    if not classroom:
        # Fallback to exact BLE uuid match
        classroom = db.query(Classroom).filter(Classroom.ble_uuid == classroom_uuid).first()

    if not classroom:
        logger.warning(f"[ACTIVE_SESSION_LOOKUP] Classroom not found for UUID={classroom_uuid}")
        return {"session_id": None}

    # Query active session
    active_session = db.query(SessionModel).filter(
        SessionModel.classroom_id == classroom.id,
        SessionModel.is_active == True
    ).first()

    if not active_session:
        logger.info(f"[ACTIVE_SESSION_LOOKUP] No active session in classroom={classroom.room_name}")
        return {"session_id": None, "is_active": False}

    subject = db.query(Subject).filter(Subject.id == active_session.subject_id).first()
    subject_name = subject.subject_name if subject else "Unknown Subject"

    return {
        "session_id": active_session.id,
        "subject_name": subject_name,
        "classroom_name": classroom.room_name,
        "classroom_uuid": classroom.ble_uuid,
        "is_active": True
    }


# ─── POST /attendance/verify ──────────────────────────────────
@router.post("/verify")
async def verify_attendance(
    session_id: int = Form(...),
    rssi: int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Verify student eligibility (duplicate attendance check, department check)
    and check BLE range before capturing face selfie.
    """
    logger.info(f"[ATTENDANCE_VERIFY] Student={current_student.id}, Session={session_id}, RSSI={rssi}")

    session = get_session_by_id(db, session_id)
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()

    classroom_name = classroom.room_name if classroom else "Unknown Classroom"
    classroom_uuid = classroom.ble_uuid if classroom else ""
    subject_name = subject.subject_name if subject else "Unknown Subject"

    # 0. Validate student registration
    from app.models.models import FaceEmbedding
    registered_faces_count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == current_student.id).count()

    if registered_faces_count < 15:
        logger.warning(
            f"[REGISTRATION_VALIDATION] Registration incomplete for student={current_student.id}. "
            f"Faces count={registered_faces_count} (needs 15)"
        )
        return {
            "eligible": False,
            "step": "no_registration",
            "message": f"Face registration incomplete ({registered_faces_count}/15 poses captured). Please register your face first.",
            "session_id": session_id,
            "classroom_name": classroom_name,
            "classroom_uuid": classroom_uuid,
            "subject_name": subject_name
        }

    # 1. Check duplicate attendance
    try:
        check_duplicate_attendance(db, current_student.id, session_id)
    except HTTPException as e:
        return {
            "eligible": False,
            "step": "duplicate",
            "message": e.detail,
            "session_id": session_id,
            "classroom_name": classroom_name,
            "classroom_uuid": classroom_uuid,
            "subject_name": subject_name
        }

    # 2. Check department eligibility
    try:
        validate_student_eligibility(db, current_student, session)
    except HTTPException as e:
        return {
            "eligible": False,
            "step": "ineligible",
            "message": e.detail,
            "session_id": session_id,
            "classroom_name": classroom_name,
            "classroom_uuid": classroom_uuid,
            "subject_name": subject_name
        }

    # 3. Check BLE range (skip if rssi is 0 bypass)
    try:
        validate_rssi(rssi, classroom_id=session.classroom_id, db=db)
    except HTTPException as e:
        return {
            "eligible": False,
            "step": "out_of_range",
            "message": e.detail,
            "session_id": session_id,
            "classroom_name": classroom_name,
            "classroom_uuid": classroom_uuid,
            "subject_name": subject_name
        }

    return {
        "eligible": True,
        "step": "ready",
        "session_id": session_id,
        "classroom_name": classroom_name,
        "classroom_uuid": classroom_uuid,
        "subject_name": subject_name
    }


# ─── POST /attendance/mark ────────────────────────────────────
@router.post("/mark")
async def mark_attendance_endpoint(
    file: UploadFile = File(...),
    session_id: int = Form(...),
    rssi: int = Form(...),
    liveness_token: str | None = Form(None),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Validate student proximity (BLE), verify face match (AWS Rekognition)
    against the master face profile, and check the liveness challenge.
    Marks attendance in DB upon success.
    """
    logger.info(
        f"[ATTENDANCE_MARK] ── START ──────────────────────────────────────"
    )
    logger.info(
        f"[ATTENDANCE_MARK] Student={current_student.id} ({current_student.name}), "
        f"Session={session_id}, RSSI={rssi} dBm, "
        f"Liveness token present={liveness_token is not None}"
    )

    # 1. Validate session
    session = get_session_by_id(db, session_id)
    logger.info(f"[SESSION] Validated: session_id={session_id}, is_active={session.is_active}")
    logger.info(f"[BACKEND_LOG] Session loaded: session_id={session.id}, subject_id={session.subject_id}, classroom_id={session.classroom_id}")

    # 2. Check duplicate attendance
    check_duplicate_attendance(db, current_student.id, session_id)
    logger.info(f"[DUPLICATE] No duplicate found for student={current_student.id}")

    # 3. Check department eligibility
    validate_student_eligibility(db, current_student, session)
    logger.info(f"[ELIGIBILITY] Student={current_student.id} is eligible")

    # 4. Check BLE range
    validate_rssi(rssi, classroom_id=session.classroom_id, db=db)
    logger.info(f"[BLE] RSSI={rssi} dBm validated for classroom_id={session.classroom_id}")

    # 5. Liveness verification — NON-BLOCKING
    #    If liveness token is provided and valid, mark liveness_verified=True.
    #    If token is missing, invalid, or expired — proceed with liveness_verified=False.
    #    Liveness NEVER blocks attendance; it only enriches the record.
    liveness_verified = False
    if liveness_token:
        try:
            payload = liveness_service.decode_challenge_token(liveness_token)
            if int(payload.get("sub", 0)) == current_student.id:
                liveness_verified = True
                logger.info(
                    f"[LIVENESS] Verified ✅ student={current_student.id}"
                )
            else:
                logger.warning(
                    f"[LIVENESS] Token student mismatch — "
                    f"token_sub={payload.get('sub')}, current={current_student.id}. "
                    f"Proceeding without liveness."
                )
        except HTTPException:
            logger.warning(
                f"[LIVENESS] Token invalid/expired for student={current_student.id}. "
                f"Proceeding without liveness."
            )
        except Exception as e:
            logger.warning(
                f"[LIVENESS] Unexpected error: {e}. Proceeding without liveness."
            )
    else:
        logger.info(
            f"[LIVENESS] No token provided for student={current_student.id} — skipped"
        )
    logger.info(f"[BACKEND_LOG] Liveness verified: liveness_verified={liveness_verified} for student={current_student.id}")

    # 6. Face Verification (Local ArcFace)
    from app.models.models import FaceEmbedding
    registered_faces_count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == current_student.id).count()

    if registered_faces_count < 15:
        logger.warning(
            f"[REGISTRATION_VALIDATION] Registration incomplete/missing for student={current_student.id}. "
            f"Faces count={registered_faces_count} (needs 15)"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Face profile registration incomplete ({registered_faces_count}/15 poses captured). Please register your face first.",
        )

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded face image is empty or invalid.",
        )

    logger.info("Image received")
    logger.info(f"Image size: {len(image_bytes)} bytes")

    logger.info(
        f"[ArcFace] Verifying face embedding locally: student_id={current_student.id}"
    )

    result = face_service.verify_face_embedding(
        db=db,
        student_id=current_student.id,
        live_image_bytes=image_bytes,
    )

    matched = result.get("verified", False)
    confidence = result.get("similarity", 0.0) * 100.0
    tier = result.get("tier", "rejected")

    logger.info(
        f"[ArcFace] Verification response: matched={matched}, "
        f"confidence={confidence:.2f}%, tier={tier}"
    )

    if not matched or tier == "rejected":
        logger.warning(
            f"[ATTENDANCE_MARK] Face verification REJECTED: "
            f"student={current_student.id}, confidence={confidence:.2f}%"
        )
        return {
            "match": False,
            "tier": "rejected",
            "confidence": confidence,
            "message": result.get(
                "message",
                "Face verification failed. Face not recognized.",
            ),
            "attendance_id": None,
        }

    msg = (
        "Attendance marked successfully! ✅"
        if tier == "present"
        else "Face matched but confidence is low. Attendance logged for review. ⚠️"
    )

    # 7. Write attendance record to DB
    logger.info(
        f"[ATTENDANCE_MARK] Writing record: student={current_student.id}, "
        f"session={session_id}, tier={tier}, "
        f"liveness={liveness_verified}, rssi={rssi}"
    )
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
    logger.info(f"[BACKEND_LOG] Attendance marked: record_id={record.id}, student_id={current_student.id}, session_id={session_id}, tier={tier}")

    logger.info(
        f"[ATTENDANCE_MARK] ✅ SUCCESS: attendance_id={record.id}, "
        f"student={current_student.id}, session={session_id}, "
        f"confidence={confidence:.2f}%, tier={tier}"
    )

    return {
        "match": True,
        "verified": True,
        "tier": tier,
        "confidence": confidence,
        "similarity": result.get("similarity", 0.0),
        "message": msg,
        "attendance_id": record.id,
        "time": record.time,
        "date": record.date.isoformat(),
    }


# ─── POST /attendance/mark-qr ────────────────────────────────
@router.post("/mark-qr")
async def mark_attendance_qr(
    request: QrMarkRequest,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Fallback attendance marking using a scanned QR code.
    Verifies the signed faculty QR token, bypasses BLE and face scans.
    """
    logger.info(f"[ATTENDANCE_QR] Student={current_student.id} scanning token...")

    # Decode and verify token
    try:
        payload = jwt.decode(
            request.qr_token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM]
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired QR code. Please scan a new one."
        )

    if payload.get("type") != "qr_attendance":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid QR token type."
        )

    session_id = payload.get("session_id")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session ID missing from QR token."
        )

    # 1. Fetch Session
    session = get_session_by_id(db, session_id)

    # 2. Check Duplicate Attendance
    check_duplicate_attendance(db, current_student.id, session_id)

    # 3. Check Department Eligibility
    validate_student_eligibility(db, current_student, session)

    # 4. Write attendance to DB with QR method
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=0,  # 0 indicates BLE bypass
        face_confidence=100.0,
        liveness_verified=True,
        confidence_tier="present",
        attendance_method="qr",
    )

    return {
        "marked": True,
        "message": "Attendance marked successfully via QR code ✅",
        "attendance_id": record.id,
        "time": record.time,
        "date": record.date.isoformat()
    }
