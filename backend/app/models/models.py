# ============================================================
# SmartAttend — SQLAlchemy ORM Models (v3)
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
    # Kept on student for quick-access; canonical record is in FaceProfile
    face_id          = Column(String(255), nullable=True)         # AWS Rekognition FaceId
    face_image_url   = Column(String(500), nullable=True)         # S3 URI
    created_at       = Column(DateTime, default=func.now())

    # Relationships
    attendances   = relationship("Attendance", back_populates="student")
    face_profile  = relationship("FaceProfile", back_populates="student", uselist=False)


class Faculty(Base):
    """Faculty user model."""
    __tablename__ = "faculty"

    id            = Column(Integer, primary_key=True, index=True)
    name          = Column(String(100), nullable=False)
    department    = Column(String(100), nullable=True)
    email         = Column(String(150), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at    = Column(DateTime, default=func.now())

    # Relationships
    subjects              = relationship("Subject", back_populates="faculty")
    sessions              = relationship("Session", back_populates="faculty")
    faculty_subject_links = relationship("FacultySubject", back_populates="faculty")


class Admin(Base):
    """Admin user model."""
    __tablename__ = "admins"

    id            = Column(Integer, primary_key=True, index=True)
    name          = Column(String(100), nullable=False)
    email         = Column(String(150), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at    = Column(DateTime, default=func.now())


class Classroom(Base):
    """Classroom with ESP32 BLE beacon configuration."""
    __tablename__ = "classrooms"

    id               = Column(Integer, primary_key=True, index=True)
    room_name        = Column(String(50), unique=True, nullable=False)  # e.g. CLASSROOM_A101
    ble_uuid         = Column(String(100), unique=True, nullable=False)
    attendance_code  = Column(String(6), nullable=True)  # internal only
    created_at       = Column(DateTime, default=func.now())

    # Relationships
    sessions    = relationship("Session", back_populates="classroom")
    attendances = relationship("Attendance", back_populates="classroom")
    ble_beacon  = relationship("BleBeacon", back_populates="classroom", uselist=False)


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
    rssi_threshold = Column(Integer, nullable=False, default=-70)
    tx_power       = Column(Integer, nullable=True)
    is_active      = Column(Boolean, default=True)
    last_seen_at   = Column(DateTime, nullable=True)
    created_at     = Column(DateTime, default=func.now())

    # Relationships
    classroom = relationship("Classroom", back_populates="ble_beacon")


class FaceProfile(Base):
    """
    Normalized face profile for a student.
    Stores AWS Rekognition FaceId + S3 metadata.
    """
    __tablename__ = "face_profiles"

    id            = Column(Integer, primary_key=True, index=True)
    student_id    = Column(Integer, ForeignKey("students.id", ondelete="CASCADE"), nullable=False, unique=True)
    face_id       = Column(String(255), nullable=False)    # AWS Rekognition FaceId
    s3_key        = Column(String(500), nullable=False)    # S3 object key
    s3_url        = Column(String(500), nullable=False)    # Full S3 URI
    confidence    = Column(Float, nullable=True)
    registered_at = Column(DateTime, default=func.now())
    updated_at    = Column(DateTime, default=func.now(), onupdate=func.now())

    # Relationships
    student = relationship("Student", back_populates="face_profile")


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
    """Timetable entry linking class, subject, faculty, and classroom."""
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
    """
    __tablename__ = "sessions"

    id              = Column(Integer, primary_key=True, index=True)
    classroom_id    = Column(Integer, ForeignKey("classrooms.id"), nullable=False)
    subject_id      = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    faculty_id      = Column(Integer, ForeignKey("faculty.id"), nullable=False)
    attendance_code = Column(String(6), nullable=False)  # internal only — not shown to students
    start_time      = Column(DateTime, default=func.now())
    end_time        = Column(DateTime, nullable=True)
    is_active       = Column(Boolean, default=True)
    created_at      = Column(DateTime, default=func.now())

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

    id             = Column(Integer, primary_key=True, index=True)
    student_id     = Column(Integer, ForeignKey("students.id"), nullable=False)
    classroom_id   = Column(Integer, ForeignKey("classrooms.id"), nullable=False)
    subject_id     = Column(Integer, ForeignKey("subjects.id"), nullable=False)
    session_id     = Column(Integer, ForeignKey("sessions.id"), nullable=True)
    date           = Column(Date, nullable=False)
    time           = Column(String(10), nullable=False)  # HH:MM format
    status         = Column(String(10), default="present")  # present | absent | late
    rssi           = Column(Integer, nullable=True)
    face_confidence = Column(Float, nullable=True)
    marked_at      = Column(DateTime, default=func.now())

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
