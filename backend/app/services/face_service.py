# ============================================================
# SmartAttend — Face Recognition Service (Local ArcFace)
# ============================================================

import os
import json
import logging
import numpy as np
import cv2
from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from app.models.models import FaceEmbedding, Student, FaceProfile, StudentFace

logger = logging.getLogger(__name__)

_app = None

def get_face_analysis_app():
    """Lazily load and return the InsightFace FaceAnalysis application."""
    global _app
    if _app is None:
        from insightface.app import FaceAnalysis
        logger.info("[ArcFace] Initializing InsightFace FaceAnalysis (buffalo_l)...")
        # Initialize FaceAnalysis to run strictly on CPU using CPUExecutionProvider
        _app = FaceAnalysis(name="buffalo_l", root="~/.insightface", providers=["CPUExecutionProvider"])
        _app.prepare(ctx_id=-1, det_size=(640, 640))
        logger.info("[ArcFace] InsightFace initialized successfully.")
    return _app


def decode_image_bytes(image_bytes: bytes) -> np.ndarray:
    """Decode raw image bytes to an OpenCV BGR image."""
    nparr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Failed to decode image bytes. Image may be corrupted.")
    return img


def calculate_similarity(embedding1: np.ndarray, embedding2: np.ndarray) -> float:
    """Calculate the cosine similarity between two face embeddings."""
    # Since embeddings from FaceAnalysis are L2-normalized, the cosine similarity is the dot product.
    emb1 = np.array(embedding1, dtype=np.float32)
    emb2 = np.array(embedding2, dtype=np.float32)
    
    # Just in case they are not normalized, normalize them
    norm1 = np.linalg.norm(emb1)
    norm2 = np.linalg.norm(emb2)
    if norm1 > 0:
        emb1 = emb1 / norm1
    if norm2 > 0:
        emb2 = emb2 / norm2
        
    return float(np.dot(emb1, emb2))


class FaceService:
    """Service to handle student face registration, verification, and similarity matching locally."""

    def generate_embedding(self, image_bytes: bytes) -> np.ndarray:
        """
        Generate embedding for raw image bytes.
        
        Returns:
            512-dimensional normalized face embedding
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

    def register_face_embeddings(
        self, db: Session, student_id: int, image_bytes: bytes, pose_name: str
    ) -> dict:
        """
        Detect face, extract embedding, store in DB, and save image locally for profile pictures.
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
        
        # Save embedding record
        # Convert list to JSON string for storage in embedding_json (Text column)
        embedding_json_str = json.dumps(embedding_list)
        
        # Upsert face embedding in database
        existing = db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == student_id,
            FaceEmbedding.pose_name == pose_name
        ).first()
        
        if existing:
            existing.embedding_json = embedding_json_str
            existing.created_at = db.func.now()
        else:
            db.add(FaceEmbedding(
                student_id=student_id,
                embedding_json=embedding_json_str,
                pose_name=pose_name
            ))
            
        db.commit()
        logger.info(f"[ArcFace] Stored local face embedding for student={student_id}, pose={pose_name}")
        
        # Save image locally for profile display (e.g. if front_face or final_front)
        if pose_name in ["front_face", "final_front"]:
            static_dir = os.path.join("static", "faces")
            os.makedirs(static_dir, exist_ok=True)
            photo_path = os.path.join(static_dir, f"{student_id}.jpg")
            cv2.imwrite(photo_path, img)
            logger.info(f"[ArcFace] Saved profile image locally for student={student_id}: {photo_path}")
            
        return {
            "success": True,
            "embedding": embedding_list,
            "det_score": float(face.det_score)
        }

    def verify_face_embedding(
        self, db: Session, student_id: int, live_image_bytes: bytes
    ) -> dict:
        """
        Generate embedding for live image, load stored student embeddings,
        compare using cosine similarity, and return verification result.
        """
        try:
            live_emb = self.generate_embedding(live_image_bytes)
        except HTTPException as e:
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": e.detail
            }
        except Exception as exc:
            logger.error(f"[ArcFace] Error during live embedding generation: {exc}")
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "Failed to analyze live face image."
            }
            
        # Load stored embeddings for this student
        stored_records = db.query(FaceEmbedding).filter(
            FaceEmbedding.student_id == student_id
        ).all()
        
        if not stored_records:
            logger.warning(f"[ArcFace] No stored embeddings found for student={student_id}")
            return {
                "verified": False,
                "similarity": 0.0,
                "tier": "rejected",
                "message": "No registered face embeddings found. Please re-register."
            }
            
        # Compare live embedding against all stored embeddings
        max_similarity = -1.0
        best_pose = None
        
        for record in stored_records:
            try:
                stored_emb = np.array(json.loads(record.embedding_json), dtype=np.float32)
                sim = calculate_similarity(live_emb, stored_emb)
                if sim > max_similarity:
                    max_similarity = sim
                    best_pose = record.pose_name
            except Exception as e:
                logger.error(f"[ArcFace] Failed to read embedding record {record.id}: {e}")
                continue
                
        logger.info(
            f"[ArcFace] Face match result student={student_id}: "
            f"max_similarity={max_similarity:.4f} (best_pose={best_pose})"
        )
        
        # Apply tier rules
        # >= 0.75: present
        # 0.65 - 0.74: manual_review
        # < 0.65: rejected
        if max_similarity >= 0.75:
            tier = "present"
            verified = True
            message = "Face verified successfully! ✅"
        elif max_similarity >= 0.65:
            tier = "manual_review"
            verified = True  # verified is true but marked as manual_review tier
            message = "Face matched but similarity is borderline. Logged for manual review. ⚠️"
        else:
            tier = "rejected"
            verified = False
            message = "Face verification failed. Face not recognized."
            
        return {
            "verified": verified,
            "similarity": max_similarity,
            "tier": tier,
            "message": message
        }


# Singleton service
face_service = FaceService()
