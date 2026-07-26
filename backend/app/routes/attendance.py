# ============================================================
# SmartAttend — Attendance Routes (v5)
# GET  /attendance/check-active-session  — Dashboard session status (no BLE needed)
# POST /attendance/validate-qr           — Validate QR token, return session info
# POST /attendance/verify                — Pre-check eligibility & range
# POST /attendance/mark                  — Face match (ArcFace) + liveness verify
# POST /attendance/mark-qr               — Scan QR code fallback (legacy)
# GET  /attendance/active-session        — Lookup active session by BLE UUID
# ============================================================

import logging
import time as _time
from datetime import datetime
from typing import Optional
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from pydantic import BaseModel
from sqlalchemy.orm import Session
from jose import jwt, JWTError

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.core.config import settings
from app.models.models import Student, Classroom, Subject, Session as SessionModel, Attendance, Faculty, FaceEmbedding
from app.services.attendance_service import (
    get_session_by_id,
    check_duplicate_attendance,
    check_device_in_session,
    log_device_attendance,
    validate_rssi,
    validate_student_eligibility,
    mark_attendance,
)
from app.services.face_service import face_service
from app.services.liveness_service import liveness_service

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/attendance", tags=["Attendance"])


class QrMarkRequest(BaseModel):
    qr_token: Optional[str] = None     # Legacy: full JWT token
    session_id: Optional[int] = None   # New: after validate-qr, send session_id directly
    rssi: Optional[int] = 0            # BLE RSSI for audit


class QrValidateRequest(BaseModel):
    qr_token: str


# ─── GET /attendance/check-active-session ─────────────────────
@router.get("/check-active-session")
async def check_active_session_for_student(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student),
):
    """
    Dashboard endpoint — checks if there is any active attendance session
    for the student's department, year, and section.
    No BLE UUID required. Used to show/hide 'Start Attendance' button.
    """
    logger.info(
        f"========== SESSION CHECK ==========\n"
        f"[SESSION_CHECK] Student ID: {current_student.id}\n"
        f"[SESSION_CHECK] Name: {current_student.name}\n"
        f"[SESSION_CHECK] Department: '{current_student.department}'\n"
        f"[SESSION_CHECK] Year: {current_student.year}\n"
        f"[SESSION_CHECK] Section: '{current_student.section}'\n"
        f"==================================="
    )

    # Find ALL active sessions and log why each matches/fails
    all_active = (
        db.query(SessionModel)
        .filter(SessionModel.is_active == True)
        .all()
    )

    logger.info(f"[SESSION_CHECK] Total active sessions in DB: {len(all_active)}")

    for s in all_active:
        subj = db.query(Subject).filter(Subject.id == s.subject_id).first()
        cls = db.query(Classroom).filter(Classroom.id == s.classroom_id).first()
        subj_dept = subj.department if subj else 'N/A'
        student_dept = current_student.department or ''
        dept_match = (subj_dept.strip().casefold() == student_dept.strip().casefold()) if subj_dept and student_dept else False
        logger.info(
            f"  Session {s.id}: subject='{subj.subject_name if subj else 'N/A'}', "
            f"dept='{subj_dept}', classroom='{cls.room_name if cls else 'N/A'}', "
            f"dept_match={dept_match} (student='{student_dept}' vs subject='{subj_dept}')"
        )

    # Find an active session whose subject matches the student's department
    # Use case-insensitive comparison for department matching
    active_session = None
    for s in all_active:
        subj = db.query(Subject).filter(Subject.id == s.subject_id).first()
        if subj and subj.department:
            student_dept = (current_student.department or '').strip().casefold()
            subject_dept = subj.department.strip().casefold()
            if student_dept == subject_dept:
                active_session = s
                logger.info(f"[SESSION_CHECK] ✅ Matched session {s.id} (dept '{subj.department}')")
                break

    if not active_session:
        logger.info(f"[SESSION_CHECK] ❌ No matching active session for dept='{current_student.department}'")
        return {"is_active": False, "session_id": None}

    # Check if student already marked attendance for this session
    already_marked = (
        db.query(Attendance)
        .filter(
            Attendance.student_id == current_student.id,
            Attendance.session_id == active_session.id,
        )
        .first()
        is not None
    )

    subject = db.query(Subject).filter(Subject.id == active_session.subject_id).first()
    classroom = db.query(Classroom).filter(Classroom.id == active_session.classroom_id).first()

    logger.info(
        f"[SESSION_CHECK] Returning: session_id={active_session.id}, "
        f"subject='{subject.subject_name if subject else 'N/A'}', "
        f"classroom='{classroom.room_name if classroom else 'N/A'}', "
        f"already_marked={already_marked}"
    )

    # Check face registration (actual ArcFace embeddings)
    face_registered = (
        db.query(FaceEmbedding)
        .filter(FaceEmbedding.student_id == current_student.id)
        .count()
    ) > 0

    return {
        "is_active": True,
        "session_id": active_session.id,
        "subject_name": subject.subject_name if subject else "Unknown Subject",
        "classroom_name": classroom.room_name if classroom else "Unknown Classroom",
        "classroom_uuid": classroom.ble_uuid if classroom else "",
        "already_marked": already_marked,
        "face_registered": face_registered,
    }


# ─── GET /attendance/session-status ──────────────────────────
@router.get("/session-status")
async def get_session_status(
    db: Session = Depends(get_db),
    current_student: Student = Depends(get_current_student),
):
    """
    Lightweight polling endpoint — returns only is_active + already_marked.
    Used by the dashboard timer to detect session start/end without
    fetching full session details. Lower cost than /check-active-session.
    """
    active_session = (
        db.query(SessionModel)
        .join(Subject, SessionModel.subject_id == Subject.id)
        .filter(
            SessionModel.is_active == True,
            Subject.department == current_student.department,
        )
        .first()
    )

    if not active_session:
        return {"is_active": False, "already_marked": False}

    already_marked = (
        db.query(Attendance)
        .filter(
            Attendance.student_id == current_student.id,
            Attendance.session_id == active_session.id,
        )
        .first()
        is not None
    )

    return {
        "is_active": True,
        "session_id": active_session.id,
        "already_marked": already_marked,
    }


# ─── POST /attendance/validate-qr ─────────────────────────────
@router.post("/validate-qr")
async def validate_qr_token(
    request: QrValidateRequest,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Validates a faculty-generated QR token and returns session info.
    Does NOT mark attendance — that happens after face verification.
    Used by the QR verification screen before navigating to face capture.
    """
    logger.info(f"[VALIDATE_QR] Student={current_student.id} validating QR token")

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
            detail="Invalid or expired QR code. Please scan a fresh one from your faculty."
        )

    if payload.get("type") != "qr_attendance":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid QR token type. Only SmartAttend QR codes are accepted."
        )

    session_id = payload.get("session_id")
    if not session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Session ID missing from QR token."
        )

    # Validate session exists and is active
    session = get_session_by_id(db, session_id)

    # Check for duplicate attendance
    try:
        check_duplicate_attendance(db, current_student.id, session_id)
    except HTTPException:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You have already marked attendance for this session."
        )

    # Check student eligibility
    try:
        validate_student_eligibility(db, current_student, session)
    except HTTPException as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=e.detail
        )

    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()

    logger.info(
        f"[VALIDATE_QR] Valid QR for session={session_id}, "
        f"subject={subject.subject_name if subject else 'Unknown'}"
    )

    return {
        "valid": True,
        "session_id": session_id,
        "subject_name": subject.subject_name if subject else "Unknown Subject",
        "classroom_name": classroom.room_name if classroom else "Unknown Classroom",
        "classroom_uuid": classroom.ble_uuid if classroom else "",
        "message": "QR code verified. Please proceed with face verification."
    }



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
    logger.info(
        f"========== BLE SESSION LOOKUP ==========\n"
        f"[BLE_LOOKUP] classroom_uuid='{classroom_uuid}'\n"
        f"[BLE_LOOKUP] classroom_name='{classroom_name}'\n"
        f"[BLE_LOOKUP] student_id={current_student.id}\n"
        f"========================================"
    )

    # Log all classrooms in DB for debugging
    all_classrooms = db.query(Classroom).all()
    logger.info(f"[BLE_LOOKUP] All classrooms in DB ({len(all_classrooms)}):")
    for c in all_classrooms:
        logger.info(f"  id={c.id}, room_name='{c.room_name}', ble_uuid='{c.ble_uuid}'")

    # Search classroom by UUID or Room Name
    classroom = db.query(Classroom).filter(
        (Classroom.ble_uuid.ilike(f"%{classroom_uuid}%")) |
        (Classroom.room_name.ilike(f"%{classroom_name}%") if classroom_name else False)
    ).first()

    if not classroom:
        # Fallback to exact BLE uuid match
        classroom = db.query(Classroom).filter(Classroom.ble_uuid == classroom_uuid).first()

    if not classroom:
        logger.warning(
            f"[BLE_LOOKUP] ❌ Classroom not found for UUID='{classroom_uuid}', Name='{classroom_name}'\n"
            f"  None of the {len(all_classrooms)} classrooms matched."
        )
        return {"session_id": None}

    logger.info(f"[BLE_LOOKUP] ✅ Matched classroom: id={classroom.id}, name='{classroom.room_name}'")

    # Query active session
    active_session = db.query(SessionModel).filter(
        SessionModel.classroom_id == classroom.id,
        SessionModel.is_active == True
    ).first()

    if not active_session:
        logger.info(f"[BLE_LOOKUP] ❌ No active session in classroom='{classroom.room_name}' (id={classroom.id})")
        return {"session_id": None, "is_active": False}

    subject = db.query(Subject).filter(Subject.id == active_session.subject_id).first()
    subject_name = subject.subject_name if subject else "Unknown Subject"

    logger.info(
        f"[BLE_LOOKUP] ✅ Active session found: id={active_session.id}, "
        f"subject='{subject_name}', classroom='{classroom.room_name}'"
    )

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

    if registered_faces_count < 1:
        logger.warning(
            f"[REGISTRATION_VALIDATION] No face registered for student={current_student.id}."
        )
        return {
            "eligible": False,
            "step": "no_registration",
            "message": "Face not registered. Please complete face registration first.",
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
    attendance_method_hint: str | None = Form(None),
    device_id: str | None = Form(None),   # Android ANDROID_ID — session-scoped dedup
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Validate student proximity (BLE), verify face match (ArcFace cosine similarity)
    against stored embeddings, and check the liveness challenge.
    Marks attendance in DB upon success.
    """
    logger.info(
        f"\n"
        f"{'='*60}\n"
        f"  ATTENDANCE MARK — START\n"
        f"{'='*60}\n"
        f"  Student ID:    {current_student.id}\n"
        f"  Student Name:  {current_student.name}\n"
        f"  Department:    {current_student.department}\n"
        f"  Year:          {current_student.year}\n"
        f"  Section:       {current_student.section}\n"
        f"  Session ID:    {session_id}\n"
        f"  RSSI:          {rssi} dBm\n"
        f"  Method Hint:   {attendance_method_hint}\n"
        f"  Liveness Token: {'present' if liveness_token else 'absent'}\n"
        f"{'='*60}"
    )

    # 1. Validate session
    session = get_session_by_id(db, session_id)
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    logger.info(
        f"[SESSION] ✅ Validated:\n"
        f"  session_id={session.id}\n"
        f"  is_active={session.is_active}\n"
        f"  subject='{subject.subject_name if subject else 'N/A'}' (dept='{subject.department if subject else 'N/A'}')\n"
        f"  classroom='{classroom.room_name if classroom else 'N/A'}'\n"
        f"  faculty_id={session.faculty_id}\n"
        f"  start_time={session.start_time}"
    )

    # 2. Check duplicate attendance
    check_duplicate_attendance(db, current_student.id, session_id)
    logger.info(f"[DUPLICATE] ✅ No duplicate found for student={current_student.id}")

    # 3. Check department eligibility
    validate_student_eligibility(db, current_student, session)
    logger.info(f"[ELIGIBILITY] ✅ Student={current_student.id} is eligible")

    # 4. Check BLE range
    validate_rssi(rssi, classroom_id=session.classroom_id, db=db)
    logger.info(f"[BLE] ✅ RSSI={rssi} dBm validated for classroom_id={session.classroom_id}")

    # 4b. Session-scoped device deduplication ─────────────────────────────────
    # Rejects if a DIFFERENT student already used this Android device in this
    # same session. The same device can be used again in any other session.
    _device_id = (device_id or "").strip()
    if _device_id:
        check_device_in_session(db, session_id, _device_id, current_student.id)
        logger.info(
            f"[DEVICE_CHECK] ✅ Device '{_device_id}' cleared for "
            f"student={current_student.id}, session={session_id}"
        )
    else:
        logger.warning(
            f"[DEVICE_CHECK] ⚠️ No device_id provided by student={current_student.id}. "
            "Session-scoped dedup skipped."
        )

    # 5. Liveness verification — NON-BLOCKING
    liveness_verified = False
    if liveness_token:
        try:
            payload = liveness_service.decode_challenge_token(liveness_token)
            if int(payload.get("sub", 0)) == current_student.id:
                liveness_verified = True
                logger.info(f"[LIVENESS] ✅ Verified for student={current_student.id}")
            else:
                logger.warning(
                    f"[LIVENESS] ⚠️ Token student mismatch — "
                    f"token_sub={payload.get('sub')}, current={current_student.id}"
                )
        except HTTPException:
            logger.warning(f"[LIVENESS] ⚠️ Token invalid/expired for student={current_student.id}")
        except Exception as e:
            logger.warning(f"[LIVENESS] ⚠️ Error: {e}")
    else:
        logger.info(f"[LIVENESS] Skipped — no token provided")

    # 6. Face Verification (Local ArcFace)
    from app.models.models import FaceEmbedding
    registered_faces = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == current_student.id).all()
    registered_faces_count = len(registered_faces)

    logger.info(
        f"\n"
        f"========== FACE VERIFICATION ==========\n"
        f"  Student ID:         {current_student.id}\n"
        f"  Session ID:         {session_id}\n"
        f"  Embeddings Loaded:  {registered_faces_count}\n"
        f"  Liveness Verified:  {liveness_verified}\n"
        f"======================================="
    )

    if registered_faces_count < 1:
        logger.warning(
            f"[FACE] ❌ No face registered for student={current_student.id}"
        )
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Face not registered. Please complete face registration first.",
        )

    # Log embedding details
    for i, emb_record in enumerate(registered_faces):
        emb_len = len(emb_record.embedding_json) if emb_record.embedding_json else 0
        logger.info(
            f"  Embedding [{i}]: pose='{emb_record.pose_name}', "
            f"json_len={emb_len}, created={emb_record.created_at}"
        )

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded face image is empty or invalid.",
        )

    logger.info(f"[FACE] Image received: {len(image_bytes)} bytes")

    result = face_service.verify_face_embedding(
        db=db,
        student_id=current_student.id,
        live_image_bytes=image_bytes,
    )

    matched = result.get("verified", False)
    confidence = result.get("similarity", 0.0) * 100.0
    tier = result.get("tier", "rejected")

    logger.info(
        f"\n"
        f"========== VERIFICATION RESULT ==========\n"
        f"  Matched:           {matched}\n"
        f"  Similarity:        {result.get('similarity', 0.0):.4f}\n"
        f"  Confidence:        {confidence:.2f}%\n"
        f"  Tier:              {tier}\n"
        f"  Message:           {result.get('message', '')}\n"
        f"  Compared:          {result.get('compared_count', 'N/A')}/{result.get('total_stored', 'N/A')} embeddings\n"
        f"  Best Frame:        {result.get('best_pose_name', 'N/A')} (id={result.get('best_record_id', 'N/A')})\n"
        f"  Average Score:     {result.get('avg_score', 'N/A')}\n"
        f"  Verification Time: {result.get('verification_time_s', 'N/A')}s\n"
        f"========================================="
    )

    # Log per-embedding similarity scores for debugging
    per_scores = result.get("similarity_scores", [])
    if per_scores:
        top_scores = sorted(per_scores, reverse=True)[:10]
        logger.info(
            f"[FACE] Per-embedding scores (top 10 of {len(per_scores)}): "
            f"{[f'{s:.4f}' for s in top_scores]}"
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
    # Determine attendance method based on hint and RSSI
    if attendance_method_hint == "qr_face" and rssi == 0:
        resolved_method = "qr_face"
    else:
        resolved_method = "ble_face"

    logger.info(
        f"[ATTENDANCE_MARK] method_hint={attendance_method_hint}, "
        f"rssi={rssi}, resolved_method={resolved_method}"
    )

    t_mark_start = _time.perf_counter()
    record = mark_attendance(
        db=db,
        student_id=current_student.id,
        session=session,
        rssi=rssi,
        face_confidence=confidence,
        liveness_verified=liveness_verified,
        confidence_tier=tier,
        attendance_method=resolved_method,
    )
    t_mark_elapsed = _time.perf_counter() - t_mark_start

    # Write device log entry (non-blocking — failure here must not roll back attendance)
    if _device_id:
        try:
            log_device_attendance(db, session_id, current_student.id, _device_id)
        except Exception as log_exc:
            logger.warning(
                f"[DEVICE_LOG] Non-fatal log failure: student={current_student.id} "
                f"session={session_id} device={_device_id} — {log_exc}"
            )

    logger.info(
        f"[BACKEND_LOG] Attendance marked: record_id={record.id}, "
        f"student_id={current_student.id}, session_id={session_id}, "
        f"tier={tier}, db_write={t_mark_elapsed:.3f}s"
    )

    logger.info(
        f"[ATTENDANCE_MARK] ✅ SUCCESS: attendance_id={record.id}, "
        f"student={current_student.id}, session={session_id}, "
        f"confidence={confidence:.2f}%, tier={tier}"
    )

    # 8. Fetch faculty name for receipt
    faculty_name = ""
    if session.faculty_id:
        faculty = db.query(Faculty).filter(Faculty.id == session.faculty_id).first()
        if faculty:
            faculty_name = faculty.name

    subject_name   = subject.subject_name if subject else ""
    classroom_name = classroom.room_name if classroom else ""

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
        "details": {
            "studentName":   current_student.name,
            "registerNo":    current_student.reg_no,
            "department":    current_student.department,
            "subjectName":   subject_name,
            "classroomName": classroom_name,
            "facultyName":   faculty_name,
            "attendanceId":  record.id,
            "markedAt":      f"{record.date.isoformat()} {record.time}",
            "method":        resolved_method,
            "livenessVerified": liveness_verified,
            "confidenceTier":   tier,
            "rssi":          rssi,
        },
    }


# ─── POST /attendance/mark-qr ────────────────────────────────
@router.post("/mark-qr")
async def mark_attendance_qr(
    request: QrMarkRequest,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Mark attendance via QR code. Two modes:
    - Legacy: qr_token (JWT) provided — decode and verify
    - New: session_id provided (after /validate-qr already verified token)
    """
    logger.info(f"[ATTENDANCE_QR] Student={current_student.id} marking via QR...")

    session_id = request.session_id

    if session_id is None:
        # Legacy mode: decode qr_token
        if not request.qr_token:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Either qr_token or session_id is required."
            )
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
        rssi=request.rssi or 0,  # BLE RSSI or 0 for QR-only
        face_confidence=100.0,
        liveness_verified=True,
        confidence_tier="present",
        attendance_method="qr",
    )

    # Fetch enriched receipt data for Flutter result screen
    subject = db.query(Subject).filter(Subject.id == session.subject_id).first()
    classroom = db.query(Classroom).filter(Classroom.id == session.classroom_id).first()
    faculty_obj = db.query(Faculty).filter(Faculty.id == session.faculty_id).first() if hasattr(session, 'faculty_id') and session.faculty_id else None

    return {
        "marked": True,
        "message": "Attendance marked successfully via QR code ✅",
        "attendance_id": record.id,
        "time": str(record.time),
        "date": record.date.isoformat(),
        # Enriched for Flutter result screen
        "studentName": current_student.name,
        "registerNo": current_student.reg_no,
        "department": current_student.department,
        "subjectName": subject.subject_name if subject else "",
        "classroomName": classroom.room_name if classroom else "",
        "facultyName": faculty_obj.name if faculty_obj else "",
        "markedAt": f"{record.date.isoformat()} {record.time}",
    }
