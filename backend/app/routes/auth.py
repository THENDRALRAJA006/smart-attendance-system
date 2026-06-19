# ============================================================
# SmartAttend — Auth Routes (v3)
# POST /auth/register, /auth/login, /auth/refresh
# POST /auth/face-register, /auth/face-verify
# GET  /auth/me
# ============================================================

import logging
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_refresh_token
)
from app.core.dependencies import get_current_student, get_current_user_any_role
from app.models.models import Student, Faculty, Admin, FacultySubject, Subject
from app.schemas.schemas import (
    StudentRegisterRequest, LoginRequest, TokenResponse,
    TokenRefreshResponse, RefreshTokenRequest, StudentResponse
)
from app.services.rekognition_service import rekognition_service
from app.services.s3_service import s3_service

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
        "created_at":     student.created_at.isoformat(),
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
    if request.role == "student":
        user = db.query(Student).filter(Student.email == request.email).first()
        if not user or not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        return {
            "access_token":  create_access_token(subject=user.id, role="student"),
            "refresh_token": create_refresh_token(subject=user.id, role="student"),
            "token_type":    "bearer",
            "role":          "student",
            "user":          _make_student_payload(user),
        }

    elif request.role == "faculty":
        user = db.query(Faculty).filter(Faculty.email == request.email).first()
        if not user or not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
        # Fetch subjects assigned to this faculty via junction table
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
        return {
            "access_token":  create_access_token(subject=user.id, role="faculty"),
            "refresh_token": create_refresh_token(subject=user.id, role="faculty"),
            "token_type":    "bearer",
            "role":          "faculty",
            "user":          _make_faculty_payload(user, subjects_list),
        }

    elif request.role == "admin":
        user = db.query(Admin).filter(Admin.email == request.email).first()
        if not user or not verify_password(request.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )
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


# ─── POST /auth/refresh ───────────────────────────────────────

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


# ─── POST /auth/face-register ─────────────────────────────────

@router.post("/face-register")
async def register_face(
    file: UploadFile = File(...),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Upload and register student's face.
    1. Uploads image to AWS S3
    2. Registers face in AWS Rekognition collection
    3. Stores face_id and S3 URL in database (students + face_profiles)

    Requires: authenticated student JWT.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be an image (JPEG or PNG)",
        )

    image_bytes = await file.read()

    # Remove old face registration if exists
    if current_student.face_id:
        rekognition_service.delete_face(current_student.face_id)
        s3_service.delete_face_image(current_student.id)

    # 1. Upload to S3
    s3_url = s3_service.upload_face_image(image_bytes, current_student.id)
    s3_key = f"faces/student_{current_student.id}.jpg"

    # 2. Register in AWS Rekognition
    face_id = rekognition_service.register_face(image_bytes, current_student.id)

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


# ─── POST /auth/face-verify (standalone check) ────────────────

@router.post("/face-verify")
async def verify_face_standalone(
    file: UploadFile = File(...),
    current_student: Student = Depends(get_current_student),
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
    result = rekognition_service.verify_face(image_bytes, current_student.face_id)
    return result


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
