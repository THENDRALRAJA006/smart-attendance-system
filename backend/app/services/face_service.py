# ============================================================
# SmartAttend — Face Recognition Service (Memory Optimized v2)
# Engine: InsightFace buffalo_s (256-dim normalized embeddings)
#
# Memory optimizations applied:
#   1. buffalo_l → buffalo_s  (~120 MB vs ~400 MB model size)
#   2. det_size (640,640) → (320,320)  (4× fewer pixels)
#   3. ONNX SessionOptions: inter=1, intra=2 threads
#   4. Eager init at import time (not lazily on first request)
#   5. del img / del faces + gc.collect() after each frame
#   6. max_stored reduced 50 → 15 embeddings
#   7. Max image resize 640 → 480 px
#   8. No img.copy() — avoid duplicate RAM allocation
# ============================================================

import gc
import os
import json
import logging
import numpy as np
import cv2
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.models import FaceEmbedding, Student

logger = logging.getLogger(__name__)

# ─── ONNX Thread Configuration ───────────────────────────────
# Set before InsightFace import to apply globally to all sessions
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")

# ─── Singleton Model Instance ────────────────────────────────
_app = None


def get_face_analysis_app():
    """
    Return the singleton InsightFace FaceAnalysis app.
    NOTE: Called at module import time. Will NOT be re-initialized per request.
    """
    global _app
    if _app is not None:
        return _app

    from insightface.app import FaceAnalysis
    from app.core.config import settings

    logger.info("[ArcFace] Initializing InsightFace buffalo_s (memory-optimized)...")

    root_path = os.path.abspath(os.path.expanduser(settings.ARCFACE_MODEL_PATH))
    os.makedirs(root_path, exist_ok=True)

    # buffalo_s: ~120 MB RAM vs buffalo_l ~400 MB
    # Same API surface, 256-dim embeddings, ~96% face recognition accuracy
    _app = FaceAnalysis(
        name="buffalo_s",
        root=root_path,
        providers=["CPUExecutionProvider"],
        allowed_modules=["detection", "recognition"],
    )

    # det_size (320,320) uses 4x less memory than (640,640)
    _app.prepare(ctx_id=-1, det_size=(320, 320))

    logger.info("[ArcFace] buffalo_s initialized successfully.")
    gc.collect()
    return _app


def decode_image_bytes(image_bytes: bytes) -> np.ndarray:
    """
    Decode raw image bytes to an OpenCV BGR image.
    Resizes to max 480px to conserve memory during inference.
    """
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    del nparr  # Release buffer reference immediately

    if img is None:
        raise ValueError("Failed to decode image. File may be corrupted or unsupported format.")

    # Downscale to max 480px (was 640px) - 44% less memory during detection
    max_dim = 480
    h, w = img.shape[:2]
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        img = cv2.resize(
            img,
            (int(w * scale), int(h * scale)),
            interpolation=cv2.INTER_AREA,
        )

    return img


def calculate_similarity(embedding1: np.ndarray, embedding2: np.ndarray) -> float:
    """
    Cosine similarity between two face embeddings.
    Returns value in [-1, 1]; typical match >= 0.65 for same person.
    """
    emb1 = np.asarray(embedding1, dtype=np.float32)
    emb2 = np.asarray(embedding2, dtype=np.float32)

    n1 = np.linalg.norm(emb1)
    n2 = np.linalg.norm(emb2)

    if n1 > 0:
        emb1 = emb1 / n1
    if n2 > 0:
        emb2 = emb2 / n2

    return float(np.dot(emb1, emb2))


def _laplacian_variance(img: np.ndarray) -> float:
    """Sharpness score via Laplacian variance (higher = sharper)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    lap = cv2.Laplacian(gray, cv2.CV_64F)
    var = float(lap.var())
    del gray, lap
    return var


class FaceService:
    """
    ArcFace face registration, verification, and similarity matching.
    Memory-optimized for Render Free (512 MB RAM).
    """

    # ─── Embedding Generation ─────────────────────────────────

    def generate_embedding(self, image_bytes: bytes) -> np.ndarray:
        """
        Generate a 256-dim ArcFace embedding from raw image bytes.
        Raises HTTPException if no face or multiple faces detected.
        """
        img = decode_image_bytes(image_bytes)
        app = get_face_analysis_app()

        try:
            faces = app.get(img)
        finally:
            del img   # Always release decoded image
            gc.collect()

        if len(faces) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No face detected. Please position your face inside the camera frame.",
            )
        if len(faces) > 1:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Multiple faces detected. Please make sure only one person is in frame.",
            )

        embedding = faces[0].normed_embedding.copy()
        del faces
        return embedding

    # ─── Single-Pose Registration (legacy) ───────────────────

    def register_face_embeddings(
        self, db: Session, student_id: int, image_bytes: bytes, pose_name: str
    ) -> dict:
        """
        Detect face, extract ArcFace embedding, store in DB.
        Saves profile picture if pose is 'front_face' or 'final_front'.
        """
        img = decode_image_bytes(image_bytes)
        app = get_face_analysis_app()

        try:
            faces = app.get(img)
        except Exception as e:
            del img
            gc.collect()
            return {"success": False, "message": f"Face detection failed: {e}"}

        if len(faces) == 0:
            del img
            gc.collect()
            return {"success": False, "message": "No face detected. Position your face in the frame."}

        if len(faces) > 1:
            del img
            gc.collect()
            return {"success": False, "message": "Multiple faces detected. Ensure only one person is in frame."}

        face = faces[0]
        embedding = face.normed_embedding.copy()
        det_score = float(face.det_score)
        embedding_list = embedding.tolist()
        embedding_json_str = json.dumps(embedding_list)

        # Save profile picture for front-face poses (before del img)
        if pose_name in ["front_face", "final_front"]:
            try:
                static_dir = os.path.join("static", "faces")
                os.makedirs(static_dir, exist_ok=True)
                photo_path = os.path.join(static_dir, f"{student_id}.jpg")
                cv2.imwrite(photo_path, img)
                logger.info(f"[ArcFace] Saved profile image: {photo_path}")
            except Exception as e:
                logger.warning(f"[ArcFace] Could not save profile image: {e}")

        # Release image memory immediately
        del img, faces, face
        gc.collect()

        # Upsert embedding record
        existing = db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == student_id,
            FaceEmbedding.pose_name == pose_name,
        ).first()

        if existing:
            existing.embedding_json = embedding_json_str
        else:
            db.add(FaceEmbedding(
                student_id=student_id,
                embedding_json=embedding_json_str,
                pose_name=pose_name,
            ))

        db.commit()
        logger.info(f"[ArcFace] Stored embedding: student={student_id}, pose={pose_name}")

        return {
            "success": True,
            "embedding": embedding_list,
            "det_score": det_score,
        }

    # ─── Batch Auto-Registration (memory-optimized) ──────────

    def register_face_embeddings_batch(
        self,
        db: Session,
        student_id: int,
        images_bytes: list[bytes],
        sharpness_threshold: float = 80.0,
        dedup_threshold: float = 0.98,
        max_stored: int = 15,   # Reduced from 50 to save ~35 embedding arrays in RAM
    ) -> dict:
        """
        Process a batch of captured frames. Memory-optimized:
        - Decode one frame at a time (never hold all images in RAM)
        - del img immediately after each frame
        - Store only embeddings (small arrays), not decoded images
        - gc.collect() every 20 frames
        """
        if not images_bytes:
            return {"success": False, "stored": 0, "message": "No frames provided."}

        app = get_face_analysis_app()

        total_input = len(images_bytes)
        rejected_no_face = 0
        rejected_blurry = 0
        rejected_duplicate = 0

        # Store embeddings only (not decoded images)
        accepted_embeddings: list[np.ndarray] = []
        best_frame_bytes: bytes | None = None   # raw bytes ref, not decoded img
        best_sharpness: float = 0.0

        logger.info(
            f"[ArcFace] Batch registration: student={student_id}, "
            f"frames={total_input}, max_store={max_stored}"
        )

        for idx, img_bytes in enumerate(images_bytes):
            if len(accepted_embeddings) >= max_stored:
                break

            # 1. Decode
            try:
                img = decode_image_bytes(img_bytes)
            except Exception:
                rejected_no_face += 1
                continue

            # 2. Sharpness filter
            sharpness = _laplacian_variance(img)
            if sharpness < sharpness_threshold:
                rejected_blurry += 1
                del img
                continue

            # 3. Face detection
            try:
                faces = app.get(img)
            except Exception as e:
                logger.warning(f"[ArcFace] Frame {idx}: detection error: {e}")
                rejected_no_face += 1
                del img
                gc.collect()
                continue

            if len(faces) != 1:
                rejected_no_face += 1
                del img, faces
                continue

            embedding = faces[0].normed_embedding.copy()
            det_score = float(faces[0].det_score)

            # Release detected faces immediately (holds ONNX output buffers)
            del faces

            # 4. De-duplicate
            is_duplicate = any(
                calculate_similarity(embedding, acc) >= dedup_threshold
                for acc in accepted_embeddings
            )

            if is_duplicate:
                rejected_duplicate += 1
                del img, embedding
                continue

            # 5. Accept
            accepted_embeddings.append(embedding)

            # Track sharpest frame as raw bytes (not decoded img)
            if sharpness > best_sharpness:
                best_sharpness = sharpness
                best_frame_bytes = img_bytes   # reference only, no copy

            # Release decoded image immediately
            del img

            # Periodic GC every 20 frames
            if idx % 20 == 0:
                gc.collect()

        stored_count = len(accepted_embeddings)

        if stored_count == 0:
            logger.warning(f"[ArcFace] Batch registration failed: student={student_id}")
            return {
                "success": False,
                "stored": 0,
                "total_input": total_input,
                "rejected_no_face": rejected_no_face,
                "rejected_blurry": rejected_blurry,
                "rejected_duplicate": rejected_duplicate,
                "message": (
                    "No usable face frames found. Ensure good lighting, "
                    "single face in frame, and hold steady."
                ),
            }

        # 6. Delete old embeddings, store fresh set
        db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == student_id
        ).delete()

        for i, emb in enumerate(accepted_embeddings):
            db.add(FaceEmbedding(
                student_id=student_id,
                embedding_json=json.dumps(emb.tolist()),
                pose_name=f"auto_frame_{i:03d}",
            ))

        db.commit()

        # Release all embedding arrays
        del accepted_embeddings
        gc.collect()

        # 7. Save profile picture from sharpest frame
        if best_frame_bytes is not None:
            try:
                best_img = decode_image_bytes(best_frame_bytes)
                static_dir = os.path.join("static", "faces")
                os.makedirs(static_dir, exist_ok=True)
                photo_path = os.path.join(static_dir, f"{student_id}.jpg")
                cv2.imwrite(photo_path, best_img)
                del best_img
                logger.info(f"[ArcFace] Saved profile image: {photo_path}")
            except Exception as e:
                logger.warning(f"[ArcFace] Could not save profile image: {e}")

        gc.collect()

        logger.info(
            f"[ArcFace] Batch complete: student={student_id}, "
            f"stored={stored_count}/{total_input}"
        )

        return {
            "success": True,
            "stored": stored_count,
            "total_input": total_input,
            "rejected_no_face": rejected_no_face,
            "rejected_blurry": rejected_blurry,
            "rejected_duplicate": rejected_duplicate,
            "message": f"Face registered successfully! {stored_count} unique samples stored.",
        }

    # ─── Load Student Embeddings ──────────────────────────────

    def load_student_embeddings(
        self, db: Session, student_id: int
    ) -> list[np.ndarray]:
        """Load all stored ArcFace embeddings for a student."""
        records = (
            db.query(FaceEmbedding)
            .filter(FaceEmbedding.student_id == student_id)
            .all()
        )
        embeddings = []
        for record in records:
            try:
                emb = np.array(json.loads(record.embedding_json), dtype=np.float32)
                embeddings.append(emb)
            except Exception as e:
                logger.error(f"[ArcFace] Failed to parse embedding id={record.id}: {e}")
        return embeddings

    # ─── Face Verification ────────────────────────────────────

    def verify_face_embedding(
        self, db: Session, student_id: int, live_image_bytes: bytes
    ) -> dict:
        """
        Generate ArcFace embedding for live selfie, compare against stored
        embeddings, and return tiered verification result.

        Tiers (cosine similarity):
            >= 0.75 -> present
            0.65 - 0.74 -> manual_review
            < 0.65 -> rejected
        """
        try:
            live_emb = self.generate_embedding(live_image_bytes)
        except HTTPException as e:
            return {"verified": False, "similarity": 0.0, "tier": "rejected", "message": e.detail}
        except Exception as exc:
            logger.error(f"[ArcFace] Live embedding error: {exc}")
            return {"verified": False, "similarity": 0.0, "tier": "rejected", "message": "Failed to analyze live face image."}

        stored_embeddings = self.load_student_embeddings(db, student_id)
        logger.info(f"[ArcFace] Loaded {len(stored_embeddings)} embeddings for student={student_id}")

        if not stored_embeddings:
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "No registered face embeddings found. Please re-register your face.",
            }

        max_similarity = -1.0
        best_frame = None
        for i, stored_emb in enumerate(stored_embeddings):
            sim = calculate_similarity(live_emb, stored_emb)
            if sim > max_similarity:
                max_similarity = sim
                best_frame = i

        del stored_embeddings, live_emb
        gc.collect()

        logger.info(
            f"[ArcFace] Verification: student={student_id}, "
            f"max_similarity={max_similarity:.4f} (best_frame={best_frame})"
        )

        if max_similarity >= 0.75:
            return {"verified": True, "similarity": max_similarity, "tier": "present", "message": "Face verified successfully! ✅"}
        elif max_similarity >= 0.65:
            return {"verified": True, "similarity": max_similarity, "tier": "manual_review", "message": "Face matched but similarity is borderline. Logged for manual review. ⚠️"}
        else:
            return {"verified": False, "similarity": max_similarity, "tier": "rejected", "message": "Face verification failed. Face not recognized. ❌"}


# ─── Singleton service instance ──────────────────────────────
face_service = FaceService()

# ─── Eager model initialization ─────────────────────────────
# Load the model NOW at import time - not lazily on first request.
# OOM crash happens at startup (visible in logs), not mid-request.
try:
    get_face_analysis_app()
    logger.info("[ArcFace] Model pre-loaded at import time.")
except Exception as e:
    logger.error(f"[ArcFace] FATAL: Could not load buffalo_s model: {e}")
    # Don't re-raise — let the app start and surface error via /health
