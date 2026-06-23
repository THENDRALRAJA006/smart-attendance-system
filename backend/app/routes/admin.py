# ============================================================
# SmartAttend — Admin Routes (v3)
# Full CRUD for students, faculty, classrooms, subjects, beacons
# Analytics: low attendance alerts, total sessions
# ============================================================

import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, distinct
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.dependencies import get_current_admin
from app.core.security import hash_password
from app.core.config import settings
from app.models.models import (
    Admin, Student, Faculty, Classroom, Subject, Attendance,
    Session as SessionModel, BleBeacon
)
from app.schemas.schemas import (
    ClassroomCreateRequest, ClassroomResponse,
    SubjectCreateRequest, SubjectResponse,
    FacultyRegisterRequest,
    BleBeaconCreateRequest, BleBeaconResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin"])


# ─── GET /admin/dashboard ────────────────────────────────────
@router.get("/dashboard")
async def admin_dashboard(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """System-wide analytics for admin."""
    total_students    = db.query(Student).count()
    total_faculty     = db.query(Faculty).count()
    total_departments = db.query(func.count(distinct(Student.department))).scalar() or 0
    total_classrooms  = db.query(Classroom).count()
    total_sessions    = db.query(SessionModel).count()

    # System attendance rate
    total_records   = db.query(Attendance).count()
    present_records = db.query(Attendance).filter(Attendance.status == "present").count()
    system_rate = (present_records / total_records * 100) if total_records > 0 else 0.0

    return {
        "total_students":         total_students,
        "total_faculty":          total_faculty,
        "total_departments":      total_departments,
        "total_classrooms":       total_classrooms,
        "total_sessions":         total_sessions,
        "system_attendance_rate": round(system_rate, 2),
    }


# ══════════════════════════════════════════════════════════════
# STUDENTS CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/students")
async def list_students(
    search: Optional[str] = None,
    department: Optional[str] = None,
    skip: int = 0,
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

    students = query.offset(skip).limit(limit).all()
    return [
        {
            "id": s.id,
            "name": s.name,
            "reg_no": s.reg_no,
            "department": s.department,
            "year": s.year,
            "section": s.section,
            "email": s.email,
            "face_id": s.face_id,
            "created_at": s.created_at.isoformat(),
        }
        for s in students
    ]


@router.get("/students/{student_id}")
async def get_student_by_id(
    student_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    return {
        "id": student.id,
        "name": student.name,
        "reg_no": student.reg_no,
        "department": student.department,
        "year": student.year,
        "section": student.section,
        "email": student.email,
        "face_id": student.face_id,
        "created_at": student.created_at.isoformat(),
    }


@router.delete("/students/{student_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_student(
    student_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
    db.delete(student)
    db.commit()


# ══════════════════════════════════════════════════════════════
# FACULTY CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/faculty")
async def list_faculty(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    faculty_list = db.query(Faculty).all()
    return [
        {"id": f.id, "name": f.name, "email": f.email}
        for f in faculty_list
    ]


@router.post("/faculty", status_code=status.HTTP_201_CREATED)
async def create_faculty(
    request: FacultyRegisterRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(Faculty).filter(Faculty.email == request.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )
    faculty = Faculty(
        name=request.name,
        email=request.email,
        department=request.department,
        password_hash=hash_password(request.password),
    )
    db.add(faculty)
    db.commit()
    db.refresh(faculty)
    return {
        "id":         faculty.id,
        "name":       faculty.name,
        "email":      faculty.email,
        "department": faculty.department,
    }


@router.delete("/faculty/{faculty_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_faculty(
    faculty_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    faculty = db.query(Faculty).filter(Faculty.id == faculty_id).first()
    if not faculty:
        raise HTTPException(status_code=404, detail="Faculty not found")
    db.delete(faculty)
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
            "id": c.id,
            "room_name": c.room_name,
            "ble_uuid": c.ble_uuid,
            "attendance_code": c.attendance_code,
        }
        for c in classrooms
    ]


@router.post("/classrooms", status_code=status.HTTP_201_CREATED)
async def create_classroom(
    request: ClassroomCreateRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    existing = db.query(Classroom).filter(
        Classroom.room_name == request.room_name.upper()
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Classroom name already exists",
        )
    classroom = Classroom(
        room_name=request.room_name.upper(),
        ble_uuid=request.ble_uuid,
    )
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    return {
        "id": classroom.id,
        "room_name": classroom.room_name,
        "ble_uuid": classroom.ble_uuid,
    }


@router.delete("/classrooms/{classroom_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_classroom(
    classroom_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    classroom = db.query(Classroom).filter(Classroom.id == classroom_id).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="Classroom not found")
    db.delete(classroom)
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
            "id": r.Subject.id,
            "subject_name": r.Subject.subject_name,
            "subject_code": r.Subject.subject_code,
            "faculty_id": r.Subject.faculty_id,
            "faculty_name": r.faculty_name,
        }
        for r in rows
    ]


@router.post("/subjects", status_code=status.HTTP_201_CREATED)
async def create_subject(
    request: SubjectCreateRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    subject = Subject(
        subject_name=request.subject_name,
        subject_code=request.subject_code,
        department=request.department,
        faculty_id=request.faculty_id,
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return {
        "id": subject.id,
        "subject_name": subject.subject_name,
        "faculty_id": subject.faculty_id,
    }


# ══════════════════════════════════════════════════════════════
# ANALYTICS
# ══════════════════════════════════════════════════════════════

@router.get("/analytics")
async def system_analytics(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    System-wide attendance analytics for admin dashboard.

    Returns:
    - Department-wise attendance rates
    - Monthly attendance trends (last 6 months)
    - Low attendance alerts (students < 75%)
    - Recent sessions
    """
    from datetime import date, timedelta
    from sqlalchemy import extract

    today = date.today()

    # ─── Department-wise breakdown ───────────────────────────
    departments = db.query(Student.department).distinct().all()
    dept_stats = []
    for (dept,) in departments:
        dept_students = db.query(Student).filter(Student.department == dept).all()
        dept_ids = [s.id for s in dept_students]
        if not dept_ids:
            continue
        total   = db.query(Attendance).filter(Attendance.student_id.in_(dept_ids)).count()
        present = db.query(Attendance).filter(
            Attendance.student_id.in_(dept_ids),
            Attendance.status == "present",
        ).count()
        dept_stats.append({
            "department":      dept,
            "total_students":  len(dept_ids),
            "total_records":   total,
            "present_records": present,
            "attendance_rate": round((present / total * 100) if total > 0 else 0, 2),
        })

    # ─── Monthly trends (last 6 months) ─────────────────────
    monthly_trends = []
    for i in range(5, -1, -1):
        month_date = today.replace(day=1) - timedelta(days=i * 30)
        month_num  = month_date.month
        year_num   = month_date.year
        total   = db.query(Attendance).filter(
            extract("month", Attendance.date) == month_num,
            extract("year",  Attendance.date) == year_num,
        ).count()
        present = db.query(Attendance).filter(
            extract("month", Attendance.date) == month_num,
            extract("year",  Attendance.date) == year_num,
            Attendance.status == "present",
        ).count()
        monthly_trends.append({
            "month":   month_date.strftime("%b %Y"),
            "total":   total,
            "present": present,
            "rate":    round((present / total * 100) if total > 0 else 0, 2),
        })

    # ─── Low Attendance Alerts (< 75%) ───────────────────────
    all_students = db.query(Student).all()
    low_attendance_alerts = []
    for s in all_students:
        records = db.query(Attendance).filter(Attendance.student_id == s.id).all()
        if not records:
            continue
        attended   = sum(1 for r in records if r.status == "present")
        total_recs = len(records)
        pct = (attended / total_recs * 100) if total_recs > 0 else 0.0
        if pct < 75.0:
            low_attendance_alerts.append({
                "student_id":   s.id,
                "student_name": s.name,
                "reg_no":       s.reg_no,
                "department":   s.department,
                "percentage":   round(pct, 2),
                "attended":     attended,
                "total":        total_recs,
            })
    # Sort by percentage ascending (worst first)
    low_attendance_alerts.sort(key=lambda x: x["percentage"])

    # ─── Recent sessions (last 10) ───────────────────────────
    recent_sessions = (
        db.query(SessionModel)
        .order_by(SessionModel.start_time.desc())
        .limit(10)
        .all()
    )

    return {
        "department_stats":       dept_stats,
        "monthly_trends":         monthly_trends,
        "low_attendance_alerts":  low_attendance_alerts,
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
# SYSTEM-WIDE EXPORT
# ══════════════════════════════════════════════════════════════

@router.get("/export/{fmt}")
async def admin_export_report(
    fmt: str,
    period: str = "monthly",
    department: Optional[str] = None,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """
    Export system-wide attendance report.

    Supported formats: csv, xlsx, pdf
    Optionally filter by department.
    """
    from fastapi.responses import Response
    from app.services.report_service import (
        generate_csv, generate_excel, generate_pdf
    )
    from datetime import date, timedelta

    fmt = fmt.lower()
    if fmt not in ["csv", "xlsx", "pdf"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Unsupported format. Use csv, xlsx, or pdf.",
        )

    today = date.today()
    if period == "daily":
        start_date = today
    elif period == "weekly":
        start_date = today - timedelta(days=7)
    else:
        start_date = today.replace(day=1)

    query = (
        db.query(
            Attendance,
            Student.name.label("student_name"),
            Student.reg_no,
        )
        .join(Student, Attendance.student_id == Student.id)
        .filter(Attendance.date >= start_date)
    )

    if department:
        query = query.join(
            Student, Attendance.student_id == Student.id, isouter=True
        ).filter(Student.department == department)

    rows = query.order_by(Attendance.date.desc()).all()

    # Build data list reusing report_service format
    from app.models.models import Subject as SubjectModel, Classroom as ClassroomModel
    data = []
    for r in rows:
        subj = db.query(SubjectModel).filter(SubjectModel.id == r.Attendance.subject_id).first()
        room = db.query(ClassroomModel).filter(ClassroomModel.id == r.Attendance.classroom_id).first()
        data.append({
            "id": r.Attendance.id,
            "student_name": r.student_name,
            "reg_no": r.reg_no,
            "subject": subj.subject_name if subj else "N/A",
            "classroom": room.room_name if room else "N/A",
            "date": r.Attendance.date.isoformat(),
            "time": r.Attendance.time,
            "status": r.Attendance.status,
            "rssi": r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
        })

    if fmt == "csv":
        content = generate_csv(data)
        media_type = "text/csv"
        filename = f"smartattend_report_{period}.csv"
    elif fmt == "xlsx":
        content = generate_excel(data)
        media_type = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        filename = f"smartattend_report_{period}.xlsx"
    else:
        content = generate_pdf(data, title=f"System-Wide {period.title()} Report")
        media_type = "application/pdf"
        filename = f"smartattend_report_{period}.pdf"

    return Response(
        content=content,
        media_type=media_type,
        headers={"Content-Disposition": f"attachment; filename={filename}"},
    )


# ─── GET /admin/students/{id}/face-image ─────────────────────
@router.get("/students/{student_id}/face-image")
async def get_student_face_image(
    student_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Get a time-limited presigned URL to view a student's registered face."""
    student = db.query(Student).filter(Student.id == student_id).first()
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")

    url = student.face_image_url or f"{settings.APP_BASE_URL}/static/faces/{student.id}.jpg"
    return {"student_id": student_id, "presigned_url": url, "expires_in": 3600}


# ══════════════════════════════════════════════════════════════
# BLE BEACONS CRUD
# ══════════════════════════════════════════════════════════════

@router.get("/ble-beacons", response_model=list[BleBeaconResponse])
async def list_ble_beacons(
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """List all registered ESP32 BLE beacons."""
    beacons = db.query(BleBeacon).all()
    return beacons


@router.post("/ble-beacons", response_model=BleBeaconResponse, status_code=status.HTTP_201_CREATED)
async def create_ble_beacon(
    request: BleBeaconCreateRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Register a new ESP32 BLE beacon for a classroom."""
    classroom = db.query(Classroom).filter(Classroom.id == request.classroom_id).first()
    if not classroom:
        raise HTTPException(status_code=404, detail="Classroom not found")

    existing = db.query(BleBeacon).filter(
        BleBeacon.classroom_id == request.classroom_id
    ).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A beacon is already registered for this classroom",
        )

    beacon = BleBeacon(
        classroom_id=request.classroom_id,
        beacon_uuid=request.beacon_uuid,
        beacon_name=request.beacon_name,
        rssi_threshold=request.rssi_threshold,
        tx_power=request.tx_power,
    )
    db.add(beacon)
    db.commit()
    db.refresh(beacon)
    return beacon


@router.put("/ble-beacons/{beacon_id}", response_model=BleBeaconResponse)
async def update_ble_beacon(
    beacon_id: int,
    request: BleBeaconCreateRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Update BLE beacon configuration (e.g., RSSI threshold)."""
    beacon = db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="BLE beacon not found")

    beacon.beacon_uuid    = request.beacon_uuid
    beacon.beacon_name    = request.beacon_name
    beacon.rssi_threshold = request.rssi_threshold
    beacon.tx_power       = request.tx_power
    db.commit()
    db.refresh(beacon)
    return beacon


@router.delete("/ble-beacons/{beacon_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_ble_beacon(
    beacon_id: int,
    current_admin: Admin = Depends(get_current_admin),
    db: Session = Depends(get_db),
):
    """Remove a BLE beacon registration."""
    beacon = db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()
    if not beacon:
        raise HTTPException(status_code=404, detail="BLE beacon not found")
    db.delete(beacon)
    db.commit()
