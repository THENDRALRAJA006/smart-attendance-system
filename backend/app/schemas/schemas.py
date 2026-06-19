# ============================================================
# SmartAttend — Pydantic Request/Response Schemas (v3)
# ============================================================

from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional, List
from datetime import datetime, date


# ══════════════════════════════════════════════════════════════
# AUTH SCHEMAS
# ══════════════════════════════════════════════════════════════

class StudentRegisterRequest(BaseModel):
    name:         str
    reg_no:       str
    department:   str
    year:         int
    section:      str
    email:        EmailStr
    phone_number: Optional[str] = None
    password:     str

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain an uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain a digit")
        return v

    @field_validator("year")
    @classmethod
    def valid_year(cls, v: int) -> int:
        if v not in [1, 2, 3, 4]:
            raise ValueError("Year must be 1–4")
        return v


class LoginRequest(BaseModel):
    email:    EmailStr
    password: str
    role:     str  # student | faculty | admin

    @field_validator("role")
    @classmethod
    def valid_role(cls, v: str) -> str:
        if v not in ["student", "faculty", "admin"]:
            raise ValueError("Role must be student, faculty, or admin")
        return v


class RefreshTokenRequest(BaseModel):
    """Request body for POST /auth/refresh"""
    refresh_token: str


class FacultyRegisterRequest(BaseModel):
    name:       str
    email:      EmailStr
    password:   str
    department: Optional[str] = None


# ══════════════════════════════════════════════════════════════
# STUDENT SCHEMAS
# ══════════════════════════════════════════════════════════════

class StudentResponse(BaseModel):
    id:             int
    name:           str
    reg_no:         str
    department:     str
    year:           int
    section:        str
    email:          str
    phone_number:   Optional[str]  = None
    face_id:        Optional[str]  = None
    face_image_url: Optional[str]  = None
    created_at:     datetime

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"
    role:          str
    user:          dict


class TokenRefreshResponse(BaseModel):
    access_token:  str
    refresh_token: str
    token_type:    str = "bearer"


# ══════════════════════════════════════════════════════════════
# ATTENDANCE SCHEMAS
# ══════════════════════════════════════════════════════════════

class AttendanceMarkRequest(BaseModel):
    """Request body for POST /attendance/mark (session-id based flow)."""
    session_id: int
    rssi:       int


class AttendanceVerifyRequest(BaseModel):
    """Request body for POST /attendance/verify (pre-check without marking)."""
    session_id: int
    rssi:       int


class AttendanceResponse(BaseModel):
    id:             int
    student_id:     int
    student_name:   Optional[str] = None
    classroom_id:   int
    classroom_name: Optional[str] = None
    subject_id:     int
    subject_name:   Optional[str] = None
    date:           date
    time:           str
    status:         str
    rssi:           Optional[int]   = None
    face_confidence: Optional[float] = None

    class Config:
        from_attributes = True


class FaceVerifyResponse(BaseModel):
    match:      bool
    confidence: float
    message:    str


class LiveAttendanceEntry(BaseModel):
    """A single student who has marked attendance in a live session."""
    student_id:     int
    student_name:   str
    reg_no:         str
    time:           str
    rssi:           Optional[int]   = None
    face_confidence: Optional[float] = None
    status:         str = "present"


# ══════════════════════════════════════════════════════════════
# ATTENDANCE LINK SCHEMAS
# ══════════════════════════════════════════════════════════════

class AttendanceLinkResponse(BaseModel):
    """Response from the link-generation endpoints."""
    session_id:   int
    token:        str
    deep_link:    str
    web_link:     str
    whatsapp_url: str
    message:      str
    classroom:    str
    subject:      str
    faculty:      str
    is_active:    bool


# ══════════════════════════════════════════════════════════════
# DASHBOARD SCHEMAS
# ══════════════════════════════════════════════════════════════

class SubjectAttendanceStats(BaseModel):
    subject_name: str
    total:        int
    attended:     int
    percentage:   float


class StudentDashboardResponse(BaseModel):
    total_classes:        int
    attended_classes:     int
    attendance_percentage: float
    subject_wise:         List[SubjectAttendanceStats]
    recent_history:       List[AttendanceResponse]


class FacultyDashboardResponse(BaseModel):
    sessions:     List[dict]
    classrooms:   List[dict]
    subjects:     List[dict]
    faculty_name: Optional[str] = None
    department:   Optional[str] = None


class AdminDashboardResponse(BaseModel):
    total_students:         int
    total_faculty:          int
    total_departments:      int
    total_classrooms:       int
    total_sessions:         int
    system_attendance_rate: float


# ══════════════════════════════════════════════════════════════
# LOW ATTENDANCE ALERT
# ══════════════════════════════════════════════════════════════

class LowAttendanceAlert(BaseModel):
    student_id:   int
    student_name: str
    reg_no:       str
    department:   str
    percentage:   float
    attended:     int
    total:        int


# ══════════════════════════════════════════════════════════════
# SESSION SCHEMAS
# ══════════════════════════════════════════════════════════════

class CreateSessionRequest(BaseModel):
    classroom_id:    int
    subject_id:      int
    attendance_code: str  # internal — generated server-side

    @field_validator("attendance_code")
    @classmethod
    def valid_code(cls, v: str) -> str:
        if len(v) != 6 or not v.isdigit():
            raise ValueError("Attendance code must be 6 digits")
        return v


class SessionResponse(BaseModel):
    id:              int
    classroom_id:    int
    classroom_name:  str
    subject_id:      int
    subject_name:    str
    # attendance_code intentionally omitted from response — internal only
    start_time:      datetime
    end_time:        Optional[datetime] = None
    is_active:       bool

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════════════════════
# CLASSROOM SCHEMAS
# ══════════════════════════════════════════════════════════════

class ClassroomCreateRequest(BaseModel):
    room_name: str
    ble_uuid:  str


class ClassroomResponse(BaseModel):
    id:        int
    room_name: str
    ble_uuid:  str

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════════════════════
# BLE BEACON SCHEMAS
# ══════════════════════════════════════════════════════════════

class BleBeaconCreateRequest(BaseModel):
    classroom_id:   int
    beacon_uuid:    str
    beacon_name:    str
    rssi_threshold: int = -70
    tx_power:       Optional[int] = None


class BleBeaconResponse(BaseModel):
    id:             int
    classroom_id:   int
    beacon_uuid:    str
    beacon_name:    str
    rssi_threshold: int
    tx_power:       Optional[int] = None
    is_active:      bool

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════════════════════
# SUBJECT SCHEMAS
# ══════════════════════════════════════════════════════════════

class SubjectCreateRequest(BaseModel):
    subject_name: str
    subject_code: Optional[str] = None
    department:   Optional[str] = None
    faculty_id:   int


class SubjectResponse(BaseModel):
    id:            int
    subject_name:  str
    subject_code:  Optional[str] = None
    department:    Optional[str] = None
    faculty_id:    int
    faculty_name:  Optional[str] = None
    faculty_names: Optional[List[str]] = None

    class Config:
        from_attributes = True


class FacultyDetailResponse(BaseModel):
    id:         int
    name:       str
    email:      str
    department: Optional[str] = None
    subjects:   List[SubjectResponse] = []

    class Config:
        from_attributes = True
