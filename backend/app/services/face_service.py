# ============================================================
# SmartAttend — Face Recognition Service (ArcFace / InsightFace)
# Engine: InsightFace buffalo_l (512-dim normalized embeddings)
# No AWS Rekognition dependency.
# ============================================================

import os
import json
import logging
import numpy as np
import cv2
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.models import FaceEmbedding, Student

logger = logging.getLogger(__name__)

_app = None


def get_face_analysis_app():
    """Lazily load and return the InsightFace FaceAnalysis application."""
    global _app
    if _app is None:
        from insightface.app import FaceAnalysis
        from app.core.config import settings
        logger.info("[ArcFace] Initializing InsightFace FaceAnalysis (buffalo_l)...")
        
        # Expand model path (supports ~ and relative paths)
        root_path = os.path.abspath(os.path.expanduser(settings.ARCFACE_MODEL_PATH))
        os.makedirs(root_path, exist_ok=True)
        
        _app = FaceAnalysis(
            name="buffalo_l",
            root=root_path,
            providers=["CPUExecutionProvider"],
            allowed_modules=["detection", "recognition"],
        )
        _app.prepare(ctx_id=-1, det_size=(640, 640))
        logger.info("[ArcFace] InsightFace initialized successfully.")
    return _app


def decode_image_bytes(image_bytes: bytes) -> np.ndarray:
    """Decode raw image bytes to an OpenCV BGR image and downscale to max 640px to conserve memory."""
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Failed to decode image bytes. Image may be corrupted.")
    
    # Downscale image if too large (saves memory during InsightFace processing on 512MB RAM tier)
    max_dim = 640
    h, w = img.shape[:2]
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        new_w = int(w * scale)
        new_h = int(h * scale)
        img = cv2.resize(img, (new_w, new_h), interpolation=cv2.INTER_AREA)
        
    return img


def calculate_similarity(embedding1: np.ndarray, embedding2: np.ndarray) -> float:
    """
    Calculate the cosine similarity between two face embeddings.
    Returns a value in [-1, 1]; typical match scores are 0.5–1.0.
    """
    emb1 = np.array(embedding1, dtype=np.float32)
    emb2 = np.array(embedding2, dtype=np.float32)

    norm1 = np.linalg.norm(emb1)
    norm2 = np.linalg.norm(emb2)
    if norm1 > 0:
        emb1 = emb1 / norm1
    if norm2 > 0:
        emb2 = emb2 / norm2

    return float(np.dot(emb1, emb2))


def _laplacian_variance(img: np.ndarray) -> float:
    """Compute sharpness score of an image (higher = sharper)."""
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    return float(cv2.Laplacian(gray, cv2.CV_64F).var())


class FaceService:
    """
    ArcFace face registration, verification, and similarity matching.
    Zero dependency on AWS Rekognition.
    """

    # ─── Embedding Generation ─────────────────────────────────────

    def generate_embedding(self, image_bytes: bytes) -> np.ndarray:
        """
        Generate a 512-dim ArcFace embedding from raw image bytes.

        Raises HTTPException if no face or multiple faces are detected.
        """
        img = decode_image_bytes(image_bytes)
        app = get_face_analysis_app()
        faces = app.get(img)

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

        return faces[0].normed_embedding

    # ─── Single-Pose Registration (legacy, kept for compatibility) ─

    def register_face_embeddings(
        self, db: Session, student_id: int, image_bytes: bytes, pose_name: str
    ) -> dict:
        """
        Detect face in a single image, extract ArcFace embedding, store in DB.
        Saves a local profile picture if pose is 'front_face' or 'final_front'.
        """
        img = decode_image_bytes(image_bytes)
        app = get_face_analysis_app()
        faces = app.get(img)

        if len(faces) == 0:
            return {"success": False, "message": "No face detected. Position your face in the frame."}
        if len(faces) > 1:
            return {"success": False, "message": "Multiple faces detected. Ensure only one person is in frame."}

        face = faces[0]
        embedding = face.normed_embedding
        embedding_list = embedding.tolist()
        embedding_json_str = json.dumps(embedding_list)

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
        logger.info(f"[ArcFace] Stored embedding for student={student_id}, pose={pose_name}")

        # Save profile picture for front-face poses
        if pose_name in ["front_face", "final_front"]:
            static_dir = os.path.join("static", "faces")
            os.makedirs(static_dir, exist_ok=True)
            photo_path = os.path.join(static_dir, f"{student_id}.jpg")
            cv2.imwrite(photo_path, img)
            logger.info(f"[ArcFace] Saved profile image: {photo_path}")

        return {
            "success": True,
            "embedding": embedding_list,
            "det_score": float(face.det_score),
        }

    # ─── Batch Auto-Registration ──────────────────────────────────

    def register_face_embeddings_batch(
        self,
        db: Session,
        student_id: int,
        images_bytes: list[bytes],
        sharpness_threshold: float = 80.0,
        dedup_threshold: float = 0.98,
        max_stored: int = 50,
    ) -> dict:
        """
        Process a batch of 30–150 captured frames automatically.

        Pipeline:
        1. Decode each frame and detect face
        2. Filter blurry frames (Laplacian variance < sharpness_threshold)
        3. De-duplicate frames whose embedding is too similar to already-accepted ones
           (cosine_sim >= dedup_threshold → skip as near-duplicate)
        4. Store up to max_stored best unique embeddings in face_embeddings table
        5. Save profile picture from the sharpest accepted frame
        6. All raw bytes are discarded after processing — no images stored permanently

        Returns:
            {
                "success": bool,
                "stored": int,       # number of unique embeddings saved
                "total_input": int,  # frames received
                "rejected_no_face": int,
                "rejected_blurry": int,
                "rejected_duplicate": int,
                "message": str,
            }
        """
        if not images_bytes:
            return {"success": False, "stored": 0, "message": "No frames provided."}

        app = get_face_analysis_app()

        total_input = len(images_bytes)
        rejected_no_face = 0
        rejected_blurry = 0
        rejected_duplicate = 0

        accepted_embeddings: list[np.ndarray] = []
        accepted_det_scores: list[float] = []
        best_sharp_img: np.ndarray | None = None
        best_sharpness: float = 0.0

        logger.info(
            f"[ArcFace] Batch registration: student={student_id}, "
            f"frames={total_input}"
        )

        for idx, img_bytes in enumerate(images_bytes):
            # Stop once we have enough unique samples
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
                logger.debug(
                    f"[ArcFace] Frame {idx}: rejected blurry (sharpness={sharpness:.1f})"
                )
                continue

            # 3. Face detection
            try:
                faces = app.get(img)
            except Exception as e:
                logger.warning(f"[ArcFace] Frame {idx}: detection error: {e}")
                rejected_no_face += 1
                continue

            if len(faces) != 1:
                rejected_no_face += 1
                continue

            embedding = faces[0].normed_embedding
            det_score = float(faces[0].det_score)

            # 4. De-duplicate against already-accepted embeddings
            is_duplicate = False
            for accepted_emb in accepted_embeddings:
                if calculate_similarity(embedding, accepted_emb) >= dedup_threshold:
                    is_duplicate = True
                    break

            if is_duplicate:
                rejected_duplicate += 1
                logger.debug(f"[ArcFace] Frame {idx}: rejected duplicate")
                continue

            # 5. Accept this embedding
            accepted_embeddings.append(embedding)
            accepted_det_scores.append(det_score)

            # Track sharpest frame for profile picture
            if sharpness > best_sharpness:
                best_sharpness = sharpness
                best_sharp_img = img.copy()

        stored_count = len(accepted_embeddings)

        if stored_count == 0:
            logger.warning(
                f"[ArcFace] Batch registration failed: student={student_id}, "
                f"no valid frames accepted"
            )
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

        # 6. Delete all existing embeddings for this student, store fresh set
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

        # 7. Save profile picture from sharpest accepted frame (no permanent storage otherwise)
        if best_sharp_img is not None:
            static_dir = os.path.join("static", "faces")
            os.makedirs(static_dir, exist_ok=True)
            photo_path = os.path.join(static_dir, f"{student_id}.jpg")
            cv2.imwrite(photo_path, best_sharp_img)
            logger.info(f"[ArcFace] Saved profile image: {photo_path}")

        logger.info(
            f"[ArcFace] Batch registration complete: student={student_id}, "
            f"stored={stored_count}/{total_input} frames"
        )

        return {
            "success": True,
            "stored": stored_count,
            "total_input": total_input,
            "rejected_no_face": rejected_no_face,
            "rejected_blurry": rejected_blurry,
            "rejected_duplicate": rejected_duplicate,
            "message": (
                f"Face registered successfully! {stored_count} unique samples stored."
            ),
        }

    # ─── Load Student Embeddings ──────────────────────────────────

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

    # ─── Face Verification ────────────────────────────────────────

    def verify_face_embedding(
        self, db: Session, student_id: int, live_image_bytes: bytes
    ) -> dict:
        """
        Generate ArcFace embedding for live selfie, load all stored student embeddings,
        compute max cosine similarity, and return tiered verification result.

        Tiers:
            >= 0.75 → present
            0.65–0.74 → manual_review
            < 0.65 → rejected
        """
        # Generate live embedding
        try:
            live_emb = self.generate_embedding(live_image_bytes)
        except HTTPException as e:
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": e.detail,
            }
        except Exception as exc:
            logger.error(f"[ArcFace] Live embedding error: {exc}")
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "Failed to analyze live face image.",
            }

        # Load stored embeddings
        stored_embeddings = self.load_student_embeddings(db, student_id)
        logger.info(
            f"[ArcFace] Loaded {len(stored_embeddings)} stored embeddings "
            f"for student={student_id}"
        )

        if not stored_embeddings:
            logger.warning(f"[ArcFace] No stored embeddings for student={student_id}")
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "No registered face embeddings found. Please re-register your face.",
            }

        # Compare live embedding against all stored embeddings
        max_similarity = -1.0
        best_frame = None

        for i, stored_emb in enumerate(stored_embeddings):
            sim = calculate_similarity(live_emb, stored_emb)
            if sim > max_similarity:
                max_similarity = sim
                best_frame = i

        logger.info(
            f"[ArcFace] Verification result: student={student_id}, "
            f"max_similarity={max_similarity:.4f} (best_frame={best_frame})"
        )

        # Apply similarity tiers
        if max_similarity >= 0.75:
            tier = "present"
            verified = True
            message = "Face verified successfully! ✅"
        elif max_similarity >= 0.65:
            tier = "manual_review"
            verified = True
            message = "Face matched but similarity is borderline. Logged for manual review. ⚠️"
        else:
            tier = "rejected"
            verified = False
            message = "Face verification failed. Face not recognized. ❌"

        return {
            "verified": verified,
            "similarity": max_similarity,
            "tier": tier,
            "message": message,
        }


# Singleton service instance
face_service = FaceService()
