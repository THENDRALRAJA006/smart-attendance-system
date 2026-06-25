# ============================================================
# SmartAttend — Auth Routes (v5)
# POST /auth/register, /auth/login, /auth/refresh
# POST /auth/face-register          (single-pose, legacy compat)
# POST /auth/face-register-auto     (v5: auto-capture batch)
# POST /auth/face-register-multi    (v4: 15-pose, legacy)
# GET  /auth/liveness-challenge     (anti-spoof)
# POST /auth/liveness-verify        (anti-spoof)
# GET  /auth/me
# ============================================================

import logging
import os
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_refresh_token
)
from app.core.dependencies import get_current_student, get_current_user_any_role
from app.models.models import Student, Faculty, Admin, FacultySubject, Subject, StudentFace, FaceProfile
from app.schemas.schemas import (
    StudentRegisterRequest, LoginRequest, TokenResponse,
    TokenRefreshResponse, RefreshTokenRequest, StudentResponse
)
from app.services.face_service import face_service
from app.services.liveness_service import liveness_service
from app.core.config import settings

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/auth", tags=["Authentication"])



# ─── Helper: Build token payload ─────────────────────────────

def _make_student_payload(student: Student) -> dict:
    return {
        "id":             student.id,
        "name":           student.name,
        "reg_no":         student.reg_no,
        "department":     student.department,
        "year":           student.year,
        "section":        student.section,
        "email":          student.email,
        "phone_number":   student.phone_number,
        "face_id":        student.face_id,
        "face_image_url": student.face_image_url,
        # created_at may be None if DB default hasn't flushed yet
        "created_at":     student.created_at.isoformat() if student.created_at else None,
    }


def _make_faculty_payload(faculty: Faculty, subjects: list = None) -> dict:
    return {
        "id":         faculty.id,
        "name":       faculty.name,
        "email":      faculty.email,
        "department": getattr(faculty, "department", None),
        "subjects":   subjects or [],
    }


# ─── POST /auth/register ─────────────────────────────────────

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register_student(
    request: StudentRegisterRequest,
    db: Session = Depends(get_db),
):
    """Register a new student account and return JWT tokens."""
    # Check email uniqueness
    if db.query(Student).filter(Student.email == request.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    # Check reg number uniqueness
    if db.query(Student).filter(Student.reg_no == request.reg_no).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Register number already exists",
        )

    # Create student
    student = Student(
        name=request.name,
        reg_no=request.reg_no,
        department=request.department,
        year=request.year,
        section=request.section,
        email=request.email,
        phone_number=request.phone_number,
        password_hash=hash_password(request.password),
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    return {
        "access_token":  create_access_token(subject=student.id, role="student"),
        "refresh_token": create_refresh_token(subject=student.id, role="student"),
        "token_type":    "bearer",
        "role":          "student",
        "user":          _make_student_payload(student),
    }


# ─── POST /auth/login ─────────────────────────────────────────

@router.post("/login", response_model=TokenResponse)
async def login(
    request: LoginRequest,
    db: Session = Depends(get_db),
):
    """Authenticate user by role and return JWT access + refresh tokens."""
    logger.info(f"Login attempt: email={request.email} role={request.role}")

    try:
        if request.role == "student":
            user = db.query(Student).filter(Student.email == request.email).first()
            logger.info(f"Student lookup result: {'found' if user else 'not found'}")
            if not user or not verify_password(request.password, user.password_hash):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid email or password",
                )
            payload = _make_student_payload(user)
            logger.info(f"Student login success: id={user.id}")
            return {
                "access_token":  create_access_token(subject=user.id, role="student"),
                "refresh_token": create_refresh_token(subject=user.id, role="student"),
                "token_type":    "bearer",
                "role":          "student",
                "user":          payload,
            }

        elif request.role == "faculty":
            user = db.query(Faculty).filter(Faculty.email == request.email).first()
            logger.info(f"Faculty lookup result: {'found' if user else 'not found'}")
            if not user or not verify_password(request.password, user.password_hash):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid email or password",
                )
            assigned_subjects = (
                db.query(Subject)
                .join(FacultySubject, FacultySubject.subject_id == Subject.id)
                .filter(FacultySubject.faculty_id == user.id)
                .all()
            )
            subjects_list = [
                {
                    "id":           s.id,
                    "subject_name": s.subject_name,
                    "subject_code": s.subject_code,
                    "department":   s.department,
                    "faculty_id":   s.faculty_id,
                }
                for s in assigned_subjects
            ]
            logger.info(f"Faculty login success: id={user.id}, subjects={len(subjects_list)}")
            return {
                "access_token":  create_access_token(subject=user.id, role="faculty"),
                "refresh_token": create_refresh_token(subject=user.id, role="faculty"),
                "token_type":    "bearer",
                "role":          "faculty",
                "user":          _make_faculty_payload(user, subjects_list),
            }

        elif request.role == "admin":
            user = db.query(Admin).filter(Admin.email == request.email).first()
            logger.info(f"Admin lookup result: {'found' if user else 'not found'}")
            if not user or not verify_password(request.password, user.password_hash):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid email or password",
                )
            logger.info(f"Admin login success: id={user.id}")
            return {
                "access_token":  create_access_token(subject=user.id, role="admin"),
                "refresh_token": create_refresh_token(subject=user.id, role="admin"),
                "token_type":    "bearer",
                "role":          "admin",
                "user":          {"id": user.id, "name": user.name, "email": user.email},
            }

        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid role",
        )

    except HTTPException:
        raise  # Let FastAPI handle 401/400/404 normally
    except Exception as exc:
        import traceback
        logger.error(
            f"Login 500 for {request.email} ({request.role}):\n{traceback.format_exc()}"
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {type(exc).__name__}: {str(exc)}",
        )


# ─── GET /auth/debug ───────────────────────────────────────
@router.get("/debug")
async def debug_db(db: Session = Depends(get_db)):
    """
    Diagnostic endpoint: verifies DB connection and returns row counts.
    Remove or secure before go-live.
    """
    try:
        admin_count   = db.query(Admin).count()
        student_count = db.query(Student).count()
        faculty_count = db.query(Faculty).count()
        # Test password hashing round-trip
        test_hash = hash_password("TestPass@123")
        hash_ok   = verify_password("TestPass@123", test_hash)
        return {
            "db_connected":   True,
            "admins":         admin_count,
            "students":       student_count,
            "faculty":        faculty_count,
            "bcrypt_ok":      hash_ok,
        }
    except Exception as exc:
        import traceback
        return {
            "db_connected": False,
            "error":        type(exc).__name__,
            "detail":       str(exc),
            "traceback":    traceback.format_exc(),
        }



@router.post("/refresh", response_model=TokenRefreshResponse)
async def refresh_token(
    request: RefreshTokenRequest,
    db: Session = Depends(get_db),
):
    """
    Exchange a valid refresh token for new access + refresh tokens.
    Implements refresh token rotation for security.
    """
    from jose import JWTError

    try:
        payload = decode_refresh_token(request.refresh_token)
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    user_id = int(payload["sub"])
    role    = payload["role"]

    # Verify user still exists
    if role == "student":
        user = db.query(Student).filter(Student.id == user_id).first()
    elif role == "faculty":
        user = db.query(Faculty).filter(Faculty.id == user_id).first()
    elif role == "admin":
        user = db.query(Admin).filter(Admin.id == user_id).first()
    else:
        user = None

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User no longer exists",
        )

    return {
        "access_token":  create_access_token(subject=user_id, role=role),
        "refresh_token": create_refresh_token(subject=user_id, role=role),
        "token_type":    "bearer",
    }


# ─── POST /auth/face-register ───────────────────────────────────

@router.post("/face-register")
async def register_face(
    file: UploadFile = File(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Upload a single image and register the student's face (ArcFace embedding).
    Stores one embedding in face_embeddings table.
    For richer multi-sample registration, use POST /auth/face-register-auto.

    Requires: authenticated student JWT.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image (JPEG or PNG)",
        )

    image_bytes = await file.read()

    # Remove old face registration if exists
    from app.models.models import FaceEmbedding
    db.query(FaceEmbedding).filter(FaceEmbedding.student_id == current_student.id).delete()

    # 1. Register face locally (use front_face as default pose name)
    reg_res = face_service.register_face_embeddings(db, current_student.id, image_bytes, "front_face")
    if not reg_res.get("success", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=reg_res.get("message", "Face registration failed. Ensure a clear face is visible.")
        )
    
    face_id = f"arcface_{current_student.id}"
    s3_url = f"{settings.APP_BASE_URL}/static/faces/{current_student.id}.jpg"
    s3_key = f"faces/{current_student.id}/front_face.jpg"

    # 3. Save to students table (quick-access shortcut)
    current_student.face_id        = face_id
    current_student.face_image_url = s3_url
    db.commit()

    # 4. Upsert into face_profiles table
    from app.models.models import FaceProfile
    profile = db.query(FaceProfile).filter(
        FaceProfile.student_id == current_student.id
    ).first()

    if profile:
        profile.face_id = face_id
        profile.s3_key  = s3_key
        profile.s3_url  = s3_url
    else:
        profile = FaceProfile(
            student_id=current_student.id,
            face_id=face_id,
            s3_key=s3_key,
            s3_url=s3_url,
        )
        db.add(profile)

    db.commit()
    db.refresh(current_student)

    logger.info(
        f"Face registered for student {current_student.id}: "
        f"face_id={face_id}, s3_url={s3_url}"
    )

    return {
        "message": "Face registered successfully",
        "face_id": face_id,
        "s3_url":  s3_url,
    }


# ─── POST /auth/face-register-auto ──────────────────────────────

@router.post("/face-register-auto", tags=["Authentication"])
async def register_face_auto(
    files: List[UploadFile] = File(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    v5: Automatic batch face registration.

    Accepts 30–150 frames captured automatically by the Flutter app during
    guided movement (front, smile, blink, left, right, up, down, head rotation).

    Processing pipeline (all server-side, no images stored permanently):
    1. Decode each frame
    2. Reject blurry frames (Laplacian sharpness < 80)
    3. Detect face — skip frames with 0 or 2+ faces
    4. De-duplicate: skip frames with cosine_sim >= 0.98 to already-accepted frames
    5. Store up to 50 unique ArcFace embeddings in face_embeddings table
    6. Save profile picture from sharpest frame only
    7. Discard all raw bytes — no permanent image storage

    Returns: success, stored count, rejection breakdown, message
    """
    if not files:
        raise HTTPException(status_code=400, detail="At least 1 frame is required.")
    if len(files) > 200:
        raise HTTPException(status_code=400, detail="Maximum 200 frames allowed per batch.")

    images_bytes: list[bytes] = []
    for f in files:
        if not f.content_type or not f.content_type.startswith("image/"):
            continue
        data = await f.read()
        if data:
            images_bytes.append(data)

    if not images_bytes:
        raise HTTPException(
            status_code=400,
            detail="All submitted frames are empty or invalid.",
        )

    result = face_service.register_face_embeddings_batch(
        db=db,
        student_id=current_student.id,
        images_bytes=images_bytes,
    )

    if not result.get("success", False):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=result.get("message", "Batch face registration failed."),
        )

    face_id = f"arcface_{current_student.id}"
    from app.core.config import settings as _settings
    profile_url = f"{_settings.APP_BASE_URL}/static/faces/{current_student.id}.jpg"
    current_student.face_id = face_id
    current_student.face_image_url = profile_url
    db.commit()

    logger.info(
        f"[ArcFace] Auto-registration complete: student={current_student.id}, "
        f"stored={result['stored']} embeddings from {result['total_input']} frames"
    )

    return {
        "success": True,
        "student_id": current_student.id,
        "stored": result["stored"],
        "total_input": result["total_input"],
        "rejected_no_face": result["rejected_no_face"],
        "rejected_blurry": result["rejected_blurry"],
        "rejected_duplicate": result["rejected_duplicate"],
        "profile_url": profile_url,
        "message": result["message"],
    }


# ─── POST /auth/face-verify (standalone check) ────────────────

@router.post("/face-verify")
async def verify_face_standalone(
    file: UploadFile = File(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Verify student's face without marking attendance.
    Used for testing/re-registration validation.
    """
    if not current_student.face_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No face registered. Please register your face first.",
        )

    image_bytes = await file.read()
    result = face_service.verify_face_embedding(db, current_student.id, image_bytes)
    return {
        "matched": result["verified"],
        "confidence": result["similarity"] * 100.0,
        "tier": result["tier"],
        "message": result["message"]
    }


# ─── GET /auth/me (multi-role) ────────────────────────────────

@router.get("/me")
async def get_current_user_profile(
    current_user=Depends(get_current_user_any_role),
    db: Session = Depends(get_db),
):
    """
    Return the currently authenticated user's profile.
    Works for student, faculty, and admin roles.
    """
    user, role = current_user

    if role == "student":
        return {"role": "student", "user": _make_student_payload(user)}

    elif role == "faculty":
        assigned_subjects = (
            db.query(Subject)
            .join(FacultySubject, FacultySubject.subject_id == Subject.id)
            .filter(FacultySubject.faculty_id == user.id)
            .all()
        )
        subjects_list = [
            {
                "id":           s.id,
                "subject_name": s.subject_name,
                "subject_code": s.subject_code,
                "department":   s.department,
            }
            for s in assigned_subjects
        ]
        return {"role": "faculty", "user": _make_faculty_payload(user, subjects_list)}

    elif role == "admin":
        return {
            "role": "admin",
            "user": {"id": user.id, "name": user.name, "email": user.email},
        }

    raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unauthorized")

# ============================================================
# v4 ENDPOINTS: 15-Pose Registration + Liveness Anti-Spoofing
# ============================================================

POSE_SEQUENCE = [
    (1,  "front_face",   "Look directly at the camera"),
    (2,  "left_15",      "Turn your head slightly LEFT (15 degrees)"),
    (3,  "left_30",      "Turn your head LEFT (30 degrees)"),
    (4,  "right_15",     "Turn your head slightly RIGHT (15 degrees)"),
    (5,  "right_30",     "Turn your head RIGHT (30 degrees)"),
    (6,  "look_up",      "Tilt your head UP"),
    (7,  "look_down",    "Tilt your head DOWN"),
    (8,  "smile",        "Smile naturally"),
    (9,  "blink",        "Blink once"),
    (10, "neutral",      "Return to neutral expression"),
    (11, "slight_left",  "Slight LEFT turn"),
    (12, "slight_right", "Slight RIGHT turn"),
    (13, "front_face_2", "Look at camera again"),
    (14, "smile_2",      "Smile again"),
    (15, "final_front",  "Final front-facing photo"),
]
POSE_MAP = {idx: (ptype, instr) for idx, ptype, instr in POSE_SEQUENCE}


@router.post("/face-register-multi", tags=["Authentication"])
async def register_face_pose(
    file: UploadFile = File(...),
    pose_index: int = Form(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Upload one pose in the 15-step guided face registration. Call once per pose (1-15).

    Flow:
    1. Quality-check frame (brightness, sharpness, single face)
    2. Extract ArcFace embedding and store in face_embeddings table
    3. Upsert row in student_faces table (legacy compatibility)
    4. On pose 15: promote face_id to students table
    """
    if not 1 <= pose_index <= 15:
        raise HTTPException(status_code=400, detail="pose_index must be 1-15")
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")

    image_bytes = await file.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Empty image file")

    pose_type, _ = POSE_MAP.get(pose_index, ("unknown", ""))

    # Quality gate — rejects blur, dark images, multiple faces
    quality = liveness_service.check_registration_frame_quality(image_bytes)
    if not quality["valid"]:
        return {
            "success": False, "pose_index": pose_index, "pose_type": pose_type,
            "message": quality["reason"], "quality": quality,
        }

    # Register face embedding locally
    reg_result = face_service.register_face_embeddings(
        db, current_student.id, image_bytes, pose_type
    )
    if not reg_result.get("success", False):
        return {
            "success": False, "pose_index": pose_index, "pose_type": pose_type,
            "message": reg_result.get("message", "Registration failed"), "quality": quality,
        }

    face_id = f"arcface_student_{current_student.id}"
    confidence = 100.0
    is_primary = True
    s3_url = f"{settings.APP_BASE_URL}/static/faces/{current_student.id}.jpg"
    s3_key = f"faces/{current_student.id}/{pose_type}.jpg"

    # Upsert student_faces (compatibility)
    existing = db.query(StudentFace).filter_by(
        student_id=current_student.id, pose_index=pose_index
    ).first()
    if existing:
        existing.face_id = face_id
        existing.image_url = s3_url
        existing.s3_key = s3_key
        existing.pose_type = pose_type
        existing.confidence = confidence
        existing.is_primary = is_primary
    else:
        db.add(StudentFace(
            student_id=current_student.id, face_id=face_id, image_url=s3_url,
            s3_key=s3_key, pose_index=pose_index, pose_type=pose_type,
            confidence=confidence, is_primary=is_primary,
        ))

    # Final pose: promote face credentials
    if pose_index == 15:
        current_student.face_id = face_id
        current_student.face_image_url = s3_url
        profile = db.query(FaceProfile).filter_by(
            student_id=current_student.id
        ).first()
        if profile:
            profile.face_id = face_id
            profile.s3_key  = s3_key
            profile.s3_url  = s3_url
            profile.confidence = confidence
        else:
            db.add(FaceProfile(
                student_id=current_student.id,
                face_id=face_id, s3_key=s3_key,
                s3_url=s3_url, confidence=confidence,
            ))

    db.commit()

    next_pose = None
    if pose_index < 15:
        ni, nt, nins = POSE_SEQUENCE[pose_index]
        next_pose = {"pose_index": ni, "pose_type": nt, "instruction": nins}

    logger.info(
        f"Pose {pose_index}/{pose_type} registered: "
        f"student={current_student.id}, face_id={face_id}"
    )

    return {
        "success": True,
        "pose_index": pose_index,
        "pose_type": pose_type,
        "s3_url": s3_url,
        "face_id": face_id,
        "confidence": confidence,
        "is_final": pose_index == 15,
        "next_pose": next_pose,
        "message": (
            f"Pose {pose_index}/15 captured!"
            if pose_index < 15
            else "All 15 poses registered! Face profile active."
        ),
        "quality": quality,
    }


# ─── GET /auth/liveness-challenge ────────────────────────────
@router.get("/liveness-challenge", tags=["Authentication"])
async def get_liveness_challenge(
    current_student: Student = Depends(get_current_student),
):
    """Issue a random liveness challenge (BLINK/SMILE/TURN_LEFT/TURN_RIGHT). Token expires in 90s."""
    return liveness_service.generate_challenge(current_student.id)


# ─── POST /auth/liveness-verify ──────────────────────────────
@router.post("/liveness-verify", tags=["Authentication"])
async def verify_liveness(
    files: List[UploadFile] = File(...),
    challenge_token: str = Form(...),
    current_student: Student = Depends(get_current_student),
):
    """
    Verify liveness using 1-3 frames captured during the challenge.

    Anti-spoofing:
    - Brightness > 40 (rejects dark / printed photos)
    - Sharpness > 40 (rejects blurry / printed images)
    - Single face only
    - BLINK: eyes closed in at least 1 frame
    - SMILE: smile confidence > 70 percent in at least 1 frame
    - TURN_LEFT/RIGHT: head yaw > 15 degrees in at least 1 frame
    """
    if not files:
        raise HTTPException(status_code=400, detail="At least 1 frame required")
    if len(files) > 3:
        raise HTTPException(status_code=400, detail="Maximum 3 frames")

    frames: list[bytes] = []
    for f in files:
        if not f.content_type or not f.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="All files must be images")
        data = await f.read()
        if data:
            frames.append(data)

    if not frames:
        raise HTTPException(status_code=400, detail="All submitted files are empty")

    result = liveness_service.verify_liveness(
        frames=frames, challenge_token=challenge_token
    )
    logger.info(
        f"Liveness verify: student={current_student.id}, "
        f"passed={result['passed']}, challenge={result['challenge_type']}"
    )
    return result


# ─── DELETE /auth/face-reset ──────────────────────────────────
@router.delete("/face-reset", summary="Reset student face registration")
async def reset_face_registration(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Completely wipe the student's face registration:
    - Deletes all local database embeddings
    - Deletes local profile picture file
    - Clears all rows in student_faces table for this student
    - Resets student.face_id and student.face_image_url to null
    """
    student_id = current_student.id

    # 1. Delete local DB embeddings
    from app.models.models import FaceEmbedding
    db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).delete()

    # 2. Delete local profile picture if exists
    photo_path = os.path.join("static", "faces", f"{student_id}.jpg")
    deleted_local_file = False
    if os.path.exists(photo_path):
        try:
            os.remove(photo_path)
            deleted_local_file = True
        except Exception as e:
            logger.warning(f"[FACE_RESET] Failed to remove local file {photo_path}: {e}")

    # 3. Clear student_faces table
    db.query(StudentFace).filter(StudentFace.student_id == student_id).delete()

    # 4. Clear FaceProfile
    db.query(FaceProfile).filter(FaceProfile.student_id == student_id).delete()

    # 5. Reset student record
    current_student.face_id = None
    current_student.face_image_url = None
    db.add(current_student)
    db.commit()

    logger.info(
        f"[FACE_RESET] student_id={student_id}: deleted_local_file={deleted_local_file}"
    )

    return {
        "success": True,
        "student_id": student_id,
        "local_file_deleted": deleted_local_file,
        "message": "Face registration reset. You can now re-register from pose 1.",
    }
