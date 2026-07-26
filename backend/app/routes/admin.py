# ============================================================
# SmartAttend — Admin Routes (v4 — Super Admin Dashboard)
#
# Full CRUD + audit logging for every resource:
#   Students, Faculty, Classrooms, Subjects, BLE Beacons,
#   Attendance, Sessions, Face Data, Device Security,
#   System Settings, Audit Logs
# ============================================================

import json
import logging
import secrets
import string
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import extract, func, distinct
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.core.security import hash_password
from app.core.config import settings
from app.models.models import (
    Admin, Student, Faculty, Classroom, Subject, Attendance,
    Session as SessionModel, BleBeacon, FaceEmbedding, FaceProfile,
    AttendanceDeviceLog, AuditLog, SystemSettings,
)
from app.models.device_model import DeviceBinding
from app.schemas.schemas import (
    ClassroomCreateRequest, ClassroomResponse,
    SubjectCreateRequest, SubjectResponse,
    FacultyRegisterRequest,
    BleBeaconCreateRequest, BleBeaconResponse,
)
from app.services.audit_service import log_action_from_admin

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin"])


# ══════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════

def _generate_temp_password(length: int = 10) -> str:
    """Generate a secure temporary password: 2 upper, 2 digits, rest lower."""
    alphabet = string.ascii_letters + string.digits
    while True:
        pwd = ''.join(secrets.choice(alphabet) for _ in range(length))
        if (
            any(c.isupper() for c in pwd)
            and any(c.isdigit() for c in pwd)
            and any(c.islower() for c in pwd)
        ):
            return pwd


def _student_dict(s: Student) -> dict:
    face_count = len(s.face_embeddings) if s.face_embeddings else 0
    return {
        "id":           s.id,
        "name":         s.name,
        "reg_no":       s.reg_no,
        "department":   s.department,
        "year":         s.year,
        "section":      s.section,
        "email":        s.email,
        "phone_number": s.phone_number,
        "is_active":    s.is_active,
        "face_id":      s.face_id,
        "face_registered": face_count > 0,
        "face_count":   face_count,
        "created_at":   s.created_at.isoformat() if s.created_at else None,
    }


def _faculty_dict(f: Faculty) -> dict:
    return {
        "id":           f.id,
        "name":         f.name,
        "email":        f.email,
        "department":   f.department,
        "phone_number": f.phone_number,
        "is_active":    f.is_active,
        "created_at":   f.created_at.isoformat() if f.created_at else None,
    }


# ══════════════════════════════════════════════════════════════
# DASHBOARD
# ══════════════════════════════════════════════════════════════

@router.get("/dashboard")
async def admin_dashboard(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Enhanced system-wide analytics — 15 metrics + recent activity."""
    today = date.today()

    total_students    = db.query(Student).count()
    total_faculty     = db.query(Faculty).count()
    total_departments = db.query(func.count(distinct(Student.department))).scalar() or 0
    total_classrooms  = db.query(Classroom).count()
    total_sessions    = db.query(SessionModel).count()
    active_sessions   = db.query(SessionModel).filter(SessionModel.is_active.is_(True)).count()

    # Today's attendance
    today_records  = db.query(Attendance).filter(Attendance.date == today)
    today_present  = today_records.filter(Attendance.status == "present").count()
    today_absent   = today_records.filter(Attendance.status == "absent").count()
    today_review   = today_records.filter(Attendance.status == "manual_review").count()
    today_total    = today_records.count()

    # Face + device counts
    face_count    = db.query(FaceEmbedding).count()
    device_count  = db.query(distinct(AttendanceDeviceLog.device_id)).count()
    ble_active    = db.query(BleBeacon).filter(BleBeacon.is_active.is_(True)).count()

    # System-wide attendance rate
    total_records   = db.query(Attendance).count()
    present_records = db.query(Attendance).filter(Attendance.status == "present").count()
    system_rate     = round((present_records / total_records * 100) if total_records > 0 else 0.0, 2)

    # Recent audit logs (last 8)
    recent_audit = (
        db.query(AuditLog)
        .order_by(AuditLog.created_at.desc())
        .limit(8)
        .all()
    )

    # Monthly trend (last 6 months)
    monthly_trends = []
    for i in range(5, -1, -1):
        month_date = (today.replace(day=1) - timedelta(days=i * 30))
        mn, yr = month_date.month, month_date.year
        t = db.query(Attendance).filter(
            extract("month", Attendance.date) == mn,
            extract("year",  Attendance.date) == yr,
        ).count()
        p = db.query(Attendance).filter(
            extract("month", Attendance.date) == mn,
            extract("year",  Attendance.date) == yr,
            Attendance.status == "present",
        ).count()
        monthly_trends.append({
            "month":   month_date.strftime("%b %Y"),
            "total":   t,
            "present": p,
            "rate":    round((p / t * 100) if t > 0 else 0, 2),
        })

    return {
        "total_students":         total_students,
        "total_faculty":          total_faculty,
        "total_departments":      total_departments,
        "total_classrooms":       total_classrooms,
        "total_sessions":         total_sessions,
        "active_sessions":        active_sessions,
        "today_present":          today_present,
        "today_absent":           today_absent,
        "today_manual_review":    today_review,
        "today_total":            today_total,
        "registered_faces":       face_count,
        "registered_device_ids":  device_count,
        "active_ble_devices":     ble_active,
        "system_attendance_rate": system_rate,
        "monthly_trends":         monthly_trends,
        "recent_activity": [
            {
                "id":          a.id,
                "action":      a.action,
                "actor_name":  a.actor_name,
                "target_type": a.target_type,
                "target_id":   a.target_id,
                "detail":      a.detail,
                "created_at":  a.created_at.isoformat(),
            }
            for a in recent_audit
        ],
    }


# ══════════════════════════════════════════════════════════════
# ANALYTICS
# ══════════════════════════════════════════════════════════════

@router.get("/analytics")
async def system_analytics(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Department-wise breakdown, monthly trends, low attendance alerts."""
    today = date.today()

    # Department-wise
    departments = db.query(Student.department).distinct().all()
    dept_stats = []
    for (dept,) in departments:
        ids = [s.id for s in db.query(Student).filter(Student.department == dept).all()]
        if not ids:
            continue
        total   = db.query(Attendance).filter(Attendance.student_id.in_(ids)).count()
        present = db.query(Attendance).filter(
            Attendance.student_id.in_(ids), Attendance.status == "present"
        ).count()
        dept_stats.append({
            "department":      dept,
            "total_students":  len(ids),
            "total_records":   total,
            "present_records": present,
            "attendance_rate": round((present / total * 100) if total > 0 else 0, 2),
        })

    # Monthly trends
    monthly_trends = []
    for i in range(5, -1, -1):
        md = today.replace(day=1) - timedelta(days=i * 30)
        t = db.query(Attendance).filter(
            extract("month", Attendance.date) == md.month,
            extract("year",  Attendance.date) == md.year,
        ).count()
        p = db.query(Attendance).filter(
            extract("month", Attendance.date) == md.month,
            extract("year",  Attendance.date) == md.year,
            Attendance.status == "present",
        ).count()
        monthly_trends.append({
            "month":   md.strftime("%b %Y"),
            "total":   t,
            "present": p,
            "rate":    round((p / t * 100) if t > 0 else 0, 2),
        })

    # Low attendance alerts
    alerts = []
    for s in db.query(Student).all():
        records = db.query(Attendance).filter(Attendance.student_id == s.id).all()
        if not records:
            continue
        attended = sum(1 for r in records if r.status == "present")
        pct = (attended / len(records) * 100)
        if pct < 75.0:
            alerts.append({
                "student_id":   s.id,
                "student_name": s.name,
                "reg_no":       s.reg_no,
                "department":   s.department,
                "percentage":   round(pct, 2),
                "attended":     attended,
                "total":        len(records),
            })
    alerts.sort(key=lambda x: x["percentage"])

    recent_sessions = (
        db.query(SessionModel)
        .order_by(SessionModel.start_time.desc())
        .limit(10)
        .all()
    )

    return {
        "department_stats":      dept_stats,
        "monthly_trends":        monthly_trends,
        "low_attendance_alerts": alerts,
        "recent_sessions": [
            {
                "id":           s.id,
                "faculty_id":   s.faculty_id,
                "classroom_id": s.classroom_id,
                "is_active":    s.is_active,
                "start_time":   s.start_time.isoformat(),
                "end_time":     s.end_time.isoformat() if s.end_time else None,
            }
            for s in recent_sessions
        ],
    }


# ══════════════════════════════════════════════════════════════
# STUDENTS — FULL CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/students")
async def list_students(
    search:     Optional[str] = None,
    department: Optional[str] = None,
    is_active:  Optional[bool] = None,
    year:       Optional[int]  = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Student)
    if search:
        query = query.filter(
            (Student.name.ilike(f"%{search}%")) |
            (Student.reg_no.ilike(f"%{search}%")) |
            (Student.email.ilike(f"%{search}%"))
        )
    if department:
        query = query.filter(Student.department == department)
    if is_active is not None:
        query = query.filter(Student.is_active == is_active)
    if year is not None:
        query = query.filter(Student.year == year)

    total = query.count()
    students = query.offset(skip).limit(limit).all()
    return {
        "total": total,
        "items": [_student_dict(s) for s in students],
    }


@router.get("/students/{student_id}")
async def get_student(
    student_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    s = db.query(Student).filter(Student.id == student_id).first()
    if not s:
        raise HTTPException(status_code=404, detail="Student not found")
    return _student_dict(s)


@router.post("/students", status_code=status.HTTP_201_CREATED)
async def create_student(
    request: Request,
    name:        str = None,
    reg_no:      str = None,
    department:  str = None,
    year:        int = None,
    section:     str = None,
    email:       str = None,
    phone:       Optional[str] = None,
    password:    str = None,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    body = await request.json()
    name       = body.get("name")
    reg_no     = body.get("reg_no")
    department = body.get("department")
    year       = body.get("year")
    section    = body.get("section")
    email      = body.get("email")
    phone      = body.get("phone_number")
    password   = body.get("password", _generate_temp_password())

    if not all([name, reg_no, department, year, section, email]):
        raise HTTPException(status_code=400, detail="Missing required fields")

    if db.query(Student).filter(Student.email == email).first():
        raise HTTPException(status_code=409, detail="Email already exists")
    if db.query(Student).filter(Student.reg_no == reg_no).first():
        raise HTTPException(status_code=409, detail="Register number already exists")

    student = Student(
        name=name, reg_no=reg_no, department=department,
        year=year, section=section, email=email,
        phone_number=phone, password_hash=hash_password(password),
    )
    db.add(student)
    db.commit()
    db.refresh(student)

    log_action_from_admin(db, current_admin, "student.create", request,
        target_type="student", target_id=student.id,
        detail={"name": student.name, "reg_no": student.reg_no})

    return {**_student_dict(student), "temp_password": password}


@router.patch("/students/{student_id}")
async def edit_student(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    body = await request.json()
    for field in ["name", "email", "department", "section", "phone_number"]:
        if field in body:
            setattr(student, field, body[field])
    if "year" in body:
        student.year = int(body["year"])

    db.commit()
    db.refresh(student)

    log_action_from_admin(db, current_admin, "student.edit", request,
        target_type="student", target_id=student.id,
        detail={"updated_fields": list(body.keys())})

    return _student_dict(student)


@router.post("/students/{student_id}/suspend")
async def toggle_student_suspend(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    student.is_active = not student.is_active
    db.commit()

    action = "student.activate" if student.is_active else "student.suspend"
    log_action_from_admin(db, current_admin, action, request,
        target_type="student", target_id=student.id,
        detail={"name": student.name, "is_active": student.is_active})

    return {"student_id": student_id, "is_active": student.is_active}


@router.post("/students/{student_id}/reset-password")
async def reset_student_password(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    body = await request.json() if request.headers.get("content-type") == "application/json" else {}
    new_password = body.get("password") if body else None
    if not new_password:
        new_password = _generate_temp_password()

    student.password_hash = hash_password(new_password)
    db.commit()

    log_action_from_admin(db, current_admin, "student.reset_password", request,
        target_type="student", target_id=student.id,
        detail={"name": student.name})

    return {"student_id": student_id, "temp_password": new_password}


@router.delete("/students/{student_id}/face")
async def delete_student_face(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    deleted = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).delete()
    # Also clear face_id legacy field
    student.face_id = None
    db.commit()

    log_action_from_admin(db, current_admin, "face.delete", request,
        target_type="face", target_id=student_id,
        detail={"student_name": student.name, "embeddings_deleted": deleted})

    return {"student_id": student_id, "embeddings_deleted": deleted}


@router.get("/students/{student_id}/attendance")
async def student_attendance_history(
    student_id: int,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    records = (
        db.query(Attendance)
        .filter(Attendance.student_id == student_id)
        .order_by(Attendance.date.desc())
        .offset(skip).limit(limit)
        .all()
    )
    total = db.query(Attendance).filter(Attendance.student_id == student_id).count()
    present = db.query(Attendance).filter(
        Attendance.student_id == student_id, Attendance.status == "present"
    ).count()

    return {
        "student":    _student_dict(student),
        "total":      total,
        "present":    present,
        "percentage": round((present / total * 100) if total > 0 else 0, 2),
        "records": [
            {
                "id":             r.id,
                "date":           r.date.isoformat(),
                "time":           r.time,
                "status":         r.status,
                "session_id":     r.session_id,
                "rssi":           r.rssi,
                "face_confidence": r.face_confidence,
                "liveness_verified": r.liveness_verified,
                "attendance_method": r.attendance_method,
                "marked_at":      r.marked_at.isoformat() if r.marked_at else None,
            }
            for r in records
        ],
    }


@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    log_action_from_admin(db, current_admin, "student.delete", request,
        target_type="student", target_id=student_id,
        detail={"name": student.name, "reg_no": student.reg_no})

    db.delete(student)
    db.commit()


# ══════════════════════════════════════════════════════════════
# FACULTY — FULL CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/faculty")
async def list_faculty(
    search:     Optional[str]  = None,
    department: Optional[str]  = None,
    is_active:  Optional[bool] = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Faculty)
    if search:
        query = query.filter(
            Faculty.name.ilike(f"%{search}%") | Faculty.email.ilike(f"%{search}%")
        )
    if department:
        query = query.filter(Faculty.department == department)
    if is_active is not None:
        query = query.filter(Faculty.is_active == is_active)

    total   = query.count()
    faculty = query.offset(skip).limit(limit).all()
    return {"total": total, "items": [_faculty_dict(f) for f in faculty]}


@router.get("/faculty/{faculty_id}")
async def get_faculty(
    faculty_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    f = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Faculty not found")

    subjects = (
        db.query(Subject)
        .filter(Subject.faculty_id == faculty_id)
        .all()
    )
    return {
        **_faculty_dict(f),
        "subjects": [{"id": s.id, "subject_name": s.subject_name, "subject_code": s.subject_code} for s in subjects],
    }


@router.post("/faculty", status_code=status.HTTP_201_CREATED)
async def create_faculty(
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    body = await request.json()
    email = body.get("email", "")

    if db.query(Faculty).filter(Faculty.email == email).first():
        raise HTTPException(status_code=409, detail="Email already registered")

    password = body.get("password", _generate_temp_password())
    faculty = Faculty(
        name=body["name"],
        email=email,
        department=body.get("department"),
        phone_number=body.get("phone_number"),
        password_hash=hash_password(password),
    )
    db.add(faculty)
    db.commit()
    db.refresh(faculty)

    log_action_from_admin(db, current_admin, "faculty.create", request,
        target_type="faculty", target_id=faculty.id,
        detail={"name": faculty.name, "email": faculty.email})

    return {**_faculty_dict(faculty), "temp_password": password}


@router.patch("/faculty/{faculty_id}")
async def edit_faculty(
    faculty_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    f = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Faculty not found")

    body = await request.json()
    for field in ["name", "email", "department", "phone_number"]:
        if field in body:
            setattr(f, field, body[field])

    db.commit()
    db.refresh(f)

    log_action_from_admin(db, current_admin, "faculty.edit", request,
        target_type="faculty", target_id=f.id,
        detail={"updated_fields": list(body.keys())})

    return _faculty_dict(f)


@router.post("/faculty/{faculty_id}/suspend")
async def toggle_faculty_suspend(
    faculty_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    f = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Faculty not found")

    f.is_active = not f.is_active
    db.commit()

    action = "faculty.activate" if f.is_active else "faculty.suspend"
    log_action_from_admin(db, current_admin, action, request,
        target_type="faculty", target_id=faculty_id,
        detail={"name": f.name, "is_active": f.is_active})

    return {"faculty_id": faculty_id, "is_active": f.is_active}


@router.post("/faculty/{faculty_id}/reset-password")
async def reset_faculty_password(
    faculty_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    f = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Faculty not found")

    new_password = _generate_temp_password()
    f.password_hash = hash_password(new_password)
    db.commit()

    log_action_from_admin(db, current_admin, "faculty.reset_password", request,
        target_type="faculty", target_id=faculty_id,
        detail={"name": f.name})

    return {"faculty_id": faculty_id, "temp_password": new_password}


@router.delete("/faculty/{faculty_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_faculty(
    faculty_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    f = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not f:
        raise HTTPException(status_code=404, detail="Faculty not found")

    log_action_from_admin(db, current_admin, "faculty.delete", request,
        target_type="faculty", target_id=faculty_id,
        detail={"name": f.name})

    db.delete(f)
    db.commit()


# ══════════════════════════════════════════════════════════════
# CLASSROOMS CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/classrooms")
async def list_classrooms(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    classrooms = db.query(Classroom).all()
    return [
        {
            "id":              c.id,
            "room_name":       c.room_name,
            "ble_uuid":        c.ble_uuid,
            "attendance_code": c.attendance_code,
            "has_beacon":      c.ble_beacon is not None,
        }
        for c in classrooms
    ]


@router.post("/classrooms", status_code=status.HTTP_201_CREATED)
async def create_classroom(
    request_body: ClassroomCreateRequest,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    if db.query(Classroom).filter(Classroom.room_name == request_body.room_name.upper()).first():
        raise HTTPException(status_code=409, detail="Classroom name already exists")

    classroom = Classroom(room_name=request_body.room_name.upper(), ble_uuid=request_body.ble_uuid)
    db.add(classroom)
    db.commit()
    db.refresh(classroom)

    log_action_from_admin(db, current_admin, "classroom.create", request,
        target_type="classroom", target_id=classroom.id,
        detail={"room_name": classroom.room_name})

    return {"id": classroom.id, "room_name": classroom.room_name, "ble_uuid": classroom.ble_uuid}


@router.delete("/classrooms/{classroom_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_classroom(
    classroom_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    c = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="Classroom not found")

    log_action_from_admin(db, current_admin, "classroom.delete", request,
        target_type="classroom", target_id=classroom_id,
        detail={"room_name": c.room_name})

    db.delete(c)
    db.commit()


# ══════════════════════════════════════════════════════════════
# SUBJECTS CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/subjects")
async def list_subjects(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(Subject, Faculty.name.label("faculty_name"))
        .join(Faculty, Subject.faculty_id == Faculty.id)
        .all()
    )
    return [
        {
            "id":           r.Subject.id,
            "subject_name": r.Subject.subject_name,
            "subject_code": r.Subject.subject_code,
            "department":   r.Subject.department,
            "faculty_id":   r.Subject.faculty_id,
            "faculty_name": r.faculty_name,
        }
        for r in rows
    ]


@router.post("/subjects", status_code=status.HTTP_201_CREATED)
async def create_subject(
    request_body: SubjectCreateRequest,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    subject = Subject(
        subject_name=request_body.subject_name,
        subject_code=request_body.subject_code,
        department=request_body.department,
        faculty_id=request_body.faculty_id,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)

    log_action_from_admin(db, current_admin, "subject.create", request,
        target_type="subject", target_id=subject.id,
        detail={"subject_name": subject.subject_name})

    return {"id": subject.id, "subject_name": subject.subject_name, "faculty_id": subject.faculty_id}


# ══════════════════════════════════════════════════════════════
# SESSIONS MANAGEMENT
# ══════════════════════════════════════════════════════════════

@router.get("/sessions")
async def list_sessions(
    is_active:    Optional[bool] = None,
    faculty_id:   Optional[int]  = None,
    classroom_id: Optional[int]  = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(SessionModel)
    if is_active is not None:
        query = query.filter(SessionModel.is_active == is_active)
    if faculty_id:
        query = query.filter(SessionModel.faculty_id == faculty_id)
    if classroom_id:
        query = query.filter(SessionModel.classroom_id == classroom_id)

    total    = query.count()
    sessions = query.order_by(SessionModel.start_time.desc()).offset(skip).limit(limit).all()

    return {
        "total": total,
        "items": [
            {
                "id":           s.id,
                "faculty_id":   s.faculty_id,
                "classroom_id": s.classroom_id,
                "subject_id":   s.subject_id,
                "is_active":    s.is_active,
                "start_time":   s.start_time.isoformat(),
                "end_time":     s.end_time.isoformat() if s.end_time else None,
                "attendance_count": db.query(Attendance).filter(Attendance.session_id == s.id).count(),
            }
            for s in sessions
        ],
    }


@router.post("/sessions/{session_id}/close")
async def admin_close_session(
    session_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    session = db.query(SessionModel).filter(SessionModel.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    if not session.is_active:
        raise HTTPException(status_code=409, detail="Session already closed")

    session.is_active = False
    session.end_time  = datetime.utcnow()
    db.commit()

    log_action_from_admin(db, current_admin, "session.close", request,
        target_type="session", target_id=session_id)

    return {"session_id": session_id, "is_active": False}


# ══════════════════════════════════════════════════════════════
# ATTENDANCE MANAGEMENT
# ══════════════════════════════════════════════════════════════

@router.get("/attendance")
async def list_attendance(
    student_id:  Optional[int]  = None,
    session_id:  Optional[int]  = None,
    department:  Optional[str]  = None,
    att_status:  Optional[str]  = None,
    date_from:   Optional[str]  = None,
    date_to:     Optional[str]  = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Attendance, Student.name.label("student_name"), Student.reg_no)
        .join(Student, Attendance.student_id == Student.id)
    )
    if student_id:
        query = query.filter(Attendance.student_id == student_id)
    if session_id:
        query = query.filter(Attendance.session_id == session_id)
    if department:
        query = query.filter(Student.department == department)
    if att_status:
        query = query.filter(Attendance.status == att_status)
    if date_from:
        query = query.filter(Attendance.date >= date_from)
    if date_to:
        query = query.filter(Attendance.date <= date_to)

    total = query.count()
    rows  = query.order_by(Attendance.date.desc()).offset(skip).limit(limit).all()

    return {
        "total": total,
        "items": [
            {
                "id":             r.Attendance.id,
                "student_id":     r.Attendance.student_id,
                "student_name":   r.student_name,
                "reg_no":         r.reg_no,
                "session_id":     r.Attendance.session_id,
                "date":           r.Attendance.date.isoformat(),
                "time":           r.Attendance.time,
                "status":         r.Attendance.status,
                "rssi":           r.Attendance.rssi,
                "face_confidence": r.Attendance.face_confidence,
                "liveness_verified": r.Attendance.liveness_verified,
                "attendance_method": r.Attendance.attendance_method,
                "marked_at":      r.Attendance.marked_at.isoformat() if r.Attendance.marked_at else None,
            }
            for r in rows
        ],
    }


@router.patch("/attendance/{attendance_id}")
async def edit_attendance(
    attendance_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    record = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    body = await request.json()
    old_status = record.status

    if "status" in body:
        allowed = {"present", "absent", "manual_review", "rejected"}
        if body["status"] not in allowed:
            raise HTTPException(status_code=400, detail=f"status must be one of {allowed}")
        record.status = body["status"]

    db.commit()
    db.refresh(record)

    log_action_from_admin(db, current_admin, "attendance.edit", request,
        target_type="attendance", target_id=attendance_id,
        detail={"old_status": old_status, "new_status": record.status})

    return {"id": record.id, "status": record.status}


@router.delete("/attendance/{attendance_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_attendance(
    attendance_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    record = db.query(Attendance).filter(Attendance.id == attendance_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Attendance record not found")

    log_action_from_admin(db, current_admin, "attendance.delete", request,
        target_type="attendance", target_id=attendance_id,
        detail={"student_id": record.student_id, "session_id": record.session_id, "status": record.status})

    db.delete(record)
    db.commit()


@router.post("/attendance/manual", status_code=status.HTTP_201_CREATED)
async def manual_attendance(
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Manually mark attendance for a student in a session."""
    body = await request.json()
    student_id = body.get("student_id")
    session_id = body.get("session_id")
    att_status = body.get("status", "present")

    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    session = db.query(SessionModel).filter(SessionModel.id == session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    # Check for existing record
    existing = db.query(Attendance).filter(
        Attendance.student_id == student_id,
        Attendance.session_id == session_id,
    ).first()
    if existing:
        existing.status = att_status
        db.commit()
        record = existing
        action = "attendance.manual_edit"
    else:
        record = Attendance(
            student_id=student.id,
            classroom_id=session.classroom_id,
            subject_id=session.subject_id,
            session_id=session.id,
            date=date.today(),
            time=datetime.utcnow().strftime("%H:%M"),
            status=att_status,
            attendance_method="manual",
            liveness_verified=False,
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        action = "attendance.manual_mark"

    log_action_from_admin(db, current_admin, action, request,
        target_type="attendance", target_id=record.id,
        detail={"student_id": student_id, "session_id": session_id, "status": att_status})

    return {"id": record.id, "student_id": student_id, "session_id": session_id, "status": att_status}


# ══════════════════════════════════════════════════════════════
# FACE MANAGEMENT
# ══════════════════════════════════════════════════════════════

@router.get("/faces")
async def list_faces(
    search:     Optional[str] = None,
    department: Optional[str] = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(Student)
    if search:
        query = query.filter(
            Student.name.ilike(f"%{search}%") | Student.reg_no.ilike(f"%{search}%")
        )
    if department:
        query = query.filter(Student.department == department)

    total    = query.count()
    students = query.offset(skip).limit(limit).all()

    results = []
    for s in students:
        count = db.query(FaceEmbedding).filter(FaceEmbedding.student_id == s.id).count()
        results.append({
            "student_id":   s.id,
            "name":         s.name,
            "reg_no":       s.reg_no,
            "department":   s.department,
            "face_count":   count,
            "is_registered": count > 0,
            "face_image_url": s.face_image_url,
        })

    return {"total": total, "items": results}


# ══════════════════════════════════════════════════════════════
# DEVICE SECURITY
# ══════════════════════════════════════════════════════════════

@router.get("/device-logs")
async def list_device_logs(
    search:     Optional[str] = None,
    session_id: Optional[int] = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = (
        db.query(AttendanceDeviceLog,
                 Student.name.label("student_name"),
                 Student.reg_no)
        .join(Student, AttendanceDeviceLog.student_id == Student.id)
    )
    if session_id:
        query = query.filter(AttendanceDeviceLog.session_id == session_id)
    if search:
        query = query.filter(
            AttendanceDeviceLog.device_id.ilike(f"%{search}%") |
            Student.name.ilike(f"%{search}%") |
            Student.reg_no.ilike(f"%{search}%")
        )

    total = query.count()
    rows  = query.order_by(AttendanceDeviceLog.attendance_time.desc()).offset(skip).limit(limit).all()

    return {
        "total": total,
        "items": [
            {
                "id":             r.AttendanceDeviceLog.id,
                "session_id":     r.AttendanceDeviceLog.session_id,
                "student_id":     r.AttendanceDeviceLog.student_id,
                "student_name":   r.student_name,
                "reg_no":         r.reg_no,
                "device_id":      r.AttendanceDeviceLog.device_id,
                "attendance_time": r.AttendanceDeviceLog.attendance_time.isoformat(),
            }
            for r in rows
        ],
    }


@router.get("/device-logs/duplicates")
async def list_duplicate_devices(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Sessions where >1 distinct student used the same device — potential fraud."""
    from sqlalchemy import and_

    # Sub-query: count distinct students per (session, device)
    sub = (
        db.query(
            AttendanceDeviceLog.session_id,
            AttendanceDeviceLog.device_id,
            func.count(distinct(AttendanceDeviceLog.student_id)).label("student_count"),
        )
        .group_by(AttendanceDeviceLog.session_id, AttendanceDeviceLog.device_id)
        .subquery()
    )

    rows = db.query(sub).filter(sub.c.student_count > 1).all()
    return [
        {"session_id": r.session_id, "device_id": r.device_id, "student_count": r.student_count}
        for r in rows
    ]


@router.get("/device-bindings")
async def list_device_bindings(
    search: Optional[str] = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = (
        db.query(DeviceBinding, Student.name.label("student_name"), Student.reg_no)
        .join(Student, DeviceBinding.student_id == Student.id)
    )
    if search:
        query = query.filter(
            Student.name.ilike(f"%{search}%") |
            DeviceBinding.android_id.ilike(f"%{search}%")
        )

    total = query.count()
    rows  = query.offset(skip).limit(limit).all()

    return {
        "total": total,
        "items": [
            {
                "id":              r.DeviceBinding.id,
                "student_id":      r.DeviceBinding.student_id,
                "student_name":    r.student_name,
                "reg_no":          r.reg_no,
                "android_id":      r.DeviceBinding.android_id,
                "model":           r.DeviceBinding.model,
                "manufacturer":    r.DeviceBinding.manufacturer,
                "status":          r.DeviceBinding.status,
                "registered_at":   r.DeviceBinding.registered_at.isoformat(),
                "last_login":      r.DeviceBinding.last_login.isoformat() if r.DeviceBinding.last_login else None,
            }
            for r in rows
        ],
    }


@router.delete("/device-bindings/{binding_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_device_binding(
    binding_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    binding = db.query(DeviceBinding).filter(DeviceBinding.id == binding_id).first()
    if not binding:
        raise HTTPException(status_code=404, detail="Device binding not found")

    log_action_from_admin(db, current_admin, "device_binding.delete", request,
        target_type="device_binding", target_id=binding_id,
        detail={"student_id": binding.student_id, "android_id": binding.android_id})

    db.delete(binding)
    db.commit()


@router.delete("/students/{student_id}/device-binding", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student_device_binding(
    student_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    binding = db.query(DeviceBinding).filter(DeviceBinding.student_id == student_id).first()
    if not binding:
        raise HTTPException(status_code=404, detail="No device binding found for this student")

    log_action_from_admin(db, current_admin, "device_binding.remove_by_student", request,
        target_type="device_binding", target_id=binding.id,
        detail={"student_id": student_id, "android_id": binding.android_id})

    db.delete(binding)
    db.commit()


# ══════════════════════════════════════════════════════════════
# BLE BEACONS
# ══════════════════════════════════════════════════════════════

@router.get("/ble-beacons", response_model=list[BleBeaconResponse])
async def list_ble_beacons(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    return db.query(BleBeacon).all()


@router.post("/ble-beacons", response_model=BleBeaconResponse, status_code=status.HTTP_201_CREATED)
async def create_ble_beacon(
    request_body: BleBeaconCreateRequest,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    if not db.query(Classroom).filter(Classroom.id == request_body.classroom_id).first():
        raise HTTPException(status_code=404, detail="Classroom not found")

    if db.query(BleBeacon).filter(BleBeacon.classroom_id == request_body.classroom_id).first():
        raise HTTPException(status_code=409, detail="A beacon is already registered for this classroom")

    beacon = BleBeacon(
        classroom_id=request_body.classroom_id,
        beacon_uuid=request_body.beacon_uuid,
        beacon_name=request_body.beacon_name,
        rssi_threshold=request_body.rssi_threshold,
        tx_power=request_body.tx_power,
    )
    db.add(beacon)
    db.commit()
    db.refresh(beacon)

    log_action_from_admin(db, current_admin, "ble_beacon.create", request,
        target_type="ble_beacon", target_id=beacon.id,
        detail={"beacon_name": beacon.beacon_name, "classroom_id": beacon.classroom_id})

    return beacon


@router.put("/ble-beacons/{beacon_id}", response_model=BleBeaconResponse)
async def update_ble_beacon(
    beacon_id: int,
    request_body: BleBeaconCreateRequest,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    beacon = db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="BLE beacon not found")

    beacon.beacon_uuid    = request_body.beacon_uuid
    beacon.beacon_name    = request_body.beacon_name
    beacon.rssi_threshold = request_body.rssi_threshold
    beacon.tx_power       = request_body.tx_power
    db.commit()
    db.refresh(beacon)

    log_action_from_admin(db, current_admin, "ble_beacon.update", request,
        target_type="ble_beacon", target_id=beacon_id)

    return beacon


@router.patch("/ble-beacons/{beacon_id}/toggle")
async def toggle_ble_beacon(
    beacon_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    beacon = db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="BLE beacon not found")

    beacon.is_active = not beacon.is_active
    db.commit()

    log_action_from_admin(db, current_admin, "ble_beacon.toggle", request,
        target_type="ble_beacon", target_id=beacon_id,
        detail={"is_active": beacon.is_active})

    return {"beacon_id": beacon_id, "is_active": beacon.is_active}


@router.delete("/ble-beacons/{beacon_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_ble_beacon(
    beacon_id: int,
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    beacon = db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="BLE beacon not found")

    log_action_from_admin(db, current_admin, "ble_beacon.delete", request,
        target_type="ble_beacon", target_id=beacon_id,
        detail={"beacon_name": beacon.beacon_name})

    db.delete(beacon)
    db.commit()


# ══════════════════════════════════════════════════════════════
# SYSTEM SETTINGS
# ══════════════════════════════════════════════════════════════

@router.get("/settings")
async def get_settings(
    category: Optional[str] = None,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(SystemSettings)
    if category:
        query = query.filter(SystemSettings.category == category)

    rows = query.order_by(SystemSettings.category, SystemSettings.key).all()
    # Group by category
    result: dict = {}
    for r in rows:
        if r.category not in result:
            result[r.category] = []
        result[r.category].append({
            "key":        r.key,
            "value":      r.value,
            "label":      r.label,
            "updated_at": r.updated_at.isoformat() if r.updated_at else None,
        })
    return result


@router.patch("/settings")
async def update_settings(
    request: Request,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Bulk update settings. Body: {key: value, ...}"""
    body = await request.json()
    updated = []

    for key, value in body.items():
        setting = db.query(SystemSettings).filter(SystemSettings.key == key).first()
        if setting:
            setting.value = str(value)
            updated.append(key)
        # Unknown keys are silently ignored

    db.commit()

    log_action_from_admin(db, current_admin, "settings.update", request,
        detail={"updated_keys": updated})

    return {"updated": updated}


# ══════════════════════════════════════════════════════════════
# AUDIT LOGS
# ══════════════════════════════════════════════════════════════

@router.get("/audit-logs")
async def list_audit_logs(
    action:      Optional[str] = None,
    target_type: Optional[str] = None,
    actor_id:    Optional[int] = None,
    date_from:   Optional[str] = None,
    date_to:     Optional[str] = None,
    skip:  int = 0,
    limit: int = 50,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    query = db.query(AuditLog)
    if action:
        query = query.filter(AuditLog.action.ilike(f"%{action}%"))
    if target_type:
        query = query.filter(AuditLog.target_type == target_type)
    if actor_id:
        query = query.filter(AuditLog.actor_id == actor_id)
    if date_from:
        query = query.filter(AuditLog.created_at >= date_from)
    if date_to:
        query = query.filter(AuditLog.created_at <= date_to)

    total = query.count()
    logs  = query.order_by(AuditLog.created_at.desc()).offset(skip).limit(limit).all()

    return {
        "total": total,
        "items": [
            {
                "id":          l.id,
                "action":      l.action,
                "actor_id":    l.actor_id,
                "actor_name":  l.actor_name,
                "actor_role":  l.actor_role,
                "target_type": l.target_type,
                "target_id":   l.target_id,
                "detail":      l.detail,
                "ip_address":  l.ip_address,
                "created_at":  l.created_at.isoformat(),
            }
            for l in logs
        ],
    }


# ══════════════════════════════════════════════════════════════
# REPORTS & EXPORT  (existing — kept + extended)
# ══════════════════════════════════════════════════════════════

@router.get("/export/{fmt}")
async def admin_export_report(
    fmt:        str,
    period:     str          = "monthly",
    department: Optional[str] = None,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    from fastapi.responses import Response
    from app.services.report_service import generate_csv, generate_excel, generate_pdf

    fmt = fmt.lower()
    if fmt not in ["csv", "xlsx", "pdf"]:
        raise HTTPException(status_code=400, detail="Unsupported format. Use csv, xlsx, or pdf.")

    today = date.today()
    if period == "daily":
        start_date = today
    elif period == "weekly":
        start_date = today - timedelta(days=7)
    else:
        start_date = today.replace(day=1)

    query = (
        db.query(Attendance, Student.name.label("student_name"), Student.reg_no)
        .join(Student, Attendance.student_id == Student.id)
        .filter(Attendance.date >= start_date)
    )
    if department:
        query = query.filter(Student.department == department)

    rows = query.order_by(Attendance.date.desc()).all()

    from app.models.models import Subject as SubjectModel, Classroom as ClassroomModel
    data = []
    for r in rows:
        subj = db.query(SubjectModel).filter(SubjectModel.id == r.Attendance.subject_id).first()
        room = db.query(ClassroomModel).filter(ClassroomModel.id == r.Attendance.classroom_id).first()
        data.append({
            "id":             r.Attendance.id,
            "student_name":   r.student_name,
            "reg_no":         r.reg_no,
            "subject":        subj.subject_name if subj else "N/A",
            "classroom":      room.room_name if room else "N/A",
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
        })

    if fmt == "csv":
        content, media_type, filename = generate_csv(data), "text/csv", f"smartattend_{period}.csv"
    elif fmt == "xlsx":
        content = generate_excel(data)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"smartattend_{period}.xlsx"
    else:
        content, media_type, filename = (
            generate_pdf(data, title=f"System-Wide {period.title()} Report"),
            "application/pdf",
            f"smartattend_{period}.pdf",
        )

    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ══════════════════════════════════════════════════════════════
# FACE IMAGE (existing)
# ══════════════════════════════════════════════════════════════

@router.get("/students/{student_id}/face-image")
async def get_student_face_image(
    student_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    url = student.face_image_url or f"{settings.APP_BASE_URL}/static/faces/{student.id}.jpg"
    return {"student_id": student_id, "presigned_url": url, "expires_in": 3600}
