# ============================================================
# SmartAttend — CRUD Package Init
# ============================================================

from .crud import (
    # Students
    get_student_by_id, get_student_by_email, get_student_by_reg_no,
    get_students, create_student, update_student_face, delete_student,
    # Faculty
    get_faculty_by_id, get_faculty_by_email, get_all_faculty,
    create_faculty, delete_faculty, get_faculty_subjects,
    # Admin
    get_admin_by_email, get_admin_by_id,
    # Classrooms
    get_all_classrooms, get_classroom_by_id, get_classroom_by_name,
    create_classroom, delete_classroom,
    # Subjects
    get_all_subjects, get_subject_by_id, create_subject, link_faculty_subject,
    # Sessions
    get_session_by_id, get_active_session_for_classroom,
    create_session, end_session,
    # Attendance
    get_student_attendance, get_student_attendance_by_period,
    get_duplicate_attendance, create_attendance_record, get_session_attendance,
    # Analytics
    get_system_stats, get_low_attendance_students,
    # BLE Beacons
    get_all_ble_beacons, get_beacon_by_id, get_beacon_by_classroom,
    create_ble_beacon, delete_ble_beacon,
    # Face Profiles
    get_face_profile, upsert_face_profile,
)
