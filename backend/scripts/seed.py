#!/usr/bin/env python3
# ============================================================
# SmartAttend — Large-Scale Seed Script v2
# Seeds: 10 departments × 10 students = 100 students
#        10 faculty, 20 subjects, 10 classrooms
#        500+ realistic attendance records
# ============================================================

import os
import sys
import random
import string
from datetime import datetime, timedelta

sys.stdout.reconfigure(encoding="utf-8")
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.models import (
    Admin, Faculty, Student, Classroom, Subject,
    FacultySubject, Session as AttendanceSession, Attendance
)

# ─── Constants ──────────────────────────────────────────────
DEPARTMENTS = [
    "Computer Science and Engineering",
    "Artificial Intelligence and Machine Learning",
    "Electronics and Communication Engineering",
    "Mechanical Engineering",
    "Civil Engineering",
    "Electrical Engineering",
    "Information Technology",
    "Biomedical Engineering",
    "Chemical Engineering",
    "Aerospace Engineering",
]

DEPT_SHORT = {
    "Computer Science and Engineering": "CSE",
    "Artificial Intelligence and Machine Learning": "AIML",
    "Electronics and Communication Engineering": "ECE",
    "Mechanical Engineering": "MECH",
    "Civil Engineering": "CIVIL",
    "Electrical Engineering": "EEE",
    "Information Technology": "IT",
    "Biomedical Engineering": "BME",
    "Chemical Engineering": "CHEM",
    "Aerospace Engineering": "AERO",
}

SUBJECTS = [
    ("Data Structures and Algorithms", "CS301", "Computer Science and Engineering"),
    ("Operating Systems", "CS302", "Computer Science and Engineering"),
    ("Deep Learning", "AD301", "Artificial Intelligence and Machine Learning"),
    ("Computer Vision", "AD302", "Artificial Intelligence and Machine Learning"),
    ("Digital Signal Processing", "EC301", "Electronics and Communication Engineering"),
    ("VLSI Design", "EC302", "Electronics and Communication Engineering"),
    ("Thermodynamics", "ME301", "Mechanical Engineering"),
    ("Fluid Mechanics", "ME302", "Mechanical Engineering"),
    ("Structural Analysis", "CE301", "Civil Engineering"),
    ("Transportation Engineering", "CE302", "Civil Engineering"),
    ("Power Systems", "EE301", "Electrical Engineering"),
    ("Control Systems", "EE302", "Electrical Engineering"),
    ("Database Management Systems", "IT301", "Information Technology"),
    ("Web Technologies", "IT302", "Information Technology"),
    ("Biomedical Signal Processing", "BM301", "Biomedical Engineering"),
    ("Medical Imaging", "BM302", "Biomedical Engineering"),
    ("Process Control", "CH301", "Chemical Engineering"),
    ("Reaction Engineering", "CH302", "Chemical Engineering"),
    ("Aerodynamics", "AE301", "Aerospace Engineering"),
    ("Propulsion Systems", "AE302", "Aerospace Engineering"),
]

FACULTY_NAMES = [
    "Dr. Rajesh Kumar", "Dr. Priya Nair", "Dr. Arjun Sharma",
    "Dr. Meena Iyer", "Dr. Suresh Patel", "Dr. Kavitha Rajan",
    "Dr. Vikram Singh", "Dr. Ananya Das", "Dr. Mohan Babu", "Dr. Deepa Menon",
]

ROOM_NAMES = [
    "CSE Lab A", "ECE Lab B", "Seminar Hall 1", "Lecture Hall 201",
    "Lecture Hall 202", "Lecture Hall 301", "AIML Lab", "Mech Workshop",
    "Civil Drawing Hall", "Multipurpose Hall",
]

# BLE UUIDs — 10 unique classroom beacons
def gen_uuid():
    return "-".join([
        "".join(random.choices("0123456789abcdef", k=8)),
        "".join(random.choices("0123456789abcdef", k=4)),
        "".join(random.choices("0123456789abcdef", k=4)),
        "".join(random.choices("0123456789abcdef", k=4)),
        "".join(random.choices("0123456789abcdef", k=12)),
    ])

def random_reg_no(dept_short: str, index: int) -> str:
    return f"22{dept_short[:2].upper()}{index:04d}"

def random_email(name: str, index: int) -> str:
    clean = name.lower().replace(" ", "").replace(".", "")[:10]
    return f"{clean}{index}@college.edu.in"

def main():
    db = SessionLocal()
    try:
        print("=" * 60)
        print("SmartAttend — Seeding production data...")
        print("=" * 60)

        # ─── Admin ─────────────────────────────────────────
        existing_admin = db.query(Admin).filter(Admin.email == "admin@smartattend.com").first()
        if not existing_admin:
            admin = Admin(
                name="System Administrator",
                email="admin@smartattend.com",
                password_hash=hash_password("Admin@1234"),
            )
            db.add(admin)
            db.commit()
            print("✓ Admin created: admin@smartattend.com / Admin@1234")
        else:
            print("→ Admin already exists, skipping.")

        # ─── Classrooms ────────────────────────────────────
        classrooms = []
        for room_name in ROOM_NAMES:
            existing = db.query(Classroom).filter(Classroom.room_name == room_name).first()
            if not existing:
                classroom = Classroom(
                    room_name=room_name,
                    ble_uuid=gen_uuid(),
                    attendance_code="".join(random.choices(string.digits, k=6)),
                )
                db.add(classroom)
                db.commit()
                db.refresh(classroom)
                classrooms.append(classroom)
            else:
                classrooms.append(existing)
        print(f"✓ {len(classrooms)} classrooms ready")

        # ─── Faculty (10) ──────────────────────────────────
        faculty_list = []
        for i, (fname, dept) in enumerate(zip(FACULTY_NAMES, DEPARTMENTS)):
            email = random_email(fname.split("Dr. ")[-1], i + 1)
            existing = db.query(Faculty).filter(Faculty.email == email).first()
            if not existing:
                f = Faculty(
                    name=fname,
                    email=email,
                    password_hash=hash_password("Faculty@1234"),
                    department=dept,
                )
                db.add(f)
                db.commit()
                db.refresh(f)
                faculty_list.append(f)
            else:
                faculty_list.append(existing)
        print(f"✓ {len(faculty_list)} faculty ready")

        # ─── Subjects (20) ─────────────────────────────────
        subject_list = []
        for i, (sname, scode, sdept) in enumerate(SUBJECTS):
            existing = db.query(Subject).filter(Subject.subject_code == scode).first()
            faculty = faculty_list[i % len(faculty_list)]
            if not existing:
                s = Subject(
                    subject_name=sname,
                    subject_code=scode,
                    department=sdept,
                    faculty_id=faculty.id,
                )
                db.add(s)
                db.commit()
                db.refresh(s)
                subject_list.append(s)

                # Link to faculty via junction table
                link = FacultySubject(faculty_id=faculty.id, subject_id=s.id)
                db.add(link)
                db.commit()
            else:
                subject_list.append(existing)
        print(f"✓ {len(subject_list)} subjects ready")

        # ─── Students (100 = 10 per department) ────────────
        student_list = []
        student_first_names = [
            "Aakash", "Bhavana", "Charan", "Divya", "Elan", "Fathima",
            "Gowtham", "Haritha", "Ismail", "Jayanthi"
        ]
        student_last_names = [
            "Kumar", "Sharma", "Nair", "Patel", "Rajan", "Singh",
            "Das", "Iyer", "Rao", "Menon"
        ]

        global_idx = 1
        for dept_idx, dept in enumerate(DEPARTMENTS):
            dept_short = DEPT_SHORT[dept]
            for j in range(10):
                fname = student_first_names[j]
                lname = student_last_names[dept_idx % len(student_last_names)]
                full_name = f"{fname} {lname}"
                email = f"student{global_idx:03d}@college.edu.in"
                reg_no = random_reg_no(dept_short, global_idx)

                existing = db.query(Student).filter(Student.email == email).first()
                if not existing:
                    s = Student(
                        name=full_name,
                        reg_no=reg_no,
                        email=email,
                        password_hash=hash_password("Student@1234"),
                        department=dept,
                        year=random.randint(1, 4),
                        section=random.choice(["A", "B", "C"]),
                    )
                    db.add(s)
                    db.commit()
                    db.refresh(s)
                    # ⚠️ Store as plain dict — avoids SQLAlchemy lazy-load on expired session
                    student_list.append({"id": s.id, "department": s.department})
                else:
                    student_list.append({"id": existing.id, "department": existing.department})
                global_idx += 1

        print(f"✓ {len(student_list)} students ready")

        # Pre-build plain dicts for subjects/faculty/classrooms too
        subject_dicts = [
            {"id": s.id, "department": s.department}
            for s in subject_list
        ]
        faculty_ids = [f.id for f in faculty_list]
        classroom_dicts = [{"id": c.id} for c in classrooms]

        # ─── Attendance Sessions (50) ───────────────────────
        sessions_created = 0
        base_date = datetime.now() - timedelta(days=60)

        for day_offset in range(0, 60, 3):  # Every 3 days → 20 sessions
            session_date = base_date + timedelta(days=day_offset)
            sampled_subjects = random.sample(subject_dicts, min(3, len(subject_dicts)))

            for sub_dict in sampled_subjects:
                classroom_dict = random.choice(classroom_dicts)
                sub_idx = next(
                    (i for i, s in enumerate(subject_dicts) if s["id"] == sub_dict["id"]),
                    0
                )
                faculty_id = faculty_ids[sub_idx % len(faculty_ids)]

                existing_session = db.query(AttendanceSession).filter(
                    AttendanceSession.faculty_id == faculty_id,
                    AttendanceSession.subject_id == sub_dict["id"],
                    AttendanceSession.start_time >= session_date.replace(hour=0, minute=0),
                    AttendanceSession.start_time < session_date.replace(hour=23, minute=59),
                ).first()

                if not existing_session:
                    start_h = random.randint(8, 16)
                    session = AttendanceSession(
                        faculty_id=faculty_id,
                        classroom_id=classroom_dict["id"],
                        subject_id=sub_dict["id"],
                        attendance_code="".join(random.choices(string.digits, k=6)),
                        is_active=False,
                        start_time=session_date.replace(hour=start_h, minute=0),
                        end_time=session_date.replace(hour=start_h + 1, minute=0),
                    )
                    db.add(session)
                    db.commit()
                    db.refresh(session)
                    session_id = session.id

                    # Filter students by dept using plain dicts — no lazy load
                    dept_students = [
                        s for s in student_list
                        if s["department"] == sub_dict["department"]
                    ]
                    if not dept_students:
                        dept_students = random.sample(student_list, min(10, len(student_list)))

                    attend_count = int(len(dept_students) * random.uniform(0.7, 0.95))
                    attendees = random.sample(dept_students, min(attend_count, len(dept_students)))

                    for student_dict in attendees:
                        record = Attendance(
                            student_id=student_dict["id"],
                            session_id=session_id,
                            classroom_id=classroom_dict["id"],
                            subject_id=sub_dict["id"],
                            date=session_date.date(),
                            time=f"{start_h:02d}:{random.randint(0, 59):02d}",
                            status="present",
                            rssi=random.randint(-70, -40),
                            face_confidence=round(random.uniform(92.0, 99.9), 2),
                        )
                        db.add(record)

                    db.commit()
                    sessions_created += 1

        print(f"✓ {sessions_created} attendance sessions created with records")

        # ─── Summary ───────────────────────────────────────
        total_attendance = db.query(Attendance).count()
        print("\n" + "=" * 60)
        print("✅ Seed complete!")
        print(f"   Admins    : {db.query(Admin).count()}")
        print(f"   Faculty   : {db.query(Faculty).count()}")
        print(f"   Students  : {db.query(Student).count()}")
        print(f"   Subjects  : {db.query(Subject).count()}")
        print(f"   Classrooms: {db.query(Classroom).count()}")
        print(f"   Sessions  : {db.query(AttendanceSession).count()}")
        print(f"   Attendance: {total_attendance} records")
        print("=" * 60)
        print("\nTest credentials:")
        print("  Admin   : admin@smartattend.com / Admin@1234")
        print("  Faculty : rajeshkumar1@college.edu.in / Faculty@1234")
        print("  Student : student001@college.edu.in / Student@1234")

    except Exception as e:
        db.rollback()
        print(f"❌ Seed failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    main()
