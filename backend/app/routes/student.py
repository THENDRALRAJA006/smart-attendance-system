# ============================================================
# SmartAttend — Student Routes (v11 Enhanced Analytics)
# All endpoints use efficient aggregate SQL — no N+1 queries.
#
# GET /student/dashboard       — Enhanced with today_schedule, quick_stats
# GET /student/subjects        — Per-subject stats list
# GET /student/subject/{id}    — Full class-by-class detail
# GET /student/missed          — All absent records
# GET /student/history         — Filterable history (6 periods + custom)
# GET /student/analytics       — Semester summary
# GET /student/monthly         — Month-by-month breakdown
# GET /student/attendance-history — Legacy alias (kept for compatibility)
# ============================================================

import logging
from datetime import date, datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, case, and_, extract
from sqlalchemy.orm import Session, joinedload

from app.core.database import get_db
from app.core.dependencies import get_current_student
from app.models.models import (
    Student, Attendance, Subject, Classroom,
    Faculty, FaceEmbedding, Session as AttSession,
    FacultySubject, WeeklyTimetableSlot, ErpDepartment,
)

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Student"])


# ─── Helpers ─────────────────────────────────────────────────

def _semester_start() -> date:
    """Return start of the current academic semester (Jan or Jul)."""
    today = date.today()
    return date(today.year, 1, 1) if today.month <= 6 else date(today.year, 7, 1)


def _status_label(pct: float) -> str:
    if pct >= 90:
        return "Excellent"
    if pct >= 75:
        return "Good"
    if pct >= 60:
        return "Warning"
    return "Critical"


def _subject_stats_query(db: Session, student_id: int, start: Optional[date] = None):
    """
    Aggregate query: per-subject present / total counts for a student.
    Returns list of Row(subject_id, subject_name, subject_code,
                        faculty_id, faculty_name, department,
                        total, present).
    """
    q = (
        db.query(
            Subject.id.label("subject_id"),
            Subject.subject_name,
            Subject.subject_code,
            Subject.department,
            Faculty.id.label("faculty_id"),
            Faculty.name.label("faculty_name"),
            func.count(Attendance.id).label("total"),
            func.sum(
                case((Attendance.status == "present", 1), else_=0)
            ).label("present"),
        )
        .join(Attendance, Attendance.subject_id == Subject.id)
        .outerjoin(Faculty, Subject.faculty_id == Faculty.id)
        .filter(Attendance.student_id == student_id)
    )
    if start:
        q = q.filter(Attendance.date >= start)
    q = q.group_by(
        Subject.id, Subject.subject_name, Subject.subject_code,
        Subject.department, Faculty.id, Faculty.name,
    )
    return q.all()


def _build_subject_entry(row) -> dict:
    total   = int(row.total or 0)
    present = int(row.present or 0)
    absent  = total - present
    pct     = round(present / total * 100, 2) if total > 0 else 0.0
    return {
        "subject_id":   row.subject_id,
        "subject_name": row.subject_name,
        "subject_code": row.subject_code,
        "department":   row.department,
        "faculty_id":   row.faculty_id,
        "faculty_name": row.faculty_name,
        "total":        total,
        "attended":     present,
        "absent":       absent,
        "percentage":   pct,
        "status_label": _status_label(pct),
    }


# ─── GET /student/dashboard ──────────────────────────────────

@router.get("/student/dashboard", operation_id="student_get_dashboard")
async def student_dashboard(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Enhanced student dashboard with subject analytics & today's schedule."""
    sid = current_student.id

    # ── Overall aggregates ──────────────────────────────────
    totals = (
        db.query(
            func.count(Attendance.id).label("total"),
            func.sum(case((Attendance.status == "present", 1), else_=0)).label("attended"),
        )
        .filter(Attendance.student_id == sid)
        .one()
    )
    total     = int(totals.total or 0)
    attended  = int(totals.attended or 0)
    pct       = round(attended / total * 100, 2) if total > 0 else 0.0

    # ── Subject-wise stats ──────────────────────────────────
    subject_rows = _subject_stats_query(db, sid)
    subject_wise = [_build_subject_entry(r) for r in subject_rows]

    # ── Recent history (last 5) ─────────────────────────────
    recent_rows = (
        db.query(
            Attendance, Subject.subject_name, Classroom.room_name,
            Faculty.name.label("faculty_name"),
        )
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .outerjoin(Faculty, Subject.faculty_id == Faculty.id)
        .filter(Attendance.student_id == sid)
        .order_by(Attendance.marked_at.desc())
        .limit(5)
        .all()
    )
    recent_history = [
        {
            "id":             r.Attendance.id,
            "student_id":     sid,
            "classroom_id":   r.Attendance.classroom_id,
            "classroom_name": r.room_name,
            "subject_id":     r.Attendance.subject_id,
            "subject_name":   r.subject_name,
            "faculty_name":   r.faculty_name,
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
        }
        for r in recent_rows
    ]

    # ── Today's schedule (from TimetableEntry — always shows) ──
    today_str = date.today()
    today_day = today_str.strftime("%A")   # "Monday", "Tuesday" …
    now_hm    = datetime.now().strftime("%H:%M")
    today_schedule = _build_today_schedule(db, current_student, today_str, today_day, now_hm)

    # ── Quick stats ─────────────────────────────────────────
    today_attended = (
        db.query(func.count(Attendance.id))
        .filter(Attendance.student_id == sid, Attendance.date == today_str)
        .scalar() or 0
    )
    week_start = today_str - timedelta(days=7)
    week_attended = (
        db.query(func.count(Attendance.id))
        .filter(
            Attendance.student_id == sid,
            Attendance.date >= week_start,
            Attendance.status == "present",
        )
        .scalar() or 0
    )
    month_start = today_str.replace(day=1)
    missed_month = (
        db.query(func.count(Attendance.id))
        .filter(
            Attendance.student_id == sid,
            Attendance.date >= month_start,
            Attendance.status != "present",
        )
        .scalar() or 0
    )

    # ── Face registration ───────────────────────────────────
    embedding_count = (
        db.query(FaceEmbedding)
        .filter(FaceEmbedding.student_id == sid)
        .count()
    )

    return {
        "student_id":   sid,
        "student_name": current_student.name,
        "reg_no":       current_student.reg_no,
        "department":   current_student.department,
        "year":         current_student.year,
        "section":      current_student.section,
        "email":        current_student.email,
        "face_registered":    embedding_count > 0,
        "face_embeddings":    embedding_count,
        "face_image_url":     current_student.face_image_url,
        "total_classes":          total,
        "attended_classes":       attended,
        "attendance_percentage":  pct,
        "subject_wise":           subject_wise,
        "recent_history":         recent_history,
        "today_schedule":         today_schedule,
        "quick_stats": {
            "today_classes":   int(today_attended),
            "week_attended":   int(week_attended),
            "missed_this_month": int(missed_month),
            "total_subjects":  len(subject_wise),
        },
    }


# ─── GET /student/today-schedule (lightweight poll) ─────────

@router.get("/student/today-schedule", operation_id="student_get_today_schedule")
async def student_today_schedule(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Lightweight endpoint for 30-second live polling of today's timetable + attendance."""
    today_str = date.today()
    today_day = today_str.strftime("%A")
    now_hm    = datetime.now().strftime("%H:%M")
    return {
        "today_schedule": _build_today_schedule(db, current_student, today_str, today_day, now_hm),
        "today_day": today_day,
        "now": now_hm,
    }


def _build_today_schedule(
    db: Session,
    student: Student,
    today: date,
    today_day: str,
    now_hm: str,
) -> list:
    """
    Build today's timetable from TimetableEntry DB.
    For each entry, check if a live/closed session ran today and get
    the student's attendance status.
    Returns a list of schedule dicts compatible with TodayScheduleEntry Flutter model.
    """
    # 1. Fetch timetable entries for student's class today from WeeklyTimetableSlot
    dept = db.query(ErpDepartment).filter(
        (ErpDepartment.short_name == student.department) |
        (ErpDepartment.name == student.department)
    ).first()
    dept_id = dept.id if dept else 1

    slots = (
        db.query(WeeklyTimetableSlot)
        .filter(
            WeeklyTimetableSlot.department_id == dept_id,
            WeeklyTimetableSlot.year == student.year,
            WeeklyTimetableSlot.section == student.section,
            WeeklyTimetableSlot.day_of_week == today_day,
            WeeklyTimetableSlot.is_active == True,
            WeeklyTimetableSlot.class_type.notin_(["Break", "Lunch", "Free"]),
        )
        .all()
    )

    if not slots:
        return []

    # 2. Fetch all sessions for today for this student's class
    today_sessions = (
        db.query(AttSession)
        .filter(
            func.date(AttSession.start_time) == today,
            AttSession.department == student.department,
            AttSession.year == student.year,
            AttSession.section == student.section,
        )
        .all()
    )

    # Map: subject_id → session (prefer active, then most recent)
    session_map: dict = {}
    for s in today_sessions:
        if s.subject_id not in session_map or s.is_active:
            session_map[s.subject_id] = s

    # 3. Fetch attendance records for today for this student
    session_ids = [s.id for s in today_sessions]
    att_map: dict = {}   # session_id → status
    if session_ids:
        att_rows = (
            db.query(Attendance.session_id, Attendance.status)
            .filter(
                Attendance.student_id == student.id,
                Attendance.session_id.in_(session_ids),
            )
            .all()
        )
        for row in att_rows:
            att_map[row.session_id] = row.status

    result = []
    for s in slots:
        start = s.period_timing.start_time if s.period_timing else "00:00"
        end   = s.period_timing.end_time if s.period_timing else "23:59"
        is_current = (start <= now_hm <= end)

        session = session_map.get(s.erp_subject_id) if s.erp_subject_id else None
        session_id = session.id if session else 0
        is_active  = session.is_active if session else False

        att_status = att_map.get(session_id) if session else None
        if att_status is None:
            if is_current and is_active:
                att_status = "upcoming"
            elif is_current:
                att_status = "upcoming"
            elif now_hm > end:
                att_status = "not_marked"
            else:
                att_status = "upcoming"

        subject_name = s.erp_subject.subject_name if s.erp_subject else "Unknown Subject"
        subject_code = s.erp_subject.subject_code if s.erp_subject else None
        faculty_name = s.faculty.name if s.faculty else None
        classroom    = s.classroom.room_name if s.classroom else ""

        result.append({
            "id":             s.id,
            "period_number":  s.period_timing.order_index if s.period_timing else 1,
            "period_label":   s.period_timing.label if s.period_timing else f"Period {s.id}",
            "start_time":     start,
            "end_time":       end,
            "subject_id":     s.erp_subject_id,
            "subject_name":   subject_name,
            "subject_code":   subject_code,
            "faculty_name":   faculty_name,
            "room":           classroom,
            "class_type":     s.class_type,
            "is_current":     is_current,
            "session_active": is_active,
        })

    return result


# ─── GET /student/subjects ───────────────────────────────────

@router.get("/student/subjects", operation_id="student_get_subjects")
async def student_subjects(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Full subject list with per-subject attendance stats."""
    rows = _subject_stats_query(db, current_student.id)
    return [_build_subject_entry(r) for r in rows]


# ─── GET /student/subject/{subject_id} ───────────────────────

@router.get("/student/subject/{subject_id}", operation_id="student_get_subject_detail")
async def student_subject_detail(
    subject_id: int,
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """
    Subject detail: stats + full class-by-class attendance log
    sorted by date descending.
    """
    sid = current_student.id

    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if not subject:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Subject not found")

    faculty = (
        db.query(Faculty).filter(Faculty.id == subject.faculty_id).first()
        if subject.faculty_id else None
    )

    # Per-subject aggregate
    agg = (
        db.query(
            func.count(Attendance.id).label("total"),
            func.sum(case((Attendance.status == "present", 1), else_=0)).label("present"),
        )
        .filter(Attendance.student_id == sid, Attendance.subject_id == subject_id)
        .one()
    )
    total   = int(agg.total or 0)
    present = int(agg.present or 0)
    absent  = total - present
    pct     = round(present / total * 100, 2) if total > 0 else 0.0

    # Class-by-class log
    log_rows = (
        db.query(
            Attendance,
            Classroom.room_name,
            Faculty.name.label("faculty_name"),
        )
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .outerjoin(
            AttSession, Attendance.session_id == AttSession.id,
        )
        .outerjoin(Faculty, AttSession.faculty_id == Faculty.id)
        .filter(Attendance.student_id == sid, Attendance.subject_id == subject_id)
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

    class_log = [
        {
            "id":             r.Attendance.id,
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "classroom":      r.room_name,
            "faculty_name":   r.faculty_name,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
            "liveness_verified": r.Attendance.liveness_verified,
        }
        for r in log_rows
    ]

    return {
        "subject_id":    subject.id,
        "subject_name":  subject.subject_name,
        "subject_code":  subject.subject_code,
        "department":    subject.department,
        "faculty_id":    faculty.id if faculty else None,
        "faculty_name":  faculty.name if faculty else None,
        "total":         total,
        "attended":      present,
        "absent":        absent,
        "percentage":    pct,
        "status_label":  _status_label(pct),
        "class_log":     class_log,
    }


# ─── GET /student/missed ─────────────────────────────────────

@router.get("/student/missed", operation_id="student_get_missed")
async def student_missed(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """All absent/missed classes for the student."""
    rows = (
        db.query(
            Attendance,
            Subject.subject_name,
            Subject.subject_code,
            Classroom.room_name,
            Faculty.name.label("faculty_name"),
        )
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .outerjoin(
            AttSession, Attendance.session_id == AttSession.id,
        )
        .outerjoin(Faculty, AttSession.faculty_id == Faculty.id)
        .filter(
            Attendance.student_id == current_student.id,
            Attendance.status != "present",
        )
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )
    return [
        {
            "id":             r.Attendance.id,
            "subject_name":   r.subject_name,
            "subject_code":   r.subject_code,
            "classroom":      r.room_name,
            "faculty_name":   r.faculty_name,
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "status":         r.Attendance.status,
            "reason":         "Attendance Not Marked"
                              if r.Attendance.status == "absent"
                              else r.Attendance.status.replace("_", " ").title(),
        }
        for r in rows
    ]


# ─── GET /student/history ────────────────────────────────────

@router.get("/student/history", operation_id="student_get_history")
async def student_history(
    period: str = Query("month", description="today|yesterday|week|month|semester|all"),
    date_from: Optional[str] = Query(None, description="YYYY-MM-DD for custom range start"),
    date_to:   Optional[str] = Query(None, description="YYYY-MM-DD for custom range end"),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Enhanced filterable attendance history."""
    today = date.today()

    if date_from and date_to:
        start = datetime.strptime(date_from, "%Y-%m-%d").date()
        end   = datetime.strptime(date_to,   "%Y-%m-%d").date()
    elif period == "today":
        start = today
        end   = today
    elif period == "yesterday":
        start = today - timedelta(days=1)
        end   = today - timedelta(days=1)
    elif period == "week":
        start = today - timedelta(days=7)
        end   = today
    elif period == "month":
        start = today.replace(day=1)
        end   = today
    elif period == "semester":
        start = _semester_start()
        end   = today
    else:  # all
        start = date(2020, 1, 1)
        end   = today

    rows = (
        db.query(
            Attendance,
            Subject.subject_name,
            Subject.subject_code,
            Classroom.room_name,
            Faculty.name.label("faculty_name"),
        )
        .join(Subject, Attendance.subject_id == Subject.id)
        .join(Classroom, Attendance.classroom_id == Classroom.id)
        .outerjoin(
            AttSession, Attendance.session_id == AttSession.id,
        )
        .outerjoin(Faculty, AttSession.faculty_id == Faculty.id)
        .filter(
            Attendance.student_id == current_student.id,
            Attendance.date >= start,
            Attendance.date <= end,
        )
        .order_by(Attendance.date.desc(), Attendance.time.desc())
        .all()
    )

    return [
        {
            "id":             r.Attendance.id,
            "subject_name":   r.subject_name,
            "subject_code":   r.subject_code,
            "classroom":      r.room_name,
            "faculty_name":   r.faculty_name,
            "date":           r.Attendance.date.isoformat(),
            "time":           r.Attendance.time,
            "status":         r.Attendance.status,
            "rssi":           r.Attendance.rssi,
            "face_confidence": r.Attendance.face_confidence,
        }
        for r in rows
    ]


# ─── GET /student/analytics ──────────────────────────────────

@router.get("/student/analytics", operation_id="student_get_analytics")
async def student_analytics(
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Semester summary analytics."""
    sid  = current_student.id
    sem_start = _semester_start()
    today = date.today()

    # Overall semester stats
    sem_agg = (
        db.query(
            func.count(Attendance.id).label("total"),
            func.sum(case((Attendance.status == "present", 1), else_=0)).label("present"),
        )
        .filter(Attendance.student_id == sid, Attendance.date >= sem_start)
        .one()
    )
    sem_total   = int(sem_agg.total or 0)
    sem_present = int(sem_agg.present or 0)
    sem_absent  = sem_total - sem_present
    sem_pct     = round(sem_present / sem_total * 100, 2) if sem_total > 0 else 0.0

    # Per-subject for semester
    sub_rows = _subject_stats_query(db, sid, start=sem_start)
    subjects = [_build_subject_entry(r) for r in sub_rows]

    highest = max(subjects, key=lambda x: x["percentage"], default=None)
    lowest  = min(subjects, key=lambda x: x["percentage"], default=None)

    # Streak calculation
    att_dates = (
        db.query(Attendance.date)
        .filter(Attendance.student_id == sid, Attendance.status == "present")
        .order_by(Attendance.date.desc())
        .distinct()
        .all()
    )
    date_set = {r.date for r in att_dates}

    def calc_streak(from_date: date) -> int:
        count = 0
        check = from_date
        while check in date_set:
            count += 1
            check -= timedelta(days=1)
        return count

    current_streak = calc_streak(today)
    # Longest streak
    longest = 0
    if date_set:
        sorted_dates = sorted(date_set)
        run = 1
        for i in range(1, len(sorted_dates)):
            if (sorted_dates[i] - sorted_dates[i - 1]).days == 1:
                run += 1
                longest = max(longest, run)
            else:
                run = 1
        longest = max(longest, run)

    return {
        "semester_start":     sem_start.isoformat(),
        "total_classes":      sem_total,
        "total_present":      sem_present,
        "total_absent":       sem_absent,
        "overall_percentage": sem_pct,
        "status_label":       _status_label(sem_pct),
        "total_subjects":     len(subjects),
        "current_streak":     current_streak,
        "longest_streak":     longest,
        "highest_subject":    highest,
        "lowest_subject":     lowest,
        "subjects":           subjects,
    }


# ─── GET /student/monthly ────────────────────────────────────

@router.get("/student/monthly", operation_id="student_get_monthly")
async def student_monthly(
    year: int = Query(default=None, description="Year (defaults to current year)"),
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Month-by-month attendance breakdown for the given year."""
    if year is None:
        year = date.today().year
    sid = current_student.id

    rows = (
        db.query(
            extract("month", Attendance.date).label("month"),
            func.count(Attendance.id).label("total"),
            func.sum(case((Attendance.status == "present", 1), else_=0)).label("present"),
        )
        .filter(
            Attendance.student_id == sid,
            extract("year", Attendance.date) == year,
        )
        .group_by(extract("month", Attendance.date))
        .order_by(extract("month", Attendance.date))
        .all()
    )

    month_names = [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ]
    data_map = {int(r.month): r for r in rows}
    result = []
    for m in range(1, 13):
        r = data_map.get(m)
        if r:
            t = int(r.total or 0)
            p = int(r.present or 0)
            a = t - p
            pct = round(p / t * 100, 2) if t > 0 else 0.0
        else:
            t, p, a, pct = 0, 0, 0, 0.0
        result.append({
            "month":      m,
            "month_name": month_names[m - 1],
            "total":      t,
            "present":    p,
            "absent":     a,
            "percentage": pct,
        })
    return {"year": year, "months": result}


# ─── GET /student/attendance-history (legacy alias) ──────────

@router.get("/student/attendance-history", operation_id="student_get_attendance_history")
async def student_attendance_history(
    period: str = "monthly",
    current_student: Student = Depends(get_current_student),
    db: Session = Depends(get_db),
):
    """Legacy alias — calls the enhanced history endpoint internally."""
    # Map old period names to new ones
    mapping = {"daily": "today", "weekly": "week", "monthly": "month"}
    mapped = mapping.get(period, "month")
    return await student_history(
        period=mapped,
        date_from=None,
        date_to=None,
        current_student=current_student,
        db=db,
    )
