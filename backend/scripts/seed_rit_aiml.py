"""
============================================================
SmartAttend — RIT AIML Production Seed Script
College  : Rajalakshmi Institute of Technology
Dept     : Artificial Intelligence & Machine Learning
Class    : III AIML C  |  Semester: V
============================================================
Run from project root:
  $env:DB_HOST="..."; $env:DB_PASSWORD="..."; python backend/scripts/seed_rit_aiml.py
"""

import sys, os, random, uuid, string
from datetime import date, time, datetime, timedelta

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.models.models import (
    Admin, Faculty, Student, Subject, Classroom,
    FacultySubject, Session as AttendanceSession, Attendance
)

db = SessionLocal()

# ─── Helpers ─────────────────────────────────────────────────

def rand_uuid():
    return str(uuid.uuid4()).upper()

def rand_token(n=8):
    return ''.join(random.choices(string.digits, k=n))

def upsert_admin(email, name, password):
    u = db.query(Admin).filter(Admin.email == email).first()
    if u:
        u.password_hash = hash_password(password)
        db.commit()
        print(f"  [UPDATED] Admin  : {email}")
    else:
        db.add(Admin(name=name, email=email, password_hash=hash_password(password)))
        db.commit()
        print(f"  [CREATED] Admin  : {email}")

def upsert_faculty(name, email, password, dept):
    u = db.query(Faculty).filter(Faculty.email == email).first()
    if u:
        u.name = name
        u.department = dept
        u.password_hash = hash_password(password)
        db.commit()
        return u
    f = Faculty(name=name, email=email,
                password_hash=hash_password(password), department=dept)
    db.add(f); db.commit(); db.refresh(f)
    print(f"  [CREATED] Faculty: {email}")
    return f

def upsert_subject(code, name, dept, faculty_id):
    u = db.query(Subject).filter(Subject.subject_code == code).first()
    if u:
        u.faculty_id = faculty_id
        db.commit()
        return u
    s = Subject(subject_name=name, subject_code=code,
                department=dept, faculty_id=faculty_id)
    db.add(s); db.commit(); db.refresh(s)
    print(f"  [CREATED] Subject: {code} — {name}")
    return s

def upsert_classroom(name):
    u = db.query(Classroom).filter(Classroom.room_name == name).first()
    if u:
        return u
    c = Classroom(room_name=name, ble_uuid=rand_uuid())
    db.add(c); db.commit(); db.refresh(c)
    print(f"  [CREATED] Classroom: {name}")
    return c

def upsert_student(reg_no, name, email, password, dept, year, section):
    u = db.query(Student).filter(Student.email == email).first()
    if u:
        u.password_hash = hash_password(password)
        db.commit()
        return u
    s = Student(name=name, reg_no=reg_no, email=email,
                password_hash=hash_password(password),
                department=dept, year=year, section=section)
    db.add(s); db.commit(); db.refresh(s)
    return s

# ─── 1. Admin ─────────────────────────────────────────────────
print("\n[1] Admin")
upsert_admin("admin@smartattend.com", "Super Admin RIT", "Admin@1234")

# ─── 2. Faculty ──────────────────────────────────────────────
print("\n[2] Faculty")
DEPT = "Artificial Intelligence and Machine Learning"
PWD  = "Faculty@123"

faculty_data = [
    ("Nikitha B",      "nikitha@smartattend.com"),
    ("Starlin M.A",    "starlin@smartattend.com"),
    ("Shree Mahesh K", "shreemahesh@smartattend.com"),
    ("Ramya M",        "ramya@smartattend.com"),
    ("Ajaypradeep N",  "ajaypradeep@smartattend.com"),
    ("C Subashini",    "subashini@smartattend.com"),
    ("Rajkumar V",     "rajkumar@smartattend.com"),
    ("Lizy A",         "lizy@smartattend.com"),
    ("Divya M",        "divya@smartattend.com"),
    ("Lavanya",        "lavanya@smartattend.com"),
]

faculty_map = {}  # name -> Faculty ORM object
for name, email in faculty_data:
    f = upsert_faculty(name, email, PWD, DEPT)
    faculty_map[name] = f

# ─── 3. Subjects ─────────────────────────────────────────────
print("\n[3] Subjects")

# Assign primary faculty_id (owner) — will also link via FacultySubject
subject_assignments = [
    ("AD23511", "Deep Learning",                             "Nikitha B"),
    ("CS23511", "Computer Networks",                         "Starlin M.A"),
    ("AL23531", "Natural Language Processing",               "Shree Mahesh K"),
    ("CB23531", "Business Analytics",                        "Ramya M"),
    ("MX23511", "Disaster Risk Reduction and Management",    "Ajaypradeep N"),
    ("AD23V12", "Big Data Analytics",                        "Rajkumar V"),
    ("AL23V11", "Exploratory Data Analysis",                 "Lizy A"),
    ("AD23IC3", "Tableau Data Visualization",                "Divya M"),
    ("AD23521", "Deep Learning Laboratory",                  "Nikitha B"),
    ("CS23521", "Computer Networks Laboratory",              "Starlin M.A"),
]

subject_map = {}  # code -> Subject ORM object
for code, name, faculty_name in subject_assignments:
    fac = faculty_map[faculty_name]
    s = upsert_subject(code, name, DEPT, fac.id)
    subject_map[code] = s

# ─── 4. Classrooms ───────────────────────────────────────────
print("\n[4] Classrooms")
classroom_names = [
    "CLASSROOM_A101",
    "CLASSROOM_A102",
    "LAB_DL",
    "LAB_CN",
    "LAB_NLP",
]
classroom_map = {}
for cn in classroom_names:
    classroom_map[cn] = upsert_classroom(cn)

# ─── 5. Faculty–Subject Links ────────────────────────────────
print("\n[5] Faculty–Subject Mapping")
fs_links = [
    ("Nikitha B",      "AD23511"),   # Deep Learning
    ("Starlin M.A",    "CS23511"),   # Computer Networks
    ("Rajkumar V",     "AD23V12"),   # Big Data Analytics
    ("Lizy A",         "AL23V11"),   # Exploratory Data Analysis
    ("Ramya M",        "CB23531"),   # Business Analytics
    ("Shree Mahesh K", "AL23531"),   # NLP
    ("Ajaypradeep N",  "MX23511"),   # Disaster Risk Reduction
    ("Divya M",        "AD23IC3"),   # Tableau
    ("Nikitha B",      "AD23521"),   # Deep Learning Lab
    ("Starlin M.A",    "CS23521"),   # Computer Networks Lab
]

for fname, scode in fs_links:
    fac  = faculty_map[fname]
    subj = subject_map[scode]
    exists = db.query(FacultySubject).filter(
        FacultySubject.faculty_id == fac.id,
        FacultySubject.subject_id == subj.id,
    ).first()
    if not exists:
        db.add(FacultySubject(faculty_id=fac.id, subject_id=subj.id))
        db.commit()
        print(f"  [LINKED] {fname} -> {scode}")

# ─── 6. Students ─────────────────────────────────────────────
print("\n[6] Students (112)")
students = []
for i in range(1, 113):
    reg_no  = f"AIML{i:03d}"
    name    = f"Student {i:03d}"
    email   = f"aiml{i:03d}@smartattend.com"
    s = upsert_student(reg_no, name, email, "Student@123", DEPT, 3, "C")
    students.append(s)
print(f"  Done — {len(students)} students")

# ─── 7. Attendance Sessions ──────────────────────────────────
print("\n[7] Attendance Sessions (10)")

session_specs = [
    # (subject_code, faculty_name, classroom, date_offset_days)
    ("AD23511", "Nikitha B",      "CLASSROOM_A101", 0),
    ("CS23511", "Starlin M.A",    "CLASSROOM_A102", 1),
    ("AL23531", "Shree Mahesh K", "CLASSROOM_A101", 2),
    ("CB23531", "Ramya M",        "CLASSROOM_A102", 3),
    ("MX23511", "Ajaypradeep N",  "CLASSROOM_A101", 4),
    ("AD23V12", "Rajkumar V",     "CLASSROOM_A102", 5),
    ("AL23V11", "Lizy A",         "CLASSROOM_A101", 6),
    ("AD23IC3", "Divya M",        "CLASSROOM_A102", 7),
    ("AD23521", "Nikitha B",      "LAB_DL",         8),
    ("CS23521", "Starlin M.A",    "LAB_CN",         9),
]

base_date = date(2026, 6, 10)
sessions_created = []

for scode, fname, cname, offset in session_specs:
    subj      = subject_map[scode]
    fac       = faculty_map[fname]
    classroom = classroom_map[cname]
    sess_date = base_date + timedelta(days=offset)

    # Check if session already exists for this subject + faculty + date
    existing = db.query(AttendanceSession).filter(
        AttendanceSession.subject_id  == subj.id,
        AttendanceSession.faculty_id  == fac.id,
        AttendanceSession.classroom_id == classroom.id,
    ).first()

    if existing:
        sessions_created.append(existing)
        continue

    sess = AttendanceSession(
        classroom_id    = classroom.id,
        subject_id      = subj.id,
        faculty_id      = fac.id,
        attendance_code = rand_token(6),
        start_time      = datetime.combine(sess_date, time(9, 0)),
        end_time        = datetime.combine(sess_date, time(10, 0)),
        is_active       = False,
    )
    db.add(sess); db.commit(); db.refresh(sess)
    sessions_created.append(sess)
    print(f"  [SESSION] {sess_date} {scode} — {fname} @ {cname}")

print(f"  Total sessions: {len(sessions_created)}")

# ─── 8. Attendance Records ───────────────────────────────────
print("\n[8] Attendance Records (112 students × 10 sessions, 85–100%)")

inserted = 0
for student in students:
    # Each student attends 85–100% of sessions
    attendance_pct = random.uniform(0.85, 1.0)
    attended_sessions = random.sample(
        sessions_created,
        k=round(len(sessions_created) * attendance_pct)
    )

    for sess in attended_sessions:
        exists = db.query(Attendance).filter(
            Attendance.student_id  == student.id,
            Attendance.session_id  == sess.id,
        ).first()
        if exists:
            continue

        att_time = sess.start_time + timedelta(minutes=random.randint(0, 20))
        rssi_val = random.randint(-69, -45)

        rec = Attendance(
            student_id   = student.id,
            classroom_id = sess.classroom_id,
            subject_id   = sess.subject_id,
            session_id   = sess.id,
            date         = sess.start_time.date(),
            time         = att_time.time(),
            status       = "present",
            rssi         = rssi_val,
        )
        db.add(rec)
        inserted += 1

    if inserted % 200 == 0 and inserted > 0:
        db.commit()

db.commit()
print(f"  Inserted {inserted} attendance records")

# ─── 9. Summary ──────────────────────────────────────────────
print("\n" + "=" * 60)
print("SEED COMPLETE — RIT AIML III C / Semester V")
print("=" * 60)
print(f"  Admins    : {db.query(Admin).count()}")
print(f"  Faculty   : {db.query(Faculty).count()}")
print(f"  Subjects  : {db.query(Subject).count()}")
print(f"  Classrooms: {db.query(Classroom).count()}")
print(f"  Students  : {db.query(Student).count()}")
print(f"  Sessions  : {db.query(AttendanceSession).count()}")
print(f"  Attendance: {db.query(Attendance).count()}")
print()
print("LOGIN CREDENTIALS")
print("-" * 60)
print("  ADMIN")
print("    admin@smartattend.com  / Admin@1234")
print()
print("  FACULTY  (all use password: Faculty@123)")
for name, email in faculty_data:
    print(f"    {email:<35s} {name}")
print()
print("  STUDENTS  (all use password: Student@123)")
print("    aiml001@smartattend.com  ..  aiml112@smartattend.com")
print("=" * 60)

db.close()
