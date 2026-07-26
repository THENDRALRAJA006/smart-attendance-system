# ============================================================
# SmartAttend — Image Preprocessing Service (v12)
# Deskews, denoises, enhances contrast for better OCR accuracy.
# Also converts multi-page PDFs to image list.
# ============================================================

import logging
import os
import uuid
from pathlib import Path
from typing import List, Tuple

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# ── Optional pdf2image import ──────────────────────────────
try:
    from pdf2image import convert_from_path
    PDF2IMAGE_AVAILABLE = True
    logger.info("✅ pdf2image available")
except ImportError:
    PDF2IMAGE_AVAILABLE = False
    logger.warning("⚠️  pdf2image not installed — PDF support unavailable")

# ── Auto-detect Poppler on Windows ─────────────────────────
import sys as _sys, os as _os
_POPPLER_PATH = None
if _sys.platform == "win32":
    _poppler_candidates = [
        r"D:\poppler\poppler-24.08.0\Library\bin",   # portable install
        r"C:\Program Files\poppler\Library\bin",
        r"C:\Program Files\poppler-24.08.0\Library\bin",
        r"C:\Program Files\poppler\bin",
        r"C:\poppler\Library\bin",
        r"C:\poppler\bin",
    ]
    # Also scan Program Files for any poppler-* folder
    for _pf in [r"C:\Program Files", r"C:\Program Files (x86)", r"C:"]:
        if _os.path.isdir(_pf):
            for _d in _os.listdir(_pf):
                if _d.lower().startswith("poppler"):
                    for _sub in ["Library\\bin", "bin"]:
                        _candidate = _os.path.join(_pf, _d, _sub)
                        if _os.path.isdir(_candidate):
                            _poppler_candidates.insert(0, _candidate)
    for _p in _poppler_candidates:
        if _os.path.isdir(_p) and any(
            f.startswith("pdftoppm") for f in _os.listdir(_p)
        ):
            _POPPLER_PATH = _p
            logger.info(f"✅ Poppler found at: {_p}")
            break
    if _POPPLER_PATH is None:
        logger.warning("⚠️  Poppler not found — PDF upload will fail. "
                       "Install via: winget install oschwartz10612.poppler")


UPLOAD_DIR = Path("static/timetable_uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


def save_upload(file_bytes: bytes, original_filename: str) -> str:
    """Save uploaded bytes to disk, return server path."""
    ext = Path(original_filename).suffix.lower()
    unique_name = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / unique_name
    dest.write_bytes(file_bytes)
    return str(dest)


def convert_pdf_to_images(pdf_path: str, dpi: int = 200) -> List[str]:
    """
    Convert each page of a PDF to a PNG image.
    Returns list of image file paths.
    """
    if not PDF2IMAGE_AVAILABLE:
        raise RuntimeError(
            "pdf2image is not installed. Install with: pip install pdf2image"
        )
    kwargs = {"dpi": dpi}
    if _POPPLER_PATH:
        kwargs["poppler_path"] = _POPPLER_PATH
    pages = convert_from_path(pdf_path, **kwargs)
    image_paths = []
    base = Path(pdf_path).stem
    out_dir = UPLOAD_DIR / base
    out_dir.mkdir(exist_ok=True)
    for i, page in enumerate(pages):
        img_path = str(out_dir / f"page_{i+1:03d}.png")
        page.save(img_path, "PNG")
        image_paths.append(img_path)
    logger.info(f"PDF → {len(image_paths)} images: {pdf_path}")
    return image_paths


def preprocess_image(image_path: str, save_previews: bool = True) -> str:
    """
    Phase 1 Preprocessing Pipeline:
    1. Load original image
    2. Auto rotate & perspective crop page edges
    3. Shadow removal (illuminance division)
    4. CLAHE contrast enhancement
    5. Bilateral & Gaussian denoise
    6. Morphological sharpening & Adaptive thresholding
    7. Save processed image + intermediate preview steps
    """
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Cannot read image: {image_path}")

    debug_dir = Path("static/timetable_uploads/debug")
    debug_dir.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(debug_dir / "01_original.png"), img)

    preview_dir = Path(image_path).parent / "previews"
    if save_previews:
        preview_dir.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(preview_dir / "01_original.png"), img)

    # ── 1. Page Edge Detection & Perspective Warp ─────────────
    warped = _crop_page_edges(img)
    if save_previews:
        cv2.imwrite(str(preview_dir / "02_perspective_crop.png"), warped)

    # ── 2. Convert to Grayscale & Upscale if small ─────────────
    gray = cv2.cvtColor(warped, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    if max(h, w) < 1400:
        scale = 1400 / max(h, w)
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # ── 3. Auto Deskewing ──────────────────────────────────────
    gray = _deskew(gray)
    cv2.imwrite(str(debug_dir / "02_deskew.png"), gray)
    if save_previews:
        cv2.imwrite(str(preview_dir / "03_deskewed.png"), gray)

    # ── 4. Shadow Removal (Illuminance division) ───────────────
    dilated = cv2.dilate(gray, np.ones((7, 7), np.uint8))
    bg = cv2.medianBlur(dilated, 21)
    diff = 255 - cv2.absdiff(gray, bg)
    norm = cv2.normalize(diff, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8UC1)

    # ── 5. CLAHE Contrast Enhancement ─────────────────────────
    clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
    enhanced = clahe.apply(norm)

    # ── 6. Bilateral Denoise & Sharpening ─────────────────────
    denoised = cv2.bilateralFilter(enhanced, 9, 75, 75)
    kernel_sharpen = np.array([[0, -1, 0], [-1, 5, -1], [0, -1, 0]])
    sharpened = cv2.filter2D(denoised, -1, kernel_sharpen)

    # ── 7. Adaptive Thresholding ──────────────────────────────
    thresh = cv2.adaptiveThreshold(
        sharpened, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY, 31, 10
    )
    cv2.imwrite(str(debug_dir / "03_threshold.png"), thresh)

    # ── 8. Detect & Draw Table Bounding Box ───────────────────
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (w // 15, 1))
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, h // 15))
    h_lines = cv2.morphologyEx(255 - thresh, cv2.MORPH_OPEN, h_kernel)
    v_lines = cv2.morphologyEx(255 - thresh, cv2.MORPH_OPEN, v_kernel)
    table_mask = cv2.add(h_lines, v_lines)
    contours, _ = cv2.findContours(table_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    debug_table_img = img.copy()
    if contours:
        largest_c = max(contours, key=cv2.contourArea)
        x, y, tw, th = cv2.boundingRect(largest_c)
        cv2.rectangle(debug_table_img, (x, y), (x + tw, y + th), (0, 255, 0), 4)
    cv2.imwrite(str(debug_dir / "04_table_detection.png"), debug_table_img)

    out_path = image_path.replace(".", "_processed.")
    if not out_path.endswith(".png"):
        out_path = out_path.rsplit(".", 1)[0] + "_processed.png"
    cv2.imwrite(out_path, thresh)
    logger.info(f"Phase 1 Preprocessing complete → {out_path}")
    return out_path


def segment_document_regions(image_path: str) -> dict:
    """
    Step 2: Region Segmentation for Multi-Layout Timetable Documents.
    Detects and crops:
      - 'header': Top ~20% (Institution, Dept, Semester, Section, WEF date)
      - 'main_timetable': Middle grid table
      - 'legend_table': Course mapping & Faculty table
      - 'signatures': Bottom ~15% (Ignored for OCR)
    """
    img = cv2.imread(image_path)
    if img is None:
        raise ValueError(f"Cannot read image for region segmentation: {image_path}")

    h, w, _ = img.shape
    region_dir = Path(image_path).parent / "regions"
    region_dir.mkdir(parents=True, exist_ok=True)

    # Detect horizontal grid line tables to segment regions
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)

    # Detect large horizontal line structures
    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (w // 15, 1))
    h_lines = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, h_kernel)

    contours, _ = cv2.findContours(h_lines, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    bounding_boxes = [cv2.boundingRect(c) for c in contours if cv2.boundingRect(c)[2] > (w * 0.4)]
    bounding_boxes = sorted(bounding_boxes, key=lambda b: b[1])  # sort top-to-bottom

    if len(bounding_boxes) >= 2:
        # Split into Main Timetable Grid (upper table) and Legend Table (lower table)
        mid_y = bounding_boxes[len(bounding_boxes) // 2][1]
        header_crop = img[0:int(h * 0.20), 0:w]
        main_grid_crop = img[int(h * 0.15):int(h * 0.60), 0:w]
        legend_crop = img[int(h * 0.55):int(h * 0.88), 0:w]
        signatures_crop = img[int(h * 0.88):h, 0:w]
    else:
        # Standard proportions
        header_crop = img[0:int(h * 0.22), 0:w]
        main_grid_crop = img[int(h * 0.18):int(h * 0.62), 0:w]
        legend_crop = img[int(h * 0.58):int(h * 0.88), 0:w]
        signatures_crop = img[int(h * 0.88):h, 0:w]

    header_path = str(region_dir / "01_header.png")
    main_grid_path = str(region_dir / "02_main_timetable.png")
    legend_path = str(region_dir / "03_legend_table.png")
    signatures_path = str(region_dir / "04_signatures_ignored.png")

    cv2.imwrite(header_path, header_crop)
    cv2.imwrite(main_grid_path, main_grid_crop)
    cv2.imwrite(legend_path, legend_crop)
    cv2.imwrite(signatures_path, signatures_crop)

    logger.info(f"[REGION DETECTED] Header: {header_path}")
    logger.info(f"[REGION DETECTED] Main Timetable Grid: {main_grid_path}")
    logger.info(f"[REGION DETECTED] Course & Faculty Legend: {legend_path}")
    logger.info(f"[REGION IGNORED] Footer & Signatures: {signatures_path}")

    return {
        "header_path": header_path,
        "main_grid_path": main_grid_path,
        "legend_path": legend_path,
        "signatures_path": signatures_path,
    }


def _crop_page_edges(img: np.ndarray) -> np.ndarray:
    """Detect outer page boundary contour and warp perspective."""
    try:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        edged = cv2.Canny(blurred, 50, 200)

        contours, _ = cv2.findContours(edged, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]

        for c in contours:
            peri = cv2.arcLength(c, True)
            approx = cv2.approxPolyDP(c, 0.02 * peri, True)
            if len(approx) == 4 and cv2.contourArea(c) > (img.shape[0] * img.shape[1] * 0.2):
                pts = approx.reshape(4, 2)
                return _four_point_transform(img, pts)
        return img
    except Exception as e:
        logger.debug(f"Page edge warp skipped (fallback to original): {e}")
        return img


def _four_point_transform(image: np.ndarray, pts: np.ndarray) -> np.ndarray:
    """Perspective warp 4 corners into rectangular card view."""
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]

    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]

    (tl, tr, br, bl) = rect
    widthA = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
    widthB = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
    maxWidth = max(int(widthA), int(widthB))

    heightA = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
    heightB = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
    maxHeight = max(int(heightA), int(heightB))

    dst = np.array([
        [0, 0],
        [maxWidth - 1, 0],
        [maxWidth - 1, maxHeight - 1],
        [0, maxHeight - 1]
    ], dtype="float32")

    M = cv2.getPerspectiveTransform(rect, dst)
    return cv2.warpPerspective(image, M, (maxWidth, maxHeight))


def _deskew(gray: np.ndarray) -> np.ndarray:
    """Detect skew angle via Hough lines and straighten text."""
    try:
        edges = cv2.Canny(gray, 50, 150, apertureSize=3)
        lines = cv2.HoughLines(edges, 1, np.pi / 180, threshold=100)
        if lines is None:
            return gray

        angles = []
        for line in lines[:50]:
            rho, theta = line[0]
            angle = np.degrees(theta) - 90
            if abs(angle) < 45:
                angles.append(angle)

        if not angles:
            return gray

        median_angle = float(np.median(angles))
        if abs(median_angle) < 0.5:
            return gray

        h, w = gray.shape
        center = (w // 2, h // 2)
        M = cv2.getRotationMatrix2D(center, median_angle, 1.0)
        return cv2.warpAffine(
            gray, M, (w, h),
            flags=cv2.INTER_CUBIC,
            borderMode=cv2.BORDER_REPLICATE
        )
    except Exception:
        return gray


def get_file_type(filename: str) -> str:
    """Return normalized file type: pdf | jpg | png | jpeg"""
    return Path(filename).suffix.lower().lstrip(".")
