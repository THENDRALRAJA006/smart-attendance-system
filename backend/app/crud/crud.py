# ============================================================
# SmartAttend — CRUD Operations Layer
# Centralised database operations (no logic in routes)
# ============================================================

from datetime import date, timedelta
from typing import Optional, List
from sqlalchemy import func, distinct, extract
from sqlalchemy.orm import Session

from app.models.models import (
    Student, Faculty, Admin, Classroom, Subject, FacultySubject,
    Session as SessionModel, Attendance, BleBeacon, FaceProfile, AttendanceLink
)
from app.core.security import hash_password


# ══════════════════════════════════════════════════════════════
# STUDENT CRUD
# ══════════════════════════════════════════════════════════════

def get_student_by_id(db: Session, student_id: int) -> Optional[Student]:
    return db.query(Student).filter(Student.id == student_id).first()

def get_student_by_email(db: Session, email: str) -> Optional[Student]:
    return db.query(Student).filter(Student.email == email).first()

def get_student_by_reg_no(db: Session, reg_no: str) -> Optional[Student]:
    return db.query(Student).filter(Student.reg_no == reg_no).first()

def get_students(
    db: Session,
    search: Optional[str] = None,
    department: Optional[str] = None,
    skip: int = 0,
    limit: int = 50,
) -> List[Student]:
    query = db.query(Student)
    if search:
        query = query.filter(
            (Student.name.ilike(f"%{search}%")) |
            (Student.reg_no.ilike(f"%{search}%")) |
            (Student.email.ilike(f"%{search}%"))
        )
    if department:
        query = query.filter(Student.department == department)
    return query.offset(skip).limit(limit).all()

def create_student(db: Session, data: dict) -> Student:
    student = Student(
        name=data["name"],
        reg_no=data["reg_no"],
        department=data["department"],
        year=data["year"],
        section=data["section"],
        email=data["email"],
        phone_number=data.get("phone_number"),
        password_hash=hash_password(data["password"]),
    )
    db.add(student)
    db.commit()
    db.refresh(student)
    return student

def update_student_face(db: Session, student: Student, face_id: str, s3_url: str) -> Student:
    student.face_id = face_id
    student.face_image_url = s3_url
    db.commit()
    db.refresh(student)
    return student

def delete_student(db: Session, student: Student) -> None:
    db.delete(student)
    db.commit()


# ══════════════════════════════════════════════════════════════
# FACULTY CRUD
# ══════════════════════════════════════════════════════════════

def get_faculty_by_id(db: Session, faculty_id: int) -> Optional[Faculty]:
    return db.query(Faculty).filter(Faculty.id == faculty_id).first()

def get_faculty_by_email(db: Session, email: str) -> Optional[Faculty]:
    return db.query(Faculty).filter(Faculty.email == email).first()

def get_all_faculty(db: Session) -> List[Faculty]:
    return db.query(Faculty).all()

def create_faculty(db: Session, data: dict) -> Faculty:
    faculty = Faculty(
        name=data["name"],
        email=data["email"],
        department=data.get("department"),
        password_hash=hash_password(data["password"]),
    )
    db.add(faculty)
    db.commit()
    db.refresh(faculty)
    return faculty

def delete_faculty(db: Session, faculty: Faculty) -> None:
    db.delete(faculty)
    db.commit()

def get_faculty_subjects(db: Session, faculty_id: int) -> List[Subject]:
    return (
        db.query(Subject)
        .join(FacultySubject, FacultySubject.subject_id == Subject.id)
        .filter(FacultySubject.faculty_id == faculty_id)
        .all()
    )


# ══════════════════════════════════════════════════════════════
# ADMIN CRUD
# ══════════════════════════════════════════════════════════════

def get_admin_by_email(db: Session, email: str) -> Optional[Admin]:
    return db.query(Admin).filter(Admin.email == email).first()

def get_admin_by_id(db: Session, admin_id: int) -> Optional[Admin]:
    return db.query(Admin).filter(Admin.id == admin_id).first()


# ══════════════════════════════════════════════════════════════
# CLASSROOM CRUD
# ══════════════════════════════════════════════════════════════

def get_all_classrooms(db: Session) -> List[Classroom]:
    return db.query(Classroom).all()

def get_classroom_by_id(db: Session, classroom_id: int) -> Optional[Classroom]:
    return db.query(Classroom).filter(Classroom.id == classroom_id).first()

def get_classroom_by_name(db: Session, room_name: str) -> Optional[Classroom]:
    return db.query(Classroom).filter(Classroom.room_name == room_name).first()

def create_classroom(db: Session, room_name: str, ble_uuid: str) -> Classroom:
    classroom = Classroom(room_name=room_name.upper(), ble_uuid=ble_uuid)
    db.add(classroom)
    db.commit()
    db.refresh(classroom)
    return classroom

def delete_classroom(db: Session, classroom: Classroom) -> None:
    db.delete(classroom)
    db.commit()


# ══════════════════════════════════════════════════════════════
# SUBJECT CRUD
# ══════════════════════════════════════════════════════════════

def get_all_subjects(db: Session) -> List:
    """Returns list of (Subject, faculty_name)."""
    return (
        db.query(Subject, Faculty.name.label("faculty_name"))
        .join(Faculty, Subject.faculty_id == Faculty.id)
        .all()
    )

def get_subject_by_id(db: Session, subject_id: int) -> Optional[Subject]:
    return db.query(Subject).filter(Subject.id == subject_id).first()

def create_subject(db: Session, data: dict) -> Subject:
    subject = Subject(
        subject_name=data["subject_name"],
        subject_code=data.get("subject_code"),
        department=data.get("department"),
        faculty_id=data["faculty_id"],
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)
    return subject

def link_faculty_subject(db: Session, faculty_id: int, subject_id: int) -> FacultySubject:
    link = FacultySubject(faculty_id=faculty_id, subject_id=subject_id)
    db.add(link)
    db.commit()
    return link


# ══════════════════════════════════════════════════════════════
# SESSION CRUD
# ══════════════════════════════════════════════════════════════

def get_session_by_id(db: Session, session_id: int) -> Optional[SessionModel]:
    return db.query(SessionModel).filter(SessionModel.id == session_id).first()

def get_active_session_for_classroom(db: Session, classroom_id: int) -> Optional[SessionModel]:
    return (
        db.query(SessionModel)
        .filter(
            SessionModel.classroom_id == classroom_id,
            SessionModel.is_active == True,
        )
        .order_by(SessionModel.start_time.desc())
        .first()
    )

def create_session(
    db: Session,
    classroom_id: int,
    subject_id: int,
    faculty_id: int,
    attendance_code: str,
) -> SessionModel:
    # Deactivate previous sessions in same classroom
    db.query(SessionModel).filter(
        SessionModel.classroom_id == classroom_id,
        SessionModel.is_active == True,
    ).update({"is_active": False})

    session = SessionModel(
        classroom_id=classroom_id,
        subject_id=subject_id,
        faculty_id=faculty_id,
        attendance_code=attendance_code,
        is_active=True,
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session

def end_session(db: Session, session: SessionModel) -> SessionModel:
    from datetime import datetime
    session.is_active = False
    session.end_time = datetime.now()
    db.query(AttendanceLink).filter(
        AttendanceLink.session_id == session.id
    ).update({"is_active": False})
    db.commit()
    db.refresh(session)
    return session


# ══════════════════════════════════════════════════════════════
# ATTENDANCE CRUD
# ══════════════════════════════════════════════════════════════

def get_student_attendance(db: Session, student_id: int) -> List[Attendance]:
    return (
        db.query(Attendance)
        .filter(Attendance.student_id == student_id)
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

def get_student_attendance_by_period(
    db: Session,
    student_id: int,
    start_date: date,
) -> List:
    return (
        db.query(Attendance, Subject.subject_name, Classroom.room_name)
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .filter(
            Attendance.student_id == student_id,
            Attendance.date >= start_date,
        )
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

def get_duplicate_attendance(
    db: Session, student_id: int, session_id: int
) -> Optional[Attendance]:
    return (
        db.query(Attendance)
        .filter(
            Attendance.student_id == student_id,
            Attendance.session_id == session_id,
        )
        .first()
    )

def create_attendance_record(
    db: Session,
    student_id: int,
    classroom_id: int,
    subject_id: int,
    session_id: int,
    rssi: int,
    face_confidence: float,
) -> Attendance:
    from datetime import datetime
    now = datetime.now()
    record = Attendance(
        student_id=student_id,
        classroom_id=classroom_id,
        subject_id=subject_id,
        session_id=session_id,
        date=now.date(),
        time=now.strftime("%H:%M"),
        status="present",
        rssi=rssi,
        face_confidence=face_confidence,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record

def get_session_attendance(db: Session, session_id: int) -> List:
    return (
        db.query(Attendance, Student.name.label("student_name"), Student.reg_no)
        .join(Student, Attendance.student_id == Student.id)
        .filter(Attendance.session_id == session_id)
        .order_by(Attendance.marked_at.asc())
        .all()
    )


# ══════════════════════════════════════════════════════════════
# ANALYTICS CRUD
# ══════════════════════════════════════════════════════════════

def get_system_stats(db: Session) -> dict:
    total_students    = db.query(Student).count()
    total_faculty     = db.query(Faculty).count()
    total_departments = db.query(func.count(distinct(Student.department))).scalar() or 0
    total_classrooms  = db.query(Classroom).count()
    total_sessions    = db.query(SessionModel).count()
    total_records     = db.query(Attendance).count()
    present_records   = db.query(Attendance).filter(Attendance.status == "present").count()
    rate = (present_records / total_records * 100) if total_records > 0 else 0.0
    return {
        "total_students":         total_students,
        "total_faculty":          total_faculty,
        "total_departments":      total_departments,
        "total_classrooms":       total_classrooms,
        "total_sessions":         total_sessions,
        "system_attendance_rate": round(rate, 2),
    }

def get_low_attendance_students(db: Session, threshold: float = 75.0) -> List[dict]:
    students = db.query(Student).all()
    result = []
    for s in students:
        records  = db.query(Attendance).filter(Attendance.student_id == s.id).all()
        if not records:
            continue
        attended   = sum(1 for r in records if r.status == "present")
        total_recs = len(records)
        pct = (attended / total_recs * 100) if total_recs > 0 else 0.0
        if pct < threshold:
            result.append({
                "student_id":   s.id,
                "student_name": s.name,
                "reg_no":       s.reg_no,
                "department":   s.department,
                "percentage":   round(pct, 2),
                "attended":     attended,
                "total":        total_recs,
            })
    result.sort(key=lambda x: x["percentage"])
    return result


# ══════════════════════════════════════════════════════════════
# BLE BEACON CRUD
# ══════════════════════════════════════════════════════════════

def get_all_ble_beacons(db: Session) -> List[BleBeacon]:
    return db.query(BleBeacon).all()

def get_beacon_by_id(db: Session, beacon_id: int) -> Optional[BleBeacon]:
    return db.query(BleBeacon).filter(BleBeacon.id == beacon_id).first()

def get_beacon_by_classroom(db: Session, classroom_id: int) -> Optional[BleBeacon]:
    return db.query(BleBeacon).filter(BleBeacon.classroom_id == classroom_id).first()

def create_ble_beacon(db: Session, data: dict) -> BleBeacon:
    beacon = BleBeacon(
        classroom_id=data["classroom_id"],
        beacon_uuid=data["beacon_uuid"],
        beacon_name=data["beacon_name"],
        rssi_threshold=data.get("rssi_threshold", -70),
        tx_power=data.get("tx_power"),
    )
    db.add(beacon)
    db.commit()
    db.refresh(beacon)
    return beacon

def delete_ble_beacon(db: Session, beacon: BleBeacon) -> None:
    db.delete(beacon)
    db.commit()


# ══════════════════════════════════════════════════════════════
# FACE PROFILE CRUD
# ══════════════════════════════════════════════════════════════

def get_face_profile(db: Session, student_id: int) -> Optional[FaceProfile]:
    return db.query(FaceProfile).filter(FaceProfile.student_id == student_id).first()

def upsert_face_profile(
    db: Session,
    student_id: int,
    face_id: str,
    s3_key: str,
    s3_url: str,
) -> FaceProfile:
    profile = get_face_profile(db, student_id)
    if profile:
        profile.face_id = face_id
        profile.s3_key  = s3_key
        profile.s3_url  = s3_url
    else:
        profile = FaceProfile(
            student_id=student_id,
            face_id=face_id,
            s3_key=s3_key,
            s3_url=s3_url,
        )
        db.add(profile)
    db.commit()
    db.refresh(profile)
    return profile
