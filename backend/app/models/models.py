# ============================================================
# SmartAttend — SQLAlchemy ORM Models (v13 — ERP Timetable)
# ArcFace embeddings stored in face_embeddings table.
# OCR timetable module REMOVED; ERP timetable module ADDED.
# ============================================================

from datetime import datetime
import uuid as _uuid
from sqlalchemy import (
    Column, Integer, String, DateTime, Date, Time,
    ForeignKey, Float, Boolean, Text, Index
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Student(Base):
    """Student user model."""
    __tablename__ = "students"

    id               = Column(Integer, primary_key=True, index=True)
    name             = Column(String(100), nullable=False)
    reg_no           = Column(String(20), unique=True, nullable=False, index=True)
    department       = Column(String(100), nullable=False)
    year             = Column(Integer, nullable=False)
    section          = Column(String(5), nullable=False)
    email            = Column(String(150), unique=True, nullable=False, index=True)
    phone_number     = Column(String(20), nullable=True)
    password_hash    = Column(String(255), nullable=False)
    is_active        = Column(Boolean, default=True, nullable=False)  # False = suspended by admin
    # Legacy field kept for schema compatibility (unused after ArcFace migration)
    face_id          = Column(String(255), nullable=True)
    face_image_url   = Column(String(500), nullable=True)
    created_at       = Column(DateTime, default=func.now())

    # Relationships
    attendances   = relationship("Attendance", back_populates="student")
    face_profile  = relationship("FaceProfile", back_populates="student", uselist=False)
    student_faces = relationship("StudentFace", back_populates="student")
    face_embeddings = relationship("FaceEmbedding", back_populates="student", cascade="all, delete-orphan")


class Faculty(Base):
    """Faculty user model — extended with ERP fields."""
    __tablename__ = "faculty"

    id            = Column(Integer, primary_key=True, index=True)
    name          = Column(String(100), nullable=False)
    department    = Column(String(100), nullable=True)
    email         = Column(String(150), unique=True, nullable=False, index=True)
    phone_number  = Column(String(20), nullable=True)
    password_hash = Column(String(255), nullable=False)
    is_active     = Column(Boolean, default=True, nullable=False)
    # v13: ERP fields (nullable for backward compat)
    employee_id   = Column(String(30), nullable=True, index=True)
    designation   = Column(String(100), nullable=True)
    created_at    = Column(DateTime, default=func.now())

    # Relationships
    subjects              = relationship("Subject", back_populates="faculty")
    sessions              = relationship("Session", back_populates="faculty")
    faculty_subject_links = relationship("FacultySubject", back_populates="faculty")
    erp_timetable_slots   = relationship("WeeklyTimetableSlot", back_populates="faculty")


class Admin(Base):
    """Admin user model."""
    __tablename__ = "admins"

    id            = Column(Integer, primary_key=True, index=True)
    name          = Column(String(100), nullable=False)
    email         = Column(String(150), unique=True, nullable=False, index=True)
    phone_number  = Column(String(20), nullable=True)
    password_hash = Column(String(255), nullable=False)
    is_active     = Column(Boolean, default=True, nullable=False)
    created_at    = Column(DateTime, default=func.now())


class Classroom(Base):
    """Classroom with ESP32 BLE beacon configuration."""
    __tablename__ = "classrooms"

    id               = Column(Integer, primary_key=True, index=True)
    room_name        = Column(String(50), unique=True, nullable=False)  # e.g. A101
    ble_uuid         = Column(String(100), unique=True, nullable=True)   # nullable for ERP classrooms without beacon
    attendance_code  = Column(String(6), nullable=True)                  # internal only
    created_at       = Column(DateTime, default=func.now())

    # Relationships
    sessions    = relationship("Session", back_populates="classroom")
    attendances = relationship("Attendance", back_populates="classroom")
    ble_beacon  = relationship("BleBeacon", back_populates="classroom", uselist=False)
    erp_timetable_slots = relationship("WeeklyTimetableSlot", back_populates="classroom")


class BleBeacon(Base):
    """
    ESP32 BLE beacon configuration — one-to-one with Classroom.
    Stores per-beacon RSSI threshold and metadata.
    """
    __tablename__ = "ble_beacons"

    id             = Column(Integer, primary_key=True, index=True)
    classroom_id   = Column(Integer, ForeignKey("classrooms.id", ondelete="CASCADE"), nullable=False, unique=True)
    beacon_uuid    = Column(String(100), unique=True, nullable=False)
    beacon_name    = Column(String(100), nullable=False)
    rssi_threshold = Column(Integer, nullable=False, default=-75)
    tx_power       = Column(Integer, nullable=True)
    is_active      = Column(Boolean, default=True)
    last_seen_at   = Column(DateTime, nullable=True)
    created_at     = Column(DateTime, default=func.now())

    # Relationships
    classroom = relationship("Classroom", back_populates="ble_beacon")


class FaceProfile(Base):
    """
    Legacy face profile table — kept for schema compatibility.
    Primary face data is stored in FaceEmbedding (ArcFace embeddings).
    This table is no longer written to in new registrations.
    """
    __tablename__ = "face_profiles"

    id            = Column(Integer, primary_key=True, index=True)
    student_id    = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, unique=True)
    face_id       = Column(String(255), nullable=True)   # Legacy field (unused)
    s3_key        = Column(String(500), nullable=True)   # Legacy field (unused)
    s3_url        = Column(String(500), nullable=True)   # Legacy field (unused)
    confidence    = Column(Float, nullable=True)
    registered_at = Column(DateTime, default=func.now())
    updated_at    = Column(DateTime, default=func.now(), onupdate=func.now())

    # Relationships
    student = relationship("Student", back_populates="face_profile")


class StudentFace(Base):
    """
    Legacy table storing guided-pose face images per student.
    No longer actively written to after auto-capture registration migration.
    Kept for schema compatibility.
    """
    __tablename__ = "student_faces"

    id                = Column(Integer, primary_key=True, index=True)
    student_id        = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    face_id           = Column(String(255), nullable=True)   # Legacy field (unused)
    image_url         = Column(String(500), nullable=True)   # Legacy field (unused)
    s3_key            = Column(String(500), nullable=True)   # Legacy field (unused)
    pose_index        = Column(Integer, nullable=False)       # 1-15
    pose_type         = Column(String(50), nullable=False)    # front_face, left_15, etc.
    confidence        = Column(Float, nullable=True)          # ArcFace detection confidence
    is_primary        = Column(Boolean, default=False)        # True = embedding stored in FaceEmbedding table
    registration_date = Column(DateTime, default=func.now())

    # Relationships
    student = relationship("Student", back_populates="student_faces")

    __table_args__ = (
        Index("uq_student_pose", "student_id", "pose_index", unique=True),
    )


class FaceEmbedding(Base):
    """
    ArcFace (InsightFace buffalo_l) embeddings per student.
    Each row = one 512-dim normalized embedding from a registered face frame.
    Multiple rows per student (30–50 samples from auto-capture registration).
    Verification uses max cosine similarity across all stored embeddings.
    """
    __tablename__ = "face_embeddings"

    id             = Column(Integer, primary_key=True, index=True)
    student_id     = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, index=True)
    embedding_json = Column(Text, nullable=False)  # JSON string of the 512-dim float list
    pose_name      = Column(String(50), nullable=False)
    embedding_version = Column(String(20), nullable=True, default="buffalo_s", server_default="buffalo_l")
    created_at     = Column(DateTime, default=func.now())

    # Relationships
    student = relationship("Student", back_populates="face_embeddings")


class Subject(Base):
    """Academic subject taught by a faculty member."""
    __tablename__ = "subjects"

    id           = Column(Integer, primary_key=True, index=True)
    subject_name = Column(String(100), nullable=False)
    subject_code = Column(String(20), nullable=True)
    department   = Column(String(100), nullable=True)
    faculty_id   = Column(Integer, ForeignKey("faculty.id"), nullable=False)
    created_at   = Column(DateTime, default=func.now())

    # Relationships
    faculty               = relationship("Faculty", back_populates="subjects")
    sessions              = relationship("Session", back_populates="subject")
    attendances           = relationship("Attendance", back_populates="subject")
    faculty_subject_links = relationship("FacultySubject", back_populates="subject")


class FacultySubject(Base):
    """Many-to-many junction: faculty ↔ subjects."""
    __tablename__ = "faculty_subjects"

    id         = Column(Integer, primary_key=True, index=True)
    faculty_id = Column(Integer, ForeignKey("faculty.id", ondelete="CASCADE"), nullable=False)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)

    # Relationships
    faculty = relationship("Faculty", back_populates="faculty_subject_links")
    subject = relationship("Subject", back_populates="faculty_subject_links")

    __table_args__ = (
        Index("uq_faculty_subject", "faculty_id", "subject_id", unique=True),
    )


class ClassTimetable(Base):
    """Legacy timetable entry — kept for schema compat. Use WeeklyTimetableSlot for new data."""
    __tablename__ = "class_timetable"

    id           = Column(Integer, primary_key=True, index=True)
    class_name   = Column(String(50), nullable=False)
    semester     = Column(Integer, nullable=False)
    day_of_week  = Column(String(10), nullable=False)
    period       = Column(Integer, nullable=False)
    subject_id   = Column(Integer, ForeignKey("subjects.id", ondelete="CASCADE"), nullable=False)
    faculty_id   = Column(Integer, ForeignKey("faculty.id", ondelete="CASCADE"), nullable=False)
    classroom_id = Column(Integer, ForeignKey("classrooms.id", ondelete="SET NULL"), nullable=True)
    start_time   = Column(String(10), nullable=False)
    end_time     = Column(String(10), nullable=False)
    created_at   = Column(DateTime, default=func.now())

    # Relationships
    subject   = relationship("Subject")
    faculty   = relationship("Faculty")
    classroom = relationship("Classroom")


class Session(Base):
    """
    An attendance session created by a faculty member.
    One session per class period — attendance is tied to sessions.
    v10: added department/year/section targeting, BLE radius, duration, status.
    """
    __tablename__ = "sessions"

    id              = Column(Integer, primary_key=True, index=True)
    classroom_id    = Column(Integer, ForeignKey("classrooms.id"), nullable=False)
    subject_id      = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    faculty_id      = Column(Integer, ForeignKey("faculty.id"), nullable=False)
    attendance_code = Column(String(6), nullable=False)  # internal only
    start_time      = Column(DateTime, default=func.now())
    end_time        = Column(DateTime, nullable=True)
    is_active       = Column(Boolean, default=True)
    created_at      = Column(DateTime, default=func.now())

    # ── v10 additions ─────────────────────────────────────────
    department        = Column(String(100), nullable=True)  # target class dept
    year              = Column(Integer, nullable=True)       # target year (1–4)
    section           = Column(String(5), nullable=True)     # target section
    attendance_radius = Column(Integer, nullable=False, default=20)  # metres
    duration_minutes  = Column(Integer, nullable=False, default=15)  # minutes
    session_name      = Column(String(200), nullable=True)   # auto-generated label
    status            = Column(String(20), nullable=False, default="active")  # active|closed

    # Relationships
    classroom        = relationship("Classroom", back_populates="sessions")
    subject          = relationship("Subject", back_populates="sessions")
    faculty          = relationship("Faculty", back_populates="sessions")
    attendances      = relationship("Attendance", back_populates="session")
    attendance_links = relationship("AttendanceLink", back_populates="session")


class AttendanceLink(Base):
    """
    Unique shareable link generated per session.
    This is the primary attendance method — shared via WhatsApp.
    Attendance code is NOT exposed through this; BLE + Face are used instead.
    """
    __tablename__ = "attendance_links"

    id           = Column(Integer, primary_key=True, index=True)
    session_id   = Column(Integer, ForeignKey("sessions.id", ondelete="CASCADE"), nullable=False)
    token        = Column(String(64), unique=True, nullable=False, default=lambda: _uuid.uuid4().hex)
    deep_link    = Column(String(500), nullable=False)  # smartattend://attendance/{session_id}
    web_link     = Column(String(500), nullable=False)  # https://smartattend.app/attendance/{session_id}
    whatsapp_url = Column(Text, nullable=False)
    is_active    = Column(Boolean, default=True)
    expires_at   = Column(DateTime, nullable=True)
    created_at   = Column(DateTime, default=func.now())

    # Relationships
    session = relationship("Session", back_populates="attendance_links")


class Attendance(Base):
    """Individual attendance record for a student in a session."""
    __tablename__ = "attendance"

    id               = Column(Integer, primary_key=True, index=True)
    student_id       = Column(Integer, ForeignKey("students.id"), nullable=False)
    classroom_id     = Column(Integer, ForeignKey("classrooms.id"), nullable=False)
    subject_id       = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    session_id       = Column(Integer, ForeignKey("sessions.id"), nullable=True)
    date             = Column(Date, nullable=False)
    time             = Column(String(10), nullable=False)   # HH:MM format
    status           = Column(String(15), default="present")  # present | absent | manual_review | rejected
    rssi             = Column(Integer, nullable=True)
    face_confidence  = Column(Float, nullable=True)
    # ── v4: anti-spoofing + liveness ──────────────────────────
    liveness_verified   = Column(Boolean, default=False)         # Passed blink/smile/movement challenge
    confidence_tier     = Column(String(15), nullable=True)      # present | manual_review | rejected
    attendance_method   = Column(String(20), default="ble_face") # ble_face | qr
    marked_at           = Column(DateTime, default=func.now())

    # Relationships
    student   = relationship("Student", back_populates="attendances")
    classroom = relationship("Classroom", back_populates="attendances")
    subject   = relationship("Subject", back_populates="attendances")
    session   = relationship("Session", back_populates="attendances")

    # Composite unique constraint: one attendance per student per session
    __table_args__ = (
        Index(
            "uq_student_session",
            "student_id",
            "session_id",
            unique=True,
        ),
    )


class AttendanceDeviceLog(Base):
    """
    Session-scoped device usage log.

    Records which Android device (identified by ANDROID_ID) was used to mark
    attendance in a given session. This prevents two different students from
    using the SAME physical phone to mark attendance in the SAME class session.

    Scope: per-session only. The same device CAN be used again in a different
    session (e.g., afternoon class after a morning class).

    NOT a permanent device lock — see DeviceBinding for that.
    """
    __tablename__ = "attendance_device_log"

    id              = Column(Integer, primary_key=True, index=True)
    session_id      = Column(
        Integer,
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    student_id      = Column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    device_id       = Column(String(64), nullable=False, index=True)  # Android ANDROID_ID
    attendance_time = Column(DateTime, nullable=False, default=func.now())

    # Relationships
    session = relationship("Session")
    student = relationship("Student")

    __table_args__ = (
        # One entry per device per session — a device can only mark once per session
        Index("uq_device_session", "session_id", "device_id", unique=True),
    )

    def __repr__(self) -> str:
        return (
            f"<AttendanceDeviceLog session={self.session_id} "
            f"student={self.student_id} device={self.device_id}>"
        )


class AuditLog(Base):
    """
    Immutable audit trail — one row per admin action.

    Every mutation made through the admin panel is recorded here.
    Records are never deleted (admin cannot delete audit logs via API).

    actor_role: 'admin' | 'system'
    target_type: 'student' | 'faculty' | 'attendance' | 'session' |
                 'face' | 'device_binding' | 'ble_beacon' | 'settings' | 'classroom'
    """
    __tablename__ = "audit_logs"

    id          = Column(Integer, primary_key=True, index=True)
    actor_id    = Column(Integer, nullable=True, index=True)       # admin.id
    actor_name  = Column(String(100), nullable=True)               # denormalized for history
    actor_role  = Column(String(20), nullable=False, default="admin")
    action      = Column(String(100), nullable=False, index=True)  # e.g. "student.suspend"
    target_type = Column(String(50), nullable=True, index=True)
    target_id   = Column(Integer, nullable=True)
    detail      = Column(Text, nullable=True)                      # JSON-serialized extra info
    ip_address  = Column(String(45), nullable=True)                # IPv4 or IPv6
    user_agent  = Column(String(500), nullable=True)
    created_at  = Column(DateTime, nullable=False, default=func.now(), index=True)

    def __repr__(self) -> str:
        return f"<AuditLog {self.action} by {self.actor_name} at {self.created_at}>"


class SystemSettings(Base):
    """
    Key-value settings store for admin-configurable system parameters.

    category: 'general' | 'attendance' | 'face' | 'ble' | 'security'

    Examples:
        college_name       = "SmartCollege"
        attendance_window  = "30"          (minutes, attendance open after session start)
        face_threshold     = "0.75"
        ble_rssi_threshold = "-80"
        working_days       = "Mon,Tue,Wed,Thu,Fri"
    """
    __tablename__ = "system_settings"

    id         = Column(Integer, primary_key=True, index=True)
    key        = Column(String(100), unique=True, nullable=False, index=True)
    value      = Column(Text, nullable=True)
    category   = Column(String(30), nullable=False, default="general", index=True)
    label      = Column(String(200), nullable=True)   # Human-readable label for UI
    updated_at = Column(DateTime, default=func.now(), onupdate=func.now())

    def __repr__(self) -> str:
        return f"<SystemSettings {self.key}={self.value}>"


# ─── ERP Timetable Module (v13) ─────────────────────────────


class ErpDepartment(Base):
    """
    Academic department. Supports unlimited departments.
    Preloaded with 11 standard departments on first run.
    """
    __tablename__ = "erp_departments"

    id           = Column(Integer, primary_key=True, index=True)
    name         = Column(String(200), nullable=False)          # Full name
    short_name   = Column(String(20), nullable=False)           # Abbreviation e.g. CSE, AIML
    degree_type  = Column(String(20), nullable=False, default="B.E.")  # B.E. | B.Tech. | M.E. | M.Tech.
    is_active    = Column(Boolean, default=True, nullable=False)
    created_at   = Column(DateTime, default=func.now())
    updated_at   = Column(DateTime, default=func.now(), onupdate=func.now())

    # Relationships
    sections     = relationship("ErpDepartmentSection", back_populates="department",
                                cascade="all, delete-orphan")
    erp_subjects = relationship("ErpSubject", back_populates="department",
                                cascade="all, delete-orphan")
    timetable_slots = relationship("WeeklyTimetableSlot", back_populates="department")

    def __repr__(self) -> str:
        return f"<ErpDepartment {self.short_name}>"


class ErpDepartmentSection(Base):
    """
    Section configuration per department per year.
    e.g. AIML Year 1 has sections A, B, C, D.
    Admin can configure unlimited sections.
    """
    __tablename__ = "erp_department_sections"

    id            = Column(Integer, primary_key=True, index=True)
    department_id = Column(Integer, ForeignKey("erp_departments.id", ondelete="CASCADE"),
                           nullable=False, index=True)
    year          = Column(Integer, nullable=False)    # 1, 2, 3, 4
    section       = Column(String(5), nullable=False)  # A, B, C, ...
    classroom_id  = Column(Integer, ForeignKey("classrooms.id", ondelete="SET NULL"),
                           nullable=True)              # default classroom for this section
    student_count = Column(Integer, nullable=True, default=0)
    created_at    = Column(DateTime, default=func.now())

    # Relationships
    department = relationship("ErpDepartment", back_populates="sections")
    classroom  = relationship("Classroom")

    __table_args__ = (
        Index("uq_dept_year_section", "department_id", "year", "section", unique=True),
    )

    def __repr__(self) -> str:
        return f"<ErpDepartmentSection dept={self.department_id} Y{self.year}{self.section}>"


class PeriodTiming(Base):
    """
    Academic period timing configuration.
    Admin configures periods, breaks, and lunch times.
    Default: 9 slots (7 periods + break + lunch).
    """
    __tablename__ = "period_timings"

    id          = Column(Integer, primary_key=True, index=True)
    label       = Column(String(30), nullable=False)   # "Period 1", "Break", "Lunch"
    start_time  = Column(String(8), nullable=False)    # HH:MM
    end_time    = Column(String(8), nullable=False)    # HH:MM
    period_type = Column(String(20), nullable=False, default="Theory")
    # Theory | Lab | Break | Lunch | Tutorial | Elective
    order_index = Column(Integer, nullable=False, default=0)   # Sort order
    is_active   = Column(Boolean, default=True, nullable=False)
    created_at  = Column(DateTime, default=func.now())

    # Relationships
    timetable_slots = relationship("WeeklyTimetableSlot", back_populates="period_timing")

    __table_args__ = (
        Index("uq_period_order", "order_index", unique=True),
    )

    def __repr__(self) -> str:
        return f"<PeriodTiming {self.label} {self.start_time}-{self.end_time}>"


class ErpSubject(Base):
    """
    ERP subject — belongs to a department.
    Admin creates subjects per department and assigns to timetable slots.
    """
    __tablename__ = "erp_subjects"

    id            = Column(Integer, primary_key=True, index=True)
    subject_name  = Column(String(150), nullable=False)
    subject_code  = Column(String(30), nullable=True)
    department_id = Column(Integer, ForeignKey("erp_departments.id", ondelete="CASCADE"),
                           nullable=False, index=True)
    year          = Column(Integer, nullable=True)        # 1-4, None = all years
    credits       = Column(Integer, nullable=True)
    subject_type  = Column(String(20), nullable=False, default="Theory")
    # Theory | Lab | Elective | Tutorial
    is_active     = Column(Boolean, default=True, nullable=False)
    created_at    = Column(DateTime, default=func.now())
    updated_at    = Column(DateTime, default=func.now(), onupdate=func.now())

    # Relationships
    department      = relationship("ErpDepartment", back_populates="erp_subjects")
    timetable_slots = relationship("WeeklyTimetableSlot", back_populates="erp_subject")

    def __repr__(self) -> str:
        return f"<ErpSubject {self.subject_name}>"


class WeeklyTimetableSlot(Base):
    """
    One cell in the weekly timetable grid.
    Identifies: Department + Year + Section + Day + Period → Subject + Faculty + Room + Type.
    This is the primary ERP timetable data store.
    """
    __tablename__ = "weekly_timetable_slots"

    id              = Column(Integer, primary_key=True, index=True)
    department_id   = Column(Integer, ForeignKey("erp_departments.id", ondelete="CASCADE"),
                             nullable=False, index=True)
    year            = Column(Integer, nullable=False)       # 1-4
    section         = Column(String(5), nullable=False)     # A, B, C, ...
    day_of_week     = Column(String(10), nullable=False)    # Monday..Saturday
    period_timing_id= Column(Integer, ForeignKey("period_timings.id", ondelete="CASCADE"),
                             nullable=False, index=True)

    # Assigned resources (nullable — breaks/lunch have no subject)
    erp_subject_id  = Column(Integer, ForeignKey("erp_subjects.id", ondelete="SET NULL"),
                             nullable=True)
    faculty_id      = Column(Integer, ForeignKey("faculty.id", ondelete="SET NULL"),
                             nullable=True)
    classroom_id    = Column(Integer, ForeignKey("classrooms.id", ondelete="SET NULL"),
                             nullable=True)

    # Class metadata
    class_type      = Column(String(20), nullable=False, default="Theory")
    # Theory | Lab | Elective | Tutorial | Break | Lunch | Free

    # Academic context
    academic_year   = Column(String(20), nullable=True)    # "2025-2026"
    semester        = Column(Integer, nullable=True)        # 1 or 2

    # Soft delete
    is_active       = Column(Boolean, default=True, nullable=False)

    created_at      = Column(DateTime, default=func.now())
    updated_at      = Column(DateTime, default=func.now(), onupdate=func.now())

    # Relationships
    department    = relationship("ErpDepartment", back_populates="timetable_slots")
    period_timing = relationship("PeriodTiming", back_populates="timetable_slots")
    erp_subject   = relationship("ErpSubject", back_populates="timetable_slots")
    faculty       = relationship("Faculty", back_populates="erp_timetable_slots")
    classroom     = relationship("Classroom", back_populates="erp_timetable_slots")

    __table_args__ = (
        Index(
            "uq_timetable_slot",
            "department_id", "year", "section",
            "day_of_week", "period_timing_id",
            unique=True,
        ),
    )

    def __repr__(self) -> str:
        return (
            f"<WeeklyTimetableSlot dept={self.department_id} "
            f"Y{self.year}{self.section} {self.day_of_week} P{self.period_timing_id}>"
        )
