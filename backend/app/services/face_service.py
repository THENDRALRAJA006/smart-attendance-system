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
            existing.embedding_version = "buffalo_s"
        else:
            db.add(FaceEmbedding(
                student_id=student_id,
                embedding_json=embedding_json_str,
                pose_name=pose_name,
                embedding_version="buffalo_s",
            ))

        db.commit()
        logger.info(f"[ArcFace] Stored embedding: student={student_id}, pose={pose_name}, version=buffalo_s")

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
        sharpness_threshold: float = 90.0,
        brightness_min: float = 40.0,
        dedup_threshold: float = 0.98,
        max_stored: int = 80,   # Enterprise: 80 unique embeddings for best accuracy
        min_required: int = 15, # Registration succeeds only if at least 15 quality embeddings
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
        rejected_dark = 0
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

            # 2b. Brightness filter (reject dark frames)
            gray_check = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            brightness = float(np.mean(gray_check))
            del gray_check
            if brightness < brightness_min:
                rejected_dark += 1
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
        # min_required is a separate param — max_stored caps the upper bound,
        # min_required is the lower quality gate.

        if stored_count < min_required:
            logger.warning(
                f"[ArcFace] Batch registration failed: student={student_id}, "
                f"stored={stored_count} < required={min_required}"
            )
            return {
                "success": False,
                "stored": stored_count,
                "total_input": total_input,
                "rejected_no_face": rejected_no_face,
                "rejected_blurry": rejected_blurry,
                "rejected_duplicate": rejected_duplicate,
                "message": (
                    f"Only {stored_count} usable face frames found (need {min_required}). "
                    "Ensure good lighting, single face in frame, and hold steady."
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
                embedding_version="buffalo_s",
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
        Generate ArcFace embedding for live selfie, compare against ALL stored
        embeddings, and return tiered verification result.

        Tiers (cosine similarity) — configurable via settings:
            >= ARCFACE_SIMILARITY_THRESHOLD -> present
            >= ARCFACE_REVIEW_THRESHOLD     -> manual_review
            <  ARCFACE_REVIEW_THRESHOLD     -> rejected

        CRITICAL: The comparison loop runs to completion for EVERY stored
        embedding. There is NO early return inside the loop. The attendance
        decision is based on the BEST similarity across ALL embeddings.
        """
        import time as _time
        from app.core.config import settings

        t_start = _time.perf_counter()

        # Get thresholds from config
        present_threshold = settings.ARCFACE_SIMILARITY_THRESHOLD
        review_threshold = settings.ARCFACE_REVIEW_THRESHOLD

        logger.info(
            f"[ArcFace] ========== FACE COMPARISON START ==========\n"
            f"  Student ID: {student_id}\n"
            f"  Present Threshold: {present_threshold}\n"
            f"  Review Threshold: {review_threshold}"
        )

        # ── Step 1: Generate live embedding ──────────────────────
        try:
            live_emb = self.generate_embedding(live_image_bytes)
            live_norm = float(np.linalg.norm(live_emb))
            logger.info(
                f"[ArcFace] ✅ Live face detected\n"
                f"  Embedding dimension: {len(live_emb)}\n"
                f"  Embedding norm: {live_norm:.4f}\n"
                f"  Embedding dtype: {live_emb.dtype}"
            )
        except HTTPException as e:
            logger.warning(f"[ArcFace] ❌ Live face detection failed: {e.detail}")
            return {"verified": False, "similarity": 0.0, "tier": "rejected", "message": e.detail}
        except Exception as exc:
            logger.error(f"[ArcFace] ❌ Live embedding error: {exc}")
            return {"verified": False, "similarity": 0.0, "tier": "rejected", "message": "Failed to analyze live face image."}

        # ── Step 2: Load ALL stored embeddings (query.all(), NOT .first()) ─
        records = (
            db.query(FaceEmbedding)
            .filter(FaceEmbedding.student_id == student_id)
            .all()  # ← CRITICAL: .all() loads every row, never .first() or LIMIT 1
        )
        total_stored = len(records)
        logger.info(f"[ArcFace] Loaded {total_stored} stored embeddings for student={student_id}")

        if not records:
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "No registered face embeddings found. Please re-register your face.",
            }

        # ── Step 3: Vectorized batch comparison (numpy matrix multiply) ─
        # Stack all stored embeddings into a matrix (N × 256),
        # then compute all cosine similarities in ONE dot-product op.
        emb_matrix: list[np.ndarray] = []
        record_ids: list[int] = []
        pose_names: list[str] = []

        for record in records:
            try:
                stored_emb = np.array(json.loads(record.embedding_json), dtype=np.float32)
                # L2-normalize
                norm = np.linalg.norm(stored_emb)
                if norm > 0:
                    stored_emb = stored_emb / norm
                emb_matrix.append(stored_emb)
                record_ids.append(record.id)
                pose_names.append(record.pose_name or '')
            except Exception as e:
                logger.error(f"[ArcFace] Failed to parse embedding id={record.id}: {e}")
                continue

        compared_count = len(emb_matrix)
        if compared_count == 0:
            return {
                "verified": False, "similarity": 0.0, "tier": "rejected",
                "message": "No valid embeddings found. Please re-register your face.",
            }

        # Stack into (N, 256) matrix and do single matmul: (256,) @ (256, N) = (N,)
        emb_stack = np.stack(emb_matrix, axis=0)   # (N, 256)

        # L2-normalize live embedding
        live_norm_val = np.linalg.norm(live_emb)
        live_emb_n = live_emb / live_norm_val if live_norm_val > 0 else live_emb

        # Vectorized cosine similarities
        similarity_scores_np = emb_stack @ live_emb_n                 # (N,)
        similarity_scores    = similarity_scores_np.tolist()

        best_idx       = int(np.argmax(similarity_scores_np))
        max_similarity = float(similarity_scores_np[best_idx])
        best_frame_idx = best_idx
        best_record_id = record_ids[best_idx]
        best_pose_name = pose_names[best_idx]

        # Log top 5 for audit
        top5_idx   = np.argsort(similarity_scores_np)[::-1][:5]
        top5_scores = [f"{similarity_scores_np[i]:.4f} ({pose_names[i]})" for i in top5_idx]
        logger.info(f"[ArcFace] Top-5 scores: {top5_scores}")

        # ── Step 4: Cleanup ─────────────────────────────────────
        del records, live_emb, emb_stack, emb_matrix
        gc.collect()

        t_elapsed = _time.perf_counter() - t_start

        # ── Step 5: Determine tier based on BEST similarity ─────
        if max_similarity >= present_threshold:
            tier = "present"
            verified = True
            msg = "Face verified successfully! ✅"
        elif max_similarity >= review_threshold:
            tier = "manual_review"
            verified = True
            msg = "Face matched but similarity is borderline. Logged for manual review. ⚠️"
        else:
            tier = "rejected"
            verified = False
            msg = "Face verification failed. Face not recognized. ❌"

        # ── Step 6: Final statistics ────────────────────────────
        avg_score = float(np.mean(similarity_scores_np))

        logger.info(
            f"\n"
            f"========== FACE MATCH SUMMARY ==========\n"
            f"  Student ID:          {student_id}\n"
            f"  Stored Embeddings:   {total_stored}\n"
            f"  Compared:            {compared_count}/{total_stored}\n"
            f"  Best Score:          {max_similarity:.4f}\n"
            f"  Average Score:       {avg_score:.4f}\n"
            f"  Matched Record:      id={best_record_id} pose='{best_pose_name}'\n"
            f"  Present Threshold:   {present_threshold}\n"
            f"  Review Threshold:    {review_threshold}\n"
            f"  Tier:                {tier}\n"
            f"  Verified:            {verified}\n"
            f"  Verification Time:   {t_elapsed:.3f}s (vectorized)\n"
            f"  Verification = {'SUCCESS ✅' if verified else 'REJECTED ❌'}\n"
            f"========================================="
        )

        return {
            "verified": verified,
            "similarity": max_similarity,
            "tier": tier,
            "message": msg,
            "similarity_scores": [round(s, 4) for s in similarity_scores],
            "best_frame": best_frame_idx,
            "best_record_id": best_record_id,
            "best_pose_name": best_pose_name,
            "compared_count": compared_count,
            "total_stored": total_stored,
            "avg_score": round(avg_score, 4),
            "verification_time_s": round(t_elapsed, 3),
        }


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
