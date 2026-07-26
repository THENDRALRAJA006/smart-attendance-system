# ============================================================
# SmartAttend — RIT Official Timetable Seeder Script
# Seeds 2026-27 ODD Semester Timetable for III AIM&ML - C (Venue A308)
# ============================================================

import sys
import os

# Add parent dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal, engine
from app.models.models import (
    Base, Faculty, Classroom, ErpDepartment, ErpSubject,
    PeriodTiming, WeeklyTimetableSlot, Subject
)
from app.core.security import hash_password

def seed_timetable():
    print("[+] Starting RIT Timetable Seeding...")
    db = SessionLocal()
    try:
        # 1. Department: CSE (AI & ML)
        dept = db.query(ErpDepartment).filter(
            (ErpDepartment.short_name == "AI&ML") | (ErpDepartment.name.like("%Machine Learning%"))
        ).first()

        if not dept:
            dept = ErpDepartment(
                name="Artificial Intelligence and Machine Learning",
                short_name="AI&ML",
                code="AIML",
                is_active=True
            )
            db.add(dept)
            db.commit()
            db.refresh(dept)
            print(f"[OK] Created Department: {dept.name} (ID: {dept.id})")
        else:
            print(f"[INFO] Found Existing Department: {dept.name} (ID: {dept.id})")

        # 2. Classroom: A308
        room = db.query(Classroom).filter(Classroom.room_name == "A308").first()
        if not room:
            room = Classroom(
                room_name="A308",
                ble_uuid="00001801-0000-1000-8000-00805f9b34fb"
            )
            db.add(room)
            db.commit()
            db.refresh(room)
            print(f"[OK] Created Classroom A308 (ID: {room.id})")
        else:
            print(f"[INFO] Found Existing Classroom A308 (ID: {room.id})")

        # 3. Period Timings (P1 to P7 + Break + Lunch)
        timings_def = [
            (1, "Period 1", "08:00", "08:50", False),
            (2, "Period 2", "08:50", "09:40", False),
            (3, "Break",    "09:40", "10:10", True),
            (4, "Period 3", "10:10", "11:00", False),
            (5, "Period 4", "11:00", "11:50", False),
            (6, "Period 5", "11:50", "12:40", False),
            (7, "Lunch",    "12:40", "13:30", True),
            (8, "Period 6", "13:30", "14:15", False),
            (9, "Period 7", "14:15", "15:00", False),
        ]

        period_map = {}
        for order, label, start, end, is_break in timings_def:
            pt = db.query(PeriodTiming).filter(PeriodTiming.order_index == order).first()
            if not pt:
                pt = PeriodTiming(
                    label=label,
                    start_time=start,
                    end_time=end,
                    order_index=order,
                    is_break=is_break
                )
                db.add(pt)
            else:
                pt.label = label
                pt.start_time = start
                pt.end_time = end
                pt.is_break = is_break
        db.commit()

        # Re-fetch for map
        for pt in db.query(PeriodTiming).all():
            period_map[pt.label] = pt
        print(f"[OK] Period Timings Configured: {len(period_map)} periods", flush=True)

        # 4. Faculty Members
        faculty_def = [
            ("Ms. Nikitha B", "nikitha.b@ritchennai.edu.in", "AI&DS"),
            ("Mrs. Starlin M.A", "starlin.ma@ritchennai.edu.in", "AI&ML"),
            ("Mr. Shree Mahesh K", "shreemahesh.k@ritchennai.edu.in", "AI&ML"),
            ("Ms. S. Pandima Devi", "pandimadevi.s@ritchennai.edu.in", "AI&DS"),
            ("Dr. C. Subashini", "subashini.c@ritchennai.edu.in", "Chemistry"),
            ("Mr. Joel", "joel@ritchennai.edu.in", "AI&DS"),
            ("Mrs. Lizy A", "lizy.a@ritchennai.edu.in", "AI&ML"),
            ("Mr. Ajaypradeep N", "ajaypradeep.n@ritchennai.edu.in", "AI&ML"),
            ("Mrs. Divya M", "divya.m@ritchennai.edu.in", "AI&DS"),
        ]

        faculty_map = {}
        default_pwd_hash = hash_password("Password123!")

        for name, email, department in faculty_def:
            f = db.query(Faculty).filter(Faculty.email == email).first()
            if not f:
                f = Faculty(
                    name=name,
                    email=email,
                    department=department,
                    password_hash=default_pwd_hash,
                    is_active=True
                )
                db.add(f)
                print(f"   + Added Faculty: {name} ({email})", flush=True)
            faculty_map[name] = f
        db.commit()

        # Re-fetch all faculty
        for f in db.query(Faculty).all():
            faculty_map[f.name] = f
        print(f"[OK] Faculty Members Configured: {len(faculty_map)} members", flush=True)

        # 5. ERP Subjects
        subjects_def = [
            ("AD23511", "Deep Learning", 3, "Theory"),
            ("CS23511", "Computer Networks", 3, "Theory"),
            ("AL23531", "Natural Language Processing", 3, "Theory"),
            ("CB23531", "Business Analytics", 3, "Theory"),
            ("MX23511", "Disaster Risk Reduction and Management", 3, "Theory"),
            ("AD23V12", "Big Data Analytics", 3, "Theory"),
            ("AL23V11", "Exploratory Data Analysis", 3, "Theory"),
            ("AD23IC3", "Tableau - Data Visualization", 2, "Theory"),
            ("AD23521", "Deep Learning Laboratory", 2, "Lab"),
            ("CS23521", "Computer Networks Laboratory", 2, "Lab"),
            ("MENTOR",  "Mentoring", 0, "Tutorial"),
            ("PLACE",   "Placement", 0, "Tutorial"),
            ("NPTEL",   "NPTEL", 0, "Elective"),
        ]

        subject_map = {}
        for code, name, credits, type_ in subjects_def:
            s = db.query(ErpSubject).filter(
                ErpSubject.department_id == dept.id,
                ErpSubject.subject_name == name
            ).first()
            if not s:
                s = ErpSubject(
                    department_id=dept.id,
                    subject_name=name,
                    subject_code=code,
                    credits=credits,
                    subject_type=type_,
                    year=3,
                    is_active=True
                )
                db.add(s)
            subject_map[code] = s
            subject_map[name] = s
        db.commit()

        for s in db.query(ErpSubject).filter(ErpSubject.department_id == dept.id).all():
            subject_map[s.subject_code] = s
            subject_map[s.subject_name] = s

        print(f"[OK] ERP Subjects Configured: {len(subjects_def)} subjects", flush=True)

        # 6. Weekly Timetable Slots Configuration
        # (Day, Period Label, Subject Code/Name, Faculty Name, Class Type)
        schedule = [
            # Monday
            ("Monday", "Period 1", "AD23V12", "Mr. Joel", "Theory"),
            ("Monday", "Period 2", "AL23531", "Mr. Shree Mahesh K", "Theory"),
            ("Monday", "Break",    None,      None, "Break"),
            ("Monday", "Period 3", "AD23511", "Ms. Nikitha B", "Theory"),
            ("Monday", "Period 4", "AD23V12", "Mr. Joel", "Theory"),
            ("Monday", "Period 5", "MENTOR",  "Mrs. Starlin M.A", "Tutorial"),
            ("Monday", "Lunch",    None,      None, "Lunch"),
            ("Monday", "Period 6", "CS23511", "Mrs. Starlin M.A", "Theory"),
            ("Monday", "Period 7", "CB23531", "Ms. S. Pandima Devi", "Theory"),

            # Tuesday
            ("Tuesday", "Period 1", "AD23511", "Ms. Nikitha B", "Theory"),
            ("Tuesday", "Period 2", "CS23511", "Mrs. Starlin M.A", "Theory"),
            ("Tuesday", "Break",    None,      None, "Break"),
            ("Tuesday", "Period 3", "AD23V12", "Mr. Joel", "Theory"),
            ("Tuesday", "Period 4", "AD23521", "Ms. Nikitha B", "Lab"),
            ("Tuesday", "Period 5", "AD23521", "Ms. Nikitha B", "Lab"),
            ("Tuesday", "Lunch",    None,      None, "Lunch"),
            ("Tuesday", "Period 6", "CB23531", "Ms. S. Pandima Devi", "Theory"),
            ("Tuesday", "Period 7", "AL23V11", "Mrs. Lizy A", "Theory"),

            # Wednesday
            ("Wednesday", "Period 1", "AL23531", "Mr. Shree Mahesh K", "Theory"),
            ("Wednesday", "Period 2", "CB23531", "Ms. S. Pandima Devi", "Theory"),
            ("Wednesday", "Break",    None,      None, "Break"),
            ("Wednesday", "Period 3", "AD23511", "Ms. Nikitha B", "Theory"),
            ("Wednesday", "Period 4", "PLACE",   None, "Tutorial"),
            ("Wednesday", "Period 5", "AL23531", "Mr. Shree Mahesh K", "Theory"),
            ("Wednesday", "Lunch",    None,      None, "Lunch"),
            ("Wednesday", "Period 6", "CS23521", "Mrs. Starlin M.A", "Lab"),
            ("Wednesday", "Period 7", "CB23531", "Ms. S. Pandima Devi", "Lab"),

            # Thursday
            ("Thursday", "Period 1", "AD23V12", "Mr. Joel", "Theory"),
            ("Thursday", "Period 2", "AL23V11", "Mrs. Lizy A", "Theory"),
            ("Thursday", "Break",    None,      None, "Break"),
            ("Thursday", "Period 3", "CS23511", "Mrs. Starlin M.A", "Theory"),
            ("Thursday", "Period 4", "AL23V11", "Mrs. Lizy A", "Theory"),
            ("Thursday", "Period 5", "NPTEL",   "Mr. Joel", "Elective"),
            ("Thursday", "Lunch",    None,      None, "Lunch"),
            ("Thursday", "Period 6", "AD23511", "Ms. Nikitha B", "Theory"),
            ("Thursday", "Period 7", "AL23531", "Mr. Shree Mahesh K", "Theory"),

            # Friday
            ("Friday", "Period 1", "CB23531", "Ms. S. Pandima Devi", "Theory"),
            ("Friday", "Period 2", "AL23V11", "Mrs. Lizy A", "Theory"),
            ("Friday", "Break",    None,      None, "Break"),
            ("Friday", "Period 3", "CS23511", "Mrs. Starlin M.A", "Theory"),
            ("Friday", "Period 4", "AL23531", "Ms. S. Pandima Devi", "Lab"),
            ("Friday", "Period 5", "AL23531", "Ms. S. Pandima Devi", "Lab"),
            ("Friday", "Lunch",    None,      None, "Lunch"),
            ("Friday", "Period 6", "AD23511", "Ms. Nikitha B", "Theory"),
            ("Friday", "Period 7", "AL23531", "Mr. Shree Mahesh K", "Theory"),
        ]

        # Clear existing slots for Section C Year 3 Dept
        db.query(WeeklyTimetableSlot).filter(
            WeeklyTimetableSlot.department_id == dept.id,
            WeeklyTimetableSlot.year == 3,
            WeeklyTimetableSlot.section == "C"
        ).delete(synchronize_session=False)
        db.commit()

        slots_created = 0
        for day, period_label, subj_code, fac_name, class_type in schedule:
            pt = period_map.get(period_label)
            if not pt:
                continue

            sub = subject_map.get(subj_code) if subj_code else None
            fac = faculty_map.get(fac_name) if fac_name else None

            slot = WeeklyTimetableSlot(
                department_id=dept.id,
                year=3,
                section="C",
                day_of_week=day,
                period_timing_id=pt.id,
                erp_subject_id=sub.id if sub else None,
                faculty_id=fac.id if fac else None,
                classroom_id=room.id,
                class_type=class_type,
                academic_year="2026-2027",
                semester=5,
                is_active=True
            )
            db.add(slot)
            slots_created += 1

        db.commit()
        print(f"[SUCCESS] Successfully Seeded {slots_created} Timetable Slots for III AIM&ML - C (Venue: A308)!")

    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error Seeding Timetable: {e}")
        import traceback
        traceback.print_exc()
    finally:
        db.close()

if __name__ == "__main__":
    seed_timetable()
