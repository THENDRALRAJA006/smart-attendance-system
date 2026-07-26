# ============================================================
# SmartAttend — OCR Service (v12)
# Layered fallback: PaddleOCR → EasyOCR → Tesseract
# Returns unified OcrResult regardless of engine used.
# ============================================================

import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# ── Engine availability flags ──────────────────────────────
_paddle_available  = False
_easyocr_available = False
_tesseract_available = False

try:
    from paddleocr import PaddleOCR
    _paddle_ocr_instance = None  # lazy init
    _paddle_available = True
    logger.info("✅ PaddleOCR available")
except ImportError:
    logger.info("ℹ️  PaddleOCR not installed — will try EasyOCR")

try:
    import easyocr
    _easy_reader = None  # lazy init
    _easyocr_available = True
    logger.info("✅ EasyOCR available")
except ImportError:
    logger.info("ℹ️  EasyOCR not installed — will try Tesseract")

try:
    import pytesseract
    import os, sys

    # ── Auto-detect Tesseract on Windows ────────────────────
    if sys.platform == "win32":
        _tess_candidates = [
            r"D:\Tesseract-OCR\tesseract.exe",           # D-drive install
            r"C:\Program Files\Tesseract-OCR\tesseract.exe",
            r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
            r"C:\Users\thiru\AppData\Local\Programs\Tesseract-OCR\tesseract.exe",
        ]
        for _p in _tess_candidates:
            if os.path.isfile(_p):
                pytesseract.pytesseract.tesseract_cmd = _p
                logger.info(f"✅ Tesseract found at: {_p}")
                break

    pytesseract.get_tesseract_version()
    _tesseract_available = True
    logger.info("✅ Tesseract available")
except Exception:
    logger.warning("⚠️  Tesseract not found — at least one OCR engine required")


# ── Data classes ───────────────────────────────────────────

@dataclass
class OcrWord:
    """Single detected word / token."""
    text: str
    confidence: float          # 0.0–1.0
    bbox: Tuple[int, int, int, int]  # (x1, y1, x2, y2)


@dataclass
class OcrLine:
    """A line of OCR-detected text (may span multiple words)."""
    text: str
    confidence: float
    bbox: Tuple[int, int, int, int]  # (x1, y1, x2, y2)
    words: List[OcrWord] = field(default_factory=list)


@dataclass
class OcrResult:
    """Full OCR output for one image."""
    lines: List[OcrLine]
    engine_used: str          # "paddle" | "easyocr" | "tesseract"
    raw_text: str


@dataclass
class CellOcrResult:
    row: int
    col: int
    text: str
    confidence: float
    engine_used: str
    bbox: Tuple[int, int, int, int]  # x, y, w, h


def detect_table_cells(image_path: str) -> List[dict]:
    """
    Phase 3: Detect grid table cells using OpenCV morphological line kernels.
    Returns list of dicts: [{'row': int, 'col': int, 'x': int, 'y': int, 'w': int, 'h': int}]
    """
    img = cv2.imread(image_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        return []

    h, w = img.shape
    # Threshold
    _, thresh = cv2.threshold(img, 200, 255, cv2.THRESH_BINARY_INV)

    # Detect horizontal lines
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (w // 25, 1))
    h_lines = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, h_kernel)

    # Detect vertical lines
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, h // 25))
    v_lines = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, v_kernel)

    # Combine grid lines
    grid = cv2.add(h_lines, v_lines)

    # Find contours of grid cells
    contours, _ = cv2.findContours(grid, cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)

    cells = []
    min_area = (w * h) * 0.0005
    max_area = (w * h) * 0.8

    for c in contours:
        x, y, cw, ch = cv2.boundingRect(c)
        area = cw * ch
        if min_area < area < max_area and cw > 20 and ch > 15:
            cells.append({'x': x, 'y': y, 'w': cw, 'h': ch})

    if not cells:
        return []

    # Sort cells by row (y) and col (x)
    cells = sorted(cells, key=lambda c: (c['y'] // 25, c['x']))

    # Assign row & column indices based on spatial alignment
    rows: List[List[dict]] = []
    for c in cells:
        placed = False
        for row in rows:
            if abs(row[0]['y'] - c['y']) < 20:
                row.append(c)
                placed = True
                break
        if not placed:
            rows.append([c])

    sorted_cells = []
    for r_idx, row in enumerate(rows):
        row_sorted = sorted(row, key=lambda c: c['x'])
        for c_idx, cell in enumerate(row_sorted):
            cell['row'] = r_idx
            cell['col'] = c_idx
            sorted_cells.append(cell)

    # ── Save Debug Artifacts 05, 06, 07 ─────────────────────────
    try:
        import json
        debug_dir = Path("static/timetable_uploads/debug")
        debug_dir.mkdir(parents=True, exist_ok=True)

        orig_img = cv2.imread(image_path)
        if orig_img is not None:
            overlay_img = orig_img.copy()
            for c in sorted_cells:
                cv2.rectangle(overlay_img, (c['x'], c['y']), (c['x'] + c['w'], c['y'] + c['h']), (0, 255, 0), 2)
                cv2.putText(overlay_img, f"R{c['row']}C{c['col']}", (c['x'] + 2, c['y'] + 12), cv2.FONT_HERSHEY_SIMPLEX, 0.4, (0, 0, 255), 1)
            cv2.imwrite(str(debug_dir / "06_cell_overlay.png"), overlay_img)

            # Draw cell crops grid
            cell_grid_img = np.zeros((max(h, 400), max(w, 400), 3), dtype=np.uint8) + 255
            for c in sorted_cells:
                crop = orig_img[c['y']:c['y']+c['h'], c['x']:c['x']+c['w']]
                if crop.size > 0:
                    cv2.rectangle(cell_grid_img, (c['x'], c['y']), (c['x'] + c['w'], c['y'] + c['h']), (200, 200, 200), 1)
            cv2.imwrite(str(debug_dir / "05_detected_cells.png"), cell_grid_img)

        with open(debug_dir / "07_table_matrix.json", "w") as f:
            json.dump({"cells_count": len(sorted_cells), "cells": sorted_cells}, f, indent=2)
    except Exception as e:
        logger.warning(f"Debug cell export skipped: {e}")

    return sorted_cells


def ocr_cell_crop(cell_crop: np.ndarray) -> Tuple[str, float, str]:
    """
    Phase 4: Run Multi-Engine Cell OCR Voting.
    Tries PaddleOCR, EasyOCR, and Tesseract, returning (best_text, best_conf, engine_name).
    """
    candidates = []

    # 1. PaddleOCR
    if _paddle_available:
        try:
            ocr = _get_paddle()
            res = ocr.ocr(cell_crop, cls=False)
            if res and res[0]:
                txt = res[0][0][1][0].strip()
                conf = float(res[0][0][1][1])
                candidates.append((txt, conf, "paddle"))
        except Exception:
            pass

    # 2. EasyOCR
    if _easyocr_available:
        try:
            reader = _get_easy_reader()
            res = reader.readtext(cell_crop, detail=1)
            if res:
                txt = str(res[0][1]).strip()
                conf = float(res[0][2])
                candidates.append((txt, conf, "easyocr"))
        except Exception:
            pass

    # 3. Tesseract
    if _tesseract_available:
        try:
            from PIL import Image
            pil_img = Image.fromarray(cv2.cvtColor(cell_crop, cv2.COLOR_BGR2RGB))
            txt = pytesseract.image_to_string(pil_img, config="--psm 7").strip()
            if txt:
                candidates.append((txt, 0.75, "tesseract"))
        except Exception:
            pass

    if not candidates:
        return ("", 0.0, "none")

    # Pick candidate with highest confidence score
    candidates.sort(key=lambda c: c[1], reverse=True)
    return candidates[0]


def ocr_legend_dictionaries(legend_image_path: str) -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Steps 8 & 9: OCR Course Mapping & Faculty Tables from the Legend Region.
    Parses table rows into:
      course_dict: {course_code -> course_name}
      faculty_dict: {course_code -> faculty_in_charge}
    """
    course_dict: Dict[str, str] = {}
    faculty_dict: Dict[str, str] = {}

    ocr_res = run_ocr(legend_image_path)
    if not ocr_res or not ocr_res.lines:
        return course_dict, faculty_dict

    import re
    # Regular expressions for course code and faculty pattern
    code_pattern = re.compile(r"\b([A-Z]{1,4}\d{2,5}[A-Z]?\d{0,4}|[A-Z0-9]{5,10})\b")

    for line in ocr_res.lines:
        txt = line.text.strip()
        if not txt or len(txt) < 4:
            continue

        match = code_pattern.search(txt)
        if match:
            code = match.group(0)
            # Remove sl.no, code from string
            remainder = code_pattern.sub("", txt).strip(" .-/")

            # Check if line has faculty title (Mr., Ms., Mrs., Dr., AP/, Prof)
            if re.search(r"\b(mr|ms|mrs|dr|ap/|prof)\b", remainder, re.IGNORECASE):
                faculty_dict[code] = remainder
                logger.info(f"[FACULTY MAPPED] {code} → {remainder}")
            elif len(remainder) > 3:
                course_dict[code] = remainder
                logger.info(f"[COURSE MAPPED] {code} → {remainder}")

    return course_dict, faculty_dict


def run_ocr(image_path: str) -> OcrResult:
    """
    Run OCR on a single image path.
    Tries PaddleOCR → EasyOCR → Tesseract until one succeeds.

    Returns OcrResult with engine_used indicating which engine ran.
    """
    if _paddle_available:
        try:
            return _run_paddle(image_path)
        except Exception as e:
            logger.warning(f"PaddleOCR failed: {e}. Trying EasyOCR…")

    if _easyocr_available:
        try:
            return _run_easyocr(image_path)
        except Exception as e:
            logger.warning(f"EasyOCR failed: {e}. Trying Tesseract…")

    if _tesseract_available:
        try:
            return _run_tesseract(image_path)
        except Exception as e:
            logger.error(f"Tesseract failed: {e}")

    raise RuntimeError(
        "All OCR engines failed. Please install at least one of: "
        "paddleocr, easyocr, or tesseract."
    )


def run_ocr_on_images(image_paths: List[str]) -> List[OcrResult]:
    """Run OCR on a list of image paths (multi-page PDF use case)."""
    results = []
    for path in image_paths:
        try:
            results.append(run_ocr(path))
        except Exception as e:
            logger.error(f"OCR failed on {path}: {e}")
    return results


def merge_ocr_results(results: List[OcrResult]) -> OcrResult:
    """Merge multi-page OCR results into a single OcrResult and save 08_raw_ocr.json."""
    if not results:
        return OcrResult(lines=[], engine_used="none", raw_text="")
    all_lines = []
    for r in results:
        all_lines.extend(r.lines)
    raw = "\n".join(r.raw_text for r in results)

    try:
        import json
        debug_dir = Path("static/timetable_uploads/debug")
        debug_dir.mkdir(parents=True, exist_ok=True)
        raw_json = {
            "engine_used": results[0].engine_used,
            "line_count": len(all_lines),
            "lines": [{"text": ln.text, "confidence": ln.confidence, "bbox": ln.bbox} for ln in all_lines]
        }
        with open(debug_dir / "08_raw_ocr.json", "w") as f:
            json.dump(raw_json, f, indent=2)
    except Exception as e:
        logger.warning(f"Debug raw OCR export skipped: {e}")

    return OcrResult(lines=all_lines, engine_used=results[0].engine_used, raw_text=raw)


# ── PaddleOCR ─────────────────────────────────────────────

def _get_paddle() -> "PaddleOCR":
    global _paddle_ocr_instance
    if _paddle_ocr_instance is None:
        _paddle_ocr_instance = PaddleOCR(
            use_angle_cls=True,
            lang="en",
            show_log=False,
            use_gpu=False,
        )
    return _paddle_ocr_instance


def _run_paddle(image_path: str) -> OcrResult:
    ocr = _get_paddle()
    result = ocr.ocr(image_path, cls=True)
    lines: List[OcrLine] = []

    if not result or not result[0]:
        return OcrResult(lines=[], engine_used="paddle", raw_text="")

    for item in result[0]:
        box_pts, (text, conf) = item
        # box_pts: [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]
        xs = [int(p[0]) for p in box_pts]
        ys = [int(p[1]) for p in box_pts]
        bbox = (min(xs), min(ys), max(xs), max(ys))
        lines.append(OcrLine(
            text=text.strip(),
            confidence=float(conf),
            bbox=bbox,
        ))

    raw = "\n".join(ln.text for ln in lines)
    return OcrResult(lines=lines, engine_used="paddle", raw_text=raw)


# ── EasyOCR ───────────────────────────────────────────────

def _get_easy_reader():
    global _easy_reader
    if _easy_reader is None:
        _easy_reader = easyocr.Reader(["en"], gpu=False, verbose=False)
    return _easy_reader


def _run_easyocr(image_path: str) -> OcrResult:
    reader = _get_easy_reader()
    results = reader.readtext(image_path, detail=1)
    lines: List[OcrLine] = []

    for (box_pts, text, conf) in results:
        xs = [int(p[0]) for p in box_pts]
        ys = [int(p[1]) for p in box_pts]
        bbox = (min(xs), min(ys), max(xs), max(ys))
        lines.append(OcrLine(
            text=str(text).strip(),
            confidence=float(conf),
            bbox=bbox,
        ))

    raw = "\n".join(ln.text for ln in lines)
    return OcrResult(lines=lines, engine_used="easyocr", raw_text=raw)


# ── Tesseract ─────────────────────────────────────────────

def _run_tesseract(image_path: str) -> OcrResult:
    from PIL import Image
    img = Image.open(image_path).convert("RGB")

    # Get word-level data with confidence scores
    data = pytesseract.image_to_data(
        img,
        config="--psm 6",   # Assume a uniform block of text
        output_type=pytesseract.Output.DICT
    )

    lines_map: dict = {}
    n = len(data["text"])

    for i in range(n):
        txt = str(data["text"][i]).strip()
        conf = int(data["conf"][i])
        if conf < 0 or not txt:
            continue

        block_num = data["block_num"][i]
        line_num  = data["line_num"][i]
        key = (block_num, line_num)

        x, y, w, h = (
            data["left"][i], data["top"][i],
            data["width"][i], data["height"][i]
        )
        word = OcrWord(
            text=txt,
            confidence=conf / 100.0,
            bbox=(x, y, x + w, y + h),
        )

        if key not in lines_map:
            lines_map[key] = {
                "words": [],
                "x1": x, "y1": y,
                "x2": x + w, "y2": y + h,
                "confs": [],
            }
        lines_map[key]["words"].append(word)
        lines_map[key]["confs"].append(conf / 100.0)
        lines_map[key]["x1"] = min(lines_map[key]["x1"], x)
        lines_map[key]["y1"] = min(lines_map[key]["y1"], y)
        lines_map[key]["x2"] = max(lines_map[key]["x2"], x + w)
        lines_map[key]["y2"] = max(lines_map[key]["y2"], y + h)

    lines: List[OcrLine] = []
    for key in sorted(lines_map.keys()):
        entry = lines_map[key]
        text = " ".join(w.text for w in entry["words"])
        avg_conf = float(np.mean(entry["confs"])) if entry["confs"] else 0.0
        lines.append(OcrLine(
            text=text,
            confidence=avg_conf,
            bbox=(entry["x1"], entry["y1"], entry["x2"], entry["y2"]),
            words=entry["words"],
        ))

    raw = "\n".join(ln.text for ln in lines)
    return OcrResult(lines=lines, engine_used="tesseract", raw_text=raw)
