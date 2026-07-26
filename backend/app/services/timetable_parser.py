# ============================================================
# SmartAttend — Timetable Parser (v13 — RIT Indian College Layout)
#
# Converts OCR output → structured timetable entries.
#
# Priority order:
#   1. _parse_rit_layout()     — Indian college split-table format
#      (Left table = course list, Right table = weekly period grid)
#   2. _parse_grid_entries()   — Generic row-per-day / col-per-day grid
#   3. _parse_linear_entries() — Linear fallback (day headers in text)
#
# Indian college timetable format (e.g. RIT):
#   Right-side grid:
#     Row 0: Period numbers  (1, 2, BREAK, 3, 4, LUNCH, 5, 6, 7)
#     Row 1: Time slots      (8:00-8:50, 8:50-9:40, …, 2:15-3:00)
#     Rows 2-7: Day rows     (Monday → Saturday)
#     Cells: subject codes   (BDA-AD23V12, NLP-AL23531, …)
#   Left-side table:
#     SL.No | Code | Course Name | Course Name | Faculty In-Charge
#     Used to build code→subject + code→faculty dictionaries
# ============================================================

import logging
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any, Dict, List, Optional, Tuple

from sqlalchemy.orm import Session as DbSession

logger = logging.getLogger(__name__)

# ── Optional rapidfuzz for fuzzy matching ──────────────────
try:
    from rapidfuzz import fuzz, process as rfuzz_process
    _FUZZY = True
except ImportError:
    _FUZZY = False
    logger.warning("rapidfuzz not installed — using basic string matching")


# ═══════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════

@dataclass
class ConfidenceField:
    value: Optional[str]
    confidence: float   # 0.0–1.0


@dataclass
class ParsedEntry:
    """One timetable slot as parsed by the AI parser."""
    department: str
    year: int
    section: str
    semester: Optional[int]
    academic_year: Optional[str]
    effective_date: Optional[date]
    day_of_week: str
    period_number: int
    start_time: str          # HH:MM
    end_time: str

    subject_name_raw: Optional[str]
    subject_code_raw: Optional[str]
    faculty_name_raw: Optional[str]
    room_raw: Optional[str]
    class_type: str          # Theory | Lab | Break | Lunch | etc.
    credits: Optional[int]

    # Resolved DB IDs (set during auto-link step)
    subject_id: Optional[int] = None
    faculty_id: Optional[int] = None
    classroom_id: Optional[int] = None

    # Per-entry confidence (average of field confidences)
    ocr_confidence: float = 1.0


@dataclass
class ParsedTimetable:
    """Full parsed result for one uploaded timetable."""
    entries: List[ParsedEntry]
    department: Optional[str]
    year: Optional[int]
    section: Optional[str]
    semester: Optional[int]
    academic_year: Optional[str]
    effective_date: Optional[date]
    validation_errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    ocr_engine: str = "unknown"


# ═══════════════════════════════════════════════════════════
# Constants
# ═══════════════════════════════════════════════════════════

DAYS_OF_WEEK = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
DAY_ALIASES = {
    "mon": "Monday", "tue": "Tuesday", "wed": "Wednesday",
    "thu": "Thursday", "fri": "Friday", "sat": "Saturday", "sun": "Sunday",
}

# Standard Indian college timetable time slots
# RIT format: 8 periods per day with break & lunch
STANDARD_TIME_SLOTS = [
    ("08:00", "08:50"),   # Period 1
    ("08:50", "09:40"),   # Period 2
    ("09:40", "10:10"),   # Break (skip)
    ("10:10", "11:00"),   # Period 3
    ("11:00", "11:50"),   # Period 4
    ("11:50", "12:40"),   # Lunch (skip)
    ("12:40", "13:30"),   # Period 5 (1:30 PM)
    ("13:30", "14:15"),   # Period 6 (2:15 PM)
    ("14:15", "15:00"),   # Period 7 (3:00 PM)
]

# Subject abbreviation expansion
SUBJECT_ABBREVIATIONS = {
    "DL": "Deep Learning",
    "CN": "Computer Networks",
    "AI": "Artificial Intelligence",
    "ML": "Machine Learning",
    "DS": "Data Structures",
    "OS": "Operating Systems",
    "DBMS": "Database Management Systems",
    "SE": "Software Engineering",
    "NLP": "Natural Language Processing",
    "CV": "Computer Vision",
    "TOC": "Theory of Computation",
    "CD": "Compiler Design",
    "COA": "Computer Organization & Architecture",
    "BDA": "Big Data Analytics",
    "BA": "Business Analytics",
    "DR": "Disaster Risk Reduction",
}

NON_TEACHING_KEYWORDS = {
    "break": "Break",
    "lunch": "Lunch",
    "free": "Free",
    "recess": "Break",
    "short break": "Break",
    "tea": "Break",
    "mentoring": "Mentoring",
    "mentor": "Mentoring",
    "placement": "Placement",
    "nptel": "NPTEL",
    "library": "Free",
    "sports": "Free",
}

# Regex for time patterns (08:00, 8:00 AM, 08.00)
TIME_RE = re.compile(r"\b(\d{1,2})[:.h](\d{2})\s*(am|pm)?\b", re.IGNORECASE)

# Subject code patterns — matches codes like:
#   AD23511, CS301, 21CS501, BDA-AD23V12, NLP-AL23531, CN-CS23531
SUBJECT_CODE_RE = re.compile(
    r"\b([A-Z]{1,4}\d{2,3}[A-Z]?\d{1,4}|[A-Z0-9]{6,10})\b"
)

# RIT-specific cell code: prefix-code like BDA-AD23V12 or NLP-AL23531
RIT_CELL_CODE_RE = re.compile(
    r"\b([A-Z]{1,5})[- ]([A-Z]{1,3}\d{2,3}[A-Z]?\d{1,4})\b",
    re.IGNORECASE
)

# Credits regex
CREDITS_RE = re.compile(r"\b(\d)\s*cr(?:edit)?s?\b", re.IGNORECASE)

# Lab detection
LAB_RE = re.compile(r"\blab\b|\bpractical\b|\bprac\b", re.IGNORECASE)


# ═══════════════════════════════════════════════════════════
# Main Parser Entry Point
# ═══════════════════════════════════════════════════════════

def parse_timetable(
    ocr_result,                  # OcrResult from ocr_service
    db: DbSession,
    department: str = "",
    year: int = 1,
    section: str = "A",
    semester: Optional[int] = None,
    academic_year: Optional[str] = None,
    effective_date: Optional[date] = None,
    course_dict: Optional[Dict[str, str]] = None,
    faculty_dict: Optional[Dict[str, str]] = None,
) -> ParsedTimetable:
    """
    Main Document Layout Analysis Entry Point.

    Priority:
    1. RIT Indian college split-table layout
    2. Generic grid (row-per-day or col-per-day)
    3. Linear fallback

    Merges with course_dict & faculty_dict from legend tables.
    """
    raw_text = ocr_result.raw_text
    lines = ocr_result.lines

    # ── Step 1: Extract metadata ─────────────────────────────
    meta = _extract_metadata(raw_text)
    dept      = meta.get("department") or department
    yr        = meta.get("year") or year
    sec       = meta.get("section") or section
    sem       = meta.get("semester") or semester
    acad_year = meta.get("academic_year") or academic_year
    eff_date  = meta.get("effective_date") or effective_date

    logger.info(f"[PARSER] Meta: dept={dept} yr={yr} sec={sec} sem={sem}")
    logger.info(f"[PARSER] OCR lines count: {len(lines)}, raw_text length: {len(raw_text)}")

    # ── Step 2: Detect grid ──────────────────────────────────
    grid = _detect_grid(lines)

    # ── Step 3: Try RIT layout first ─────────────────────────
    entries: List[ParsedEntry] = []

    rit_result = _parse_rit_layout(
        lines, raw_text, dept, yr, sec, sem, acad_year, eff_date,
        course_dict or {}, faculty_dict or {}
    )
    if rit_result:
        entries = rit_result
        logger.info(f"[PARSER] ✅ RIT layout detected — {len(entries)} entries extracted")
    elif grid:
        entries = _parse_grid_entries(
            grid, dept, yr, sec, sem, acad_year, eff_date
        )
        logger.info(f"[PARSER] Generic grid — {len(entries)} entries extracted")
    
    if not entries:
        entries = _parse_linear_entries(
            lines, raw_text, dept, yr, sec, sem, acad_year, eff_date
        )
        logger.info(f"[PARSER] Linear fallback — {len(entries)} entries extracted")

    # ── Step 4: Merge with legend dictionaries ───────────────
    _merge_legend_dicts(entries, course_dict or {}, faculty_dict or {})

    # ── Step 5: Auto-link to DB records ─────────────────────
    _auto_link(entries, db)

    # ── Step 6: Validate ─────────────────────────────────────
    errors, warnings = _validate(entries)

    # ── Export debug artifacts ───────────────────────────────
    _export_debug(entries, dept, yr, sec, sem, acad_year, eff_date,
                  ocr_result.engine_used, errors, warnings)

    logger.info(f"[PARSER] Final: {len(entries)} entries, {len(errors)} errors, {len(warnings)} warnings")

    return ParsedTimetable(
        entries=entries,
        department=dept,
        year=yr,
        section=sec,
        semester=sem,
        academic_year=acad_year,
        effective_date=eff_date,
        validation_errors=errors,
        warnings=warnings,
        ocr_engine=ocr_result.engine_used,
    )


# ═══════════════════════════════════════════════════════════
# RIT Indian College Layout Parser (PRIMARY)
# ═══════════════════════════════════════════════════════════

def _parse_rit_layout(
    lines,
    raw_text: str,
    department: str, year: int, section: str,
    semester: Optional[int], academic_year: Optional[str],
    effective_date: Optional[date],
    course_dict: Dict[str, str],
    faculty_dict: Dict[str, str],
) -> Optional[List[ParsedEntry]]:
    """
    Parse Indian Engineering College timetable (RIT / Anna University format).

    The image has TWO tables:
      LEFT TABLE:  SL.No | Code | Course Name | ... | Faculty In-Charge
      RIGHT TABLE: Weekly period grid (rows=days, cols=periods)

    This function:
    1. Scans OCR lines for day names to find grid rows
    2. Scans for time patterns to build period column time map
    3. Extracts subject cell codes per (day, period)
    4. Resolves codes → full names using course_dict
    5. Returns ParsedEntry list
    """
    if not lines:
        return None

    # ── 1. Sort all lines by Y position ─────────────────────
    sorted_lines = sorted(lines, key=lambda ln: (ln.bbox[1] + ln.bbox[3]) / 2)

    # ── 2. Find day rows (lines containing day names) ────────
    day_rows: List[Tuple[str, List]] = []   # (day_name, [lines_in_row])
    for ln in sorted_lines:
        day = _normalize_day(ln.text)
        if day:
            day_rows.append((day, [ln]))
            logger.info(f"[RIT] Found day row: {day} at y={ln.bbox[1]}")

    if not day_rows:
        logger.warning("[RIT] No day rows found — not RIT layout")
        return None

    # ── 3. Build time column map from time-containing lines ──
    # Find lines that contain time ranges like "8:00-8:50" or "8.00 AM To 8.50 AM"
    time_lines = []
    for ln in sorted_lines:
        times = _extract_times_from_cell(ln.text)
        if times and times[0] and times[1]:
            time_lines.append((ln, times))

    # Build column x-position → (start_time, end_time) mapping
    # by clustering time labels by x-position
    time_col_map: Dict[int, Tuple[str, str]] = {}
    for ln, times in time_lines:
        cx = (ln.bbox[0] + ln.bbox[2]) // 2
        # Round to nearest 40px to cluster nearby columns
        col_key = (cx // 40) * 40
        if col_key not in time_col_map:
            time_col_map[col_key] = times

    logger.info(f"[RIT] Time columns found: {len(time_col_map)}")

    # ── 4. Find the x-range of the weekly grid ───────────────
    # The weekly grid starts after the day name cell
    # Day cells are typically the leftmost cells in day rows
    # Period cells are to the right of the day name

    # For each day row, gather all OCR lines at approximately the same Y
    day_y_tolerance = 25  # pixels

    entries: List[ParsedEntry] = []
    period_counter: Dict[str, int] = {}

    for day_name, day_ref_lines in day_rows:
        # Get the Y center of this day row
        ref_ln = day_ref_lines[0]
        day_y_center = (ref_ln.bbox[1] + ref_ln.bbox[3]) / 2

        # Find all OCR lines at same Y level (the period cells)
        row_cells = []
        for ln in sorted_lines:
            cy = (ln.bbox[1] + ln.bbox[3]) / 2
            if abs(cy - day_y_center) <= day_y_tolerance:
                row_cells.append(ln)

        # Sort by X position
        row_cells.sort(key=lambda ln: ln.bbox[0])

        logger.info(f"[RIT] Day {day_name}: {len(row_cells)} cells in row")

        # Skip the first cell if it's just the day name
        subject_cells = []
        for ln in row_cells:
            if _normalize_day(ln.text):
                continue  # skip day name cell itself
            txt = ln.text.strip()
            if txt and len(txt) >= 2:
                subject_cells.append(ln)

        # Assign period numbers and times
        period_no = 0
        for cell_ln in subject_cells:
            txt = cell_ln.text.strip()
            if not txt:
                continue

            # Skip non-teaching cells
            class_type = _classify_cell(txt)
            if class_type in ("Break", "Lunch"):
                continue  # skip break/lunch rows

            period_no += 1

            # Find best matching time for this cell's X position
            cx = (cell_ln.bbox[0] + cell_ln.bbox[2]) // 2
            col_key = (cx // 40) * 40

            # Try exact match then nearest neighbor
            time_match = time_col_map.get(col_key)
            if not time_match:
                # Find nearest column
                if time_col_map:
                    nearest = min(time_col_map.keys(), key=lambda k: abs(k - col_key))
                    if abs(nearest - col_key) < 120:  # within 3 columns
                        time_match = time_col_map[nearest]

            # Fall back to standard times
            if not time_match and (period_no - 1) < len(STANDARD_TIME_SLOTS):
                time_match = STANDARD_TIME_SLOTS[period_no - 1]

            start_t = time_match[0] if time_match else ""
            end_t   = time_match[1] if time_match else ""

            # Parse the cell content
            subject_code, subject_name, faculty_name = _parse_rit_cell(
                txt, course_dict, faculty_dict
            )

            # Determine class type
            if class_type == "Theory" and LAB_RE.search(txt):
                class_type = "Lab"

            entry = ParsedEntry(
                department=department,
                year=year,
                section=section,
                semester=semester,
                academic_year=academic_year,
                effective_date=effective_date,
                day_of_week=day_name,
                period_number=period_no,
                start_time=start_t,
                end_time=end_t,
                subject_name_raw=subject_name or txt,
                subject_code_raw=subject_code,
                faculty_name_raw=faculty_name,
                room_raw=None,
                class_type=class_type,
                credits=None,
                ocr_confidence=cell_ln.confidence,
            )
            entries.append(entry)
            logger.info(
                f"[RIT] {day_name} P{period_no}: code={subject_code} "
                f"name={subject_name} faculty={faculty_name} time={start_t}-{end_t}"
            )

    if not entries:
        logger.warning("[RIT] Day rows found but no entries extracted")
        return None

    return entries


def _parse_rit_cell(
    text: str,
    course_dict: Dict[str, str],
    faculty_dict: Dict[str, str],
) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Parse a single RIT timetable cell.

    Cell formats:
    - "BDA-AD23V12"           → code=AD23V12, prefix=BDA
    - "NLP-AL23531"           → code=AL23531, prefix=NLP
    - "CN Lab-CS23531"        → code=CS23531, prefix=CN
    - "BA-CB23531"            → code=CB23531, prefix=BA
    - "DI-AD23511"            → code=AD23511, prefix=DI
    - "DL Lab-AD23511"        → code=AD23511, prefix=DL
    - "NLP Lab-AL23531"       → code=AL23531, prefix=NLP (Lab)
    - "EDA-AI23V11"           → code=AI23V11, prefix=EDA
    - "DI-Lab-AD23S1"         → lab entry

    Returns (subject_code, subject_name, faculty_name)
    """
    text_clean = text.strip()

    subject_code: Optional[str] = None
    subject_name: Optional[str] = None
    faculty_name: Optional[str] = None

    # 1. Try RIT cell pattern: PREFIX-CODE or PREFIX-Lab-CODE
    rit_match = RIT_CELL_CODE_RE.search(text_clean)
    if rit_match:
        prefix = rit_match.group(1).upper()
        code_part = rit_match.group(2).upper()
        subject_code = code_part

        # Look up full name in course_dict
        # Try both the full text code and just the numeric code
        full_key = f"{prefix}-{code_part}"
        if full_key in course_dict:
            subject_name = course_dict[full_key]
        elif code_part in course_dict:
            subject_name = course_dict[code_part]
        else:
            # Use abbreviation expansion for prefix
            expanded = SUBJECT_ABBREVIATIONS.get(prefix, prefix)
            subject_name = expanded

        # Faculty lookup
        if full_key in faculty_dict:
            faculty_name = faculty_dict[full_key]
        elif code_part in faculty_dict:
            faculty_name = faculty_dict[code_part]

        return subject_code, subject_name, faculty_name

    # 2. Try plain subject code (AD23511, CS301, etc.)
    code_match = SUBJECT_CODE_RE.search(text_clean)
    if code_match:
        subject_code = code_match.group(0)
        if subject_code in course_dict:
            subject_name = course_dict[subject_code]
        if subject_code in faculty_dict:
            faculty_name = faculty_dict[subject_code]

        if not subject_name:
            # Remove code from text and use remainder
            remainder = SUBJECT_CODE_RE.sub("", text_clean).strip(" -/\\")
            subject_name = remainder if remainder else text_clean

        return subject_code, subject_name, faculty_name

    # 3. Check non-teaching keywords
    text_lower = text_clean.lower()
    for kw, ct in NON_TEACHING_KEYWORDS.items():
        if kw in text_lower:
            return None, ct, None

    # 4. Fallback: use raw text as subject name
    return None, text_clean, None


def _classify_cell(text: str) -> str:
    """Classify a cell as Break, Lunch, Free, Lab, or Theory."""
    text_lower = text.lower().strip()
    for kw, ct in NON_TEACHING_KEYWORDS.items():
        if kw in text_lower:
            return ct
    if LAB_RE.search(text):
        return "Lab"
    return "Theory"


# ═══════════════════════════════════════════════════════════
# Step 1 — Metadata Extraction
# ═══════════════════════════════════════════════════════════

def _extract_metadata(raw_text: str) -> Dict[str, Any]:
    meta: Dict[str, Any] = {}

    # Department — match "DEPARTMENT OF ..." or "Dept: ..."
    dept_patterns = [
        r"DEPARTMENT\s+OF\s+([A-Z][A-Za-z ,&\-]+)",
        r"(?:dept|department)[:\s.-]*([A-Z][A-Za-z &]+)",
    ]
    for pat in dept_patterns:
        m = re.search(pat, raw_text, re.IGNORECASE)
        if m:
            candidate = m.group(1).strip().rstrip(".,")
            if len(candidate) > 3:
                meta["department"] = candidate
                break

    # Year — "III Year" / "3rd Year" / "Class: III AI&ML-C"
    year_patterns = [
        r"\b(I{1,3}V?|IV|I|II|III)\s+(?:AI|year|B\.?E|B\.?Tech)",
        r"\b(\d)(?:st|nd|rd|th)?\s*year\b",
        r"class\s*:\s*(I{1,3}V?|IV)",
    ]
    roman = {"I": 1, "II": 2, "III": 3, "IV": 4}
    for pat in year_patterns:
        m = re.search(pat, raw_text, re.IGNORECASE)
        if m:
            val = m.group(1)
            if val.upper() in roman:
                meta["year"] = roman[val.upper()]
            elif val.isdigit():
                meta["year"] = int(val)
            break

    # Section — "Section: C" / "Class: III AI&ML-C" (trailing letter)
    sec_patterns = [
        r"\bsection\s*[:\-]?\s*([A-Z])\b",
        r"\bsec\s*[:\-]?\s*([A-Z])\b",
        r"AI&ML\s*[-–]\s*([A-Z])\b",
        r"[A-Z]&[A-Z]{2}\s*[-–]\s*([A-Z])\b",
        r"class\s*:\s*\w+\s+\w+[- ]([A-Z])\b",
    ]
    for pat in sec_patterns:
        m = re.search(pat, raw_text, re.IGNORECASE)
        if m:
            meta["section"] = m.group(1).upper()
            break

    # Semester
    m = re.search(r"\bsem(?:ester)?\s*[:\-]?\s*(\d{1,2})\b", raw_text, re.IGNORECASE)
    if m:
        meta["semester"] = int(m.group(1))

    # Roman numeral semester — "V Semester" / "Semester V"
    roman_sem = re.search(
        r"\b(I{1,3}V?|IV|V|VI{0,3}|IX|X)\s+semester\b"
        r"|\bsemester\s+(I{1,3}V?|IV|V|VI{0,3}|IX|X)\b",
        raw_text, re.IGNORECASE
    )
    if roman_sem and "semester" not in meta:
        val = (roman_sem.group(1) or roman_sem.group(2)).upper()
        roman_full = {
            "I": 1, "II": 2, "III": 3, "IV": 4,
            "V": 5, "VI": 6, "VII": 7, "VIII": 8,
        }
        if val in roman_full:
            meta["semester"] = roman_full[val]

    # Academic year
    m = re.search(r"\b(20\d\d)[–\-](20\d\d)\b", raw_text)
    if m:
        meta["academic_year"] = f"{m.group(1)}-{m.group(2)}"

    # Effective date (W.E.F DD/MM/YYYY)
    m = re.search(
        r"\bw\.?e\.?f\.?\s*[:\-]?\s*(\d{1,2})[./-](\d{1,2})[./-](\d{4})\b",
        raw_text, re.IGNORECASE
    )
    if m:
        try:
            d, mo, y = int(m.group(1)), int(m.group(2)), int(m.group(3))
            meta["effective_date"] = date(y, mo, d)
        except ValueError:
            pass

    logger.info(f"[META] Extracted: {meta}")
    return meta


# ═══════════════════════════════════════════════════════════
# Step 2 — Grid Detection
# ═══════════════════════════════════════════════════════════

@dataclass
class GridCell:
    text: str
    confidence: float
    row: int
    col: int
    x1: int
    y1: int
    x2: int
    y2: int


def _detect_grid(lines) -> Optional[List[List[GridCell]]]:
    """
    Cluster OCR lines into a 2D grid using bounding box positions.
    Returns grid[row][col] or None if grid can't be detected.
    """
    if not lines:
        return None

    sorted_lines = sorted(lines, key=lambda ln: (ln.bbox[1] + ln.bbox[3]) / 2)

    rows: List[List] = []
    current_band_y: Optional[float] = None
    current_band: List = []

    for ln in sorted_lines:
        cy = (ln.bbox[1] + ln.bbox[3]) / 2
        if current_band_y is None or abs(cy - current_band_y) > 18:
            if current_band:
                rows.append(current_band)
            current_band = [ln]
            current_band_y = cy
        else:
            current_band.append(ln)
            current_band_y = (current_band_y + cy) / 2

    if current_band:
        rows.append(current_band)

    if not rows:
        return None

    grid: List[List[GridCell]] = []
    for row_idx, row_lines in enumerate(rows):
        sorted_cols = sorted(row_lines, key=lambda ln: ln.bbox[0])
        grid_row: List[GridCell] = []
        for col_idx, ln in enumerate(sorted_cols):
            grid_row.append(GridCell(
                text=ln.text.strip(),
                confidence=ln.confidence,
                row=row_idx, col=col_idx,
                x1=ln.bbox[0], y1=ln.bbox[1],
                x2=ln.bbox[2], y2=ln.bbox[3],
            ))
        grid.append(grid_row)

    return grid


# ═══════════════════════════════════════════════════════════
# Step 3a — Grid-based Entry Parsing (Fallback)
# ═══════════════════════════════════════════════════════════

def _parse_grid_entries(
    grid: List[List[GridCell]],
    department: str, year: int, section: str,
    semester: Optional[int], academic_year: Optional[str],
    effective_date: Optional[date],
) -> List[ParsedEntry]:
    """
    Parse grid cells into ParsedEntry objects.
    Supports row-per-day and column-per-day formats.
    """
    entries: List[ParsedEntry] = []

    # Check for row-per-day format
    row_days: Dict[int, str] = {}
    for r_idx, row in enumerate(grid):
        if row and len(row) > 0:
            d = _normalize_day(row[0].text)
            if d:
                row_days[r_idx] = d

    # Check for col-per-day format
    day_row_idx = None
    day_col_map: Dict[int, str] = {}
    for row_idx, row in enumerate(grid):
        found_days = {}
        for cell in row:
            d = _normalize_day(cell.text)
            if d:
                found_days[cell.col] = d
        if len(found_days) >= 3:
            day_row_idx = row_idx
            day_col_map = found_days
            break

    # Extract time column map
    time_col_map: Dict[int, Tuple[str, str]] = {}
    for row in grid:
        for cell in row:
            times = _extract_times_from_cell(cell.text)
            if times:
                time_col_map[cell.col] = times

    logger.info(f"[GRID] {len(grid)} rows, row_days={list(row_days.values())}, col_days={list(day_col_map.values())}")

    default_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    fallback_day_idx = 0
    period_counter: Dict[str, int] = {}

    for row_idx, row in enumerate(grid):
        if row_idx == day_row_idx:
            continue

        row_day = row_days.get(row_idx)
        if not row_day and len(day_col_map) == 0:
            row_day = default_days[fallback_day_idx % len(default_days)]
            fallback_day_idx += 1

        for cell in row:
            if cell.col == 0 and _normalize_day(cell.text) and len(cell.text.strip().split()) == 1:
                continue

            day = day_col_map.get(cell.col) or row_day or default_days[fallback_day_idx % len(default_days)]
            content = cell.text.strip()
            if not content:
                continue

            times = time_col_map.get(cell.col, ("", ""))
            start_t, end_t = times

            period_counter.setdefault(day, 0)
            period_counter[day] += 1
            period_no = period_counter[day]

            entry = _parse_cell_content(
                content, cell.confidence,
                department, year, section, semester,
                academic_year, effective_date,
                day, period_no, start_t, end_t
            )
            if entry:
                entries.append(entry)

    logger.info(f"[GRID] Parsed {len(entries)} entries")
    return entries


def _parse_cell_content(
    text: str,
    confidence: float,
    department: str, year: int, section: str,
    semester: Optional[int], academic_year: Optional[str],
    effective_date: Optional[date],
    day: str, period_no: int,
    start_time: str, end_time: str,
) -> Optional[ParsedEntry]:
    """Parse a single timetable cell into a ParsedEntry."""

    text_clean = text.strip()
    text_lower = text_clean.lower()

    class_type = "Theory"
    for kw, ct in NON_TEACHING_KEYWORDS.items():
        if kw in text_lower:
            class_type = ct
            if ct in ("Break", "Lunch", "Free"):
                return ParsedEntry(
                    department=department, year=year, section=section,
                    semester=semester, academic_year=academic_year,
                    effective_date=effective_date,
                    day_of_week=day, period_number=period_no,
                    start_time=start_time, end_time=end_time,
                    subject_name_raw=ct, subject_code_raw=None,
                    faculty_name_raw=None, room_raw=None,
                    class_type=ct, credits=None, ocr_confidence=confidence
                )

    if LAB_RE.search(text_clean):
        class_type = "Lab"

    code_match = SUBJECT_CODE_RE.search(text_clean)
    subject_code = code_match.group(0) if code_match else None

    cell_lines = [ln.strip() for ln in text_clean.splitlines() if ln.strip()]
    subject_name = None
    faculty_name = None
    room_raw = None

    if len(cell_lines) >= 1:
        sub_raw = SUBJECT_CODE_RE.sub("", cell_lines[0]).strip(" -/")
        subject_name = sub_raw if sub_raw else cell_lines[0]
    if len(cell_lines) >= 2:
        faculty_name = _clean_faculty_name(cell_lines[1])
    if len(cell_lines) >= 3:
        room_raw = cell_lines[2]

    credits = None
    cr_match = CREDITS_RE.search(text_clean)
    if cr_match:
        credits = int(cr_match.group(1))

    if not subject_name or len(subject_name.strip()) == 0:
        subject_name = text_clean if text_clean else "Unassigned"

    return ParsedEntry(
        department=department, year=year, section=section,
        semester=semester, academic_year=academic_year,
        effective_date=effective_date,
        day_of_week=day, period_number=period_no,
        start_time=start_time, end_time=end_time,
        subject_name_raw=subject_name,
        subject_code_raw=subject_code,
        faculty_name_raw=faculty_name,
        room_raw=room_raw,
        class_type=class_type,
        credits=credits,
        ocr_confidence=confidence,
    )


# ═══════════════════════════════════════════════════════════
# Step 3b — Linear Fallback Parser
# ═══════════════════════════════════════════════════════════

def _parse_linear_entries(
    lines, raw_text: str,
    department: str, year: int, section: str,
    semester: Optional[int], academic_year: Optional[str],
    effective_date: Optional[date],
) -> List[ParsedEntry]:
    """
    Fallback for timetables where grid detection failed.
    Sequential day assignment (Monday → Saturday) if day headers missing.
    """
    entries: List[ParsedEntry] = []
    default_days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    day_idx = 0
    current_day = "Monday"
    period_no = 0

    for line in lines:
        txt = line.text.strip()
        if not txt or len(txt) < 2:
            continue

        detected_day = _normalize_day(txt)
        if detected_day:
            current_day = detected_day
            period_no = 0
            continue

        times = _extract_times_from_cell(txt)
        start_t = times[0] if times else ""
        end_t   = times[1] if times else ""

        period_no += 1
        if period_no > 7:
            day_idx = (day_idx + 1) % len(default_days)
            current_day = default_days[day_idx]
            period_no = 1

        entry = _parse_cell_content(
            txt, line.confidence,
            department, year, section, semester,
            academic_year, effective_date,
            current_day, period_no, start_t, end_t
        )
        if entry:
            entries.append(entry)

    logger.info(f"[LINEAR] Parsed {len(entries)} entries")
    return entries


# ═══════════════════════════════════════════════════════════
# Legend Dictionary Merger
# ═══════════════════════════════════════════════════════════

def _merge_legend_dicts(
    entries: List[ParsedEntry],
    course_dict: Dict[str, str],
    faculty_dict: Dict[str, str],
) -> None:
    """
    Enrich entries with course names and faculty from OCR legend tables.
    Updates entries in-place.
    """
    if not course_dict and not faculty_dict:
        return

    for e in entries:
        code = e.subject_code_raw
        if not code and e.subject_name_raw:
            m = SUBJECT_CODE_RE.search(e.subject_name_raw)
            if m:
                code = m.group(0)

        if code:
            # Enrich subject name if missing or just a code
            if code in course_dict:
                if not e.subject_name_raw or e.subject_name_raw == code:
                    e.subject_name_raw = course_dict[code]
            # Enrich faculty name if missing
            if code in faculty_dict and not e.faculty_name_raw:
                e.faculty_name_raw = faculty_dict[code]


# ═══════════════════════════════════════════════════════════
# Step 4 — Auto-link to DB Records
# ═══════════════════════════════════════════════════════════

def _auto_link(entries: List[ParsedEntry], db: DbSession) -> None:
    """
    Fuzzy-match raw OCR text → Subject / Faculty / Classroom DB records.
    Sets subject_id, faculty_id, classroom_id on each entry in-place.
    """
    from app.models.models import Subject, Faculty, Classroom

    subjects     = db.query(Subject).all()
    faculty_list = db.query(Faculty).all()
    classrooms   = db.query(Classroom).all()

    subj_names    = {s.id: (s.subject_name or "") for s in subjects}
    subj_codes    = {s.id: (s.subject_code or "") for s in subjects}
    faculty_names = {f.id: f.name for f in faculty_list}
    room_names    = {c.id: c.room_name for c in classrooms}

    for entry in entries:
        if entry.class_type in ("Break", "Lunch", "Free"):
            continue

        if entry.subject_code_raw and subjects:
            sid = _best_match_id(entry.subject_code_raw, subj_codes)
            if sid:
                entry.subject_id = sid
        if not entry.subject_id and entry.subject_name_raw and subjects:
            sid = _best_match_id(entry.subject_name_raw, subj_names)
            if sid:
                entry.subject_id = sid

        if entry.faculty_name_raw and faculty_list:
            fid = _best_match_id(entry.faculty_name_raw, faculty_names)
            if fid:
                entry.faculty_id = fid

        if entry.room_raw and classrooms:
            cid = _best_match_id(entry.room_raw, room_names)
            if cid:
                entry.classroom_id = cid


def _best_match_id(query: str, candidates: Dict[int, str],
                   threshold: float = 60.0) -> Optional[int]:
    """Return the DB id whose name best matches query (above threshold)."""
    if not query or not candidates:
        return None

    if _FUZZY:
        names  = list(candidates.values())
        ids    = list(candidates.keys())
        result = rfuzz_process.extractOne(
            query, names, scorer=fuzz.token_sort_ratio
        )
        if result and result[1] >= threshold:
            idx = names.index(result[0])
            return ids[idx]
    else:
        query_lower = query.lower()
        for did, name in candidates.items():
            if query_lower in name.lower() or name.lower() in query_lower:
                return did
    return None


# ═══════════════════════════════════════════════════════════
# Step 5 — Validation
# ═══════════════════════════════════════════════════════════

def _validate(entries: List[ParsedEntry]) -> Tuple[List[str], List[str]]:
    """Detect faculty/room clashes and missing data warnings."""
    errors: List[str] = []
    warnings: List[str] = []

    faculty_slot: Dict[Tuple, ParsedEntry] = {}
    room_slot: Dict[Tuple, ParsedEntry] = {}

    for e in entries:
        if e.class_type in ("Break", "Lunch", "Free"):
            continue

        if not e.subject_name_raw:
            warnings.append(f"Missing subject name: {e.day_of_week} P{e.period_number}")
        if not e.faculty_name_raw:
            warnings.append(
                f"No faculty found: {e.day_of_week} P{e.period_number} ({e.subject_name_raw})"
            )

        if e.faculty_id:
            fkey = (e.faculty_id, e.day_of_week, e.period_number)
            if fkey in faculty_slot:
                prev = faculty_slot[fkey]
                errors.append(
                    f"Faculty clash on {e.day_of_week} P{e.period_number}: "
                    f"faculty_id={e.faculty_id} assigned to both "
                    f"'{e.subject_name_raw}' and '{prev.subject_name_raw}'"
                )
            else:
                faculty_slot[fkey] = e

        if e.classroom_id:
            rkey = (e.classroom_id, e.day_of_week, e.period_number)
            if rkey in room_slot:
                prev = room_slot[rkey]
                errors.append(
                    f"Room clash on {e.day_of_week} P{e.period_number}: "
                    f"classroom_id={e.classroom_id} assigned to both "
                    f"'{e.department}{e.year}{e.section}' and "
                    f"'{prev.department}{prev.year}{prev.section}'"
                )
            else:
                room_slot[rkey] = e

    return errors, warnings


# ═══════════════════════════════════════════════════════════
# Debug Export
# ═══════════════════════════════════════════════════════════

def _export_debug(
    entries, dept, yr, sec, sem, acad_year, eff_date,
    engine, errors, warnings
) -> None:
    try:
        import json
        from pathlib import Path
        debug_dir = Path("static/timetable_uploads/debug")
        debug_dir.mkdir(parents=True, exist_ok=True)

        entry_list = [
            {
                "day": e.day_of_week,
                "period": e.period_number,
                "start_time": e.start_time,
                "end_time": e.end_time,
                "subject_code": e.subject_code_raw,
                "subject_name": e.subject_name_raw,
                "faculty": e.faculty_name_raw,
                "room": e.room_raw,
                "class_type": e.class_type,
                "confidence": e.ocr_confidence,
            }
            for e in entries
        ]

        with open(debug_dir / "09_parser_result.json", "w") as f:
            json.dump({"parsed_entries_count": len(entries), "entries": entry_list}, f, indent=2)

        final_json = {
            "department": dept, "year": yr, "section": sec,
            "semester": sem, "academic_year": acad_year,
            "effective_date": str(eff_date) if eff_date else None,
            "total_entries": len(entries),
            "engine": engine,
            "validation_errors": errors,
            "warnings": warnings,
            "entries": entry_list,
        }
        with open(debug_dir / "10_final_result.json", "w") as f:
            json.dump(final_json, f, indent=2)

        logger.info(f"[DEBUG] Saved 09 & 10 artifacts ({len(entries)} entries)")
    except Exception as ex:
        logger.warning(f"Debug export skipped: {ex}")


# ═══════════════════════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════════════════════

def _normalize_day(text: str) -> Optional[str]:
    """Return canonical day name or None. Must be strictly a day word."""
    t = text.strip().lower()
    if not t or len(t) > 15:
        return None
    # Must not contain digits or subject code patterns
    if re.search(r"\d", t):
        return None
    for full_day in DAYS_OF_WEEK:
        if full_day.lower() == t or t == f"{full_day.lower()}s":
            return full_day
    for alias, full_day in DAY_ALIASES.items():
        if t == alias or t.startswith(f"{alias} ") or t.startswith(f"{alias}:"):
            return full_day
    return None


def _extract_times_from_cell(text: str) -> Optional[Tuple[str, str]]:
    """Extract (start_time, end_time) from time range text."""
    matches = TIME_RE.findall(text)
    if len(matches) >= 2:
        return (_format_time(matches[0]), _format_time(matches[1]))
    elif len(matches) == 1:
        return (_format_time(matches[0]), "")
    return None


def _format_time(match_tuple) -> str:
    """Convert regex match tuple (hour, min, am/pm) → HH:MM."""
    h, m, ampm = match_tuple
    h, m = int(h), int(m)
    if ampm and ampm.lower() == "pm" and h < 12:
        h += 12
    if ampm and ampm.lower() == "am" and h == 12:
        h = 0
    return f"{h:02d}:{m:02d}"


def _clean_faculty_name(text: str) -> str:
    """Remove common prefixes from faculty name strings."""
    text = re.sub(r"^(Ms\.?|Mr\.?|Dr\.?|Prof\.?)\s*", "", text, flags=re.IGNORECASE).strip()
    return text
