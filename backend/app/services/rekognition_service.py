# ============================================================
# SmartAttend - AWS Rekognition Service
# ============================================================

import os
import logging
import boto3
from botocore.exceptions import ClientError
from app.core.config import settings

logger = logging.getLogger(__name__)


class RekognitionService:
    def __init__(self):
        # Read keys directly from settings
        aws_id = settings.AWS_ACCESS_KEY_ID or os.getenv("AWS_ACCESS_KEY_ID")
        aws_secret = settings.AWS_SECRET_ACCESS_KEY or os.getenv("AWS_SECRET_ACCESS_KEY")
        aws_region = settings.AWS_REGION or os.getenv("AWS_REGION", "ap-south-1")
        
        self.client = boto3.client(
            "rekognition",
            aws_access_key_id=aws_id,
            aws_secret_access_key=aws_secret,
            region_name=aws_region,
        )
        self.collection_id = settings.AWS_REKOGNITION_COLLECTION_ID

    def ensure_collection(self) -> None:
        """Verify the Rekognition collection exists; create it if not."""
        try:
            logger.info(f"Checking AWS Rekognition collection: '{self.collection_id}'...")
            self.client.describe_collection(CollectionId=self.collection_id)
            logger.info(f"✅ AWS Rekognition collection '{self.collection_id}' exists.")
        except ClientError as e:
            if e.response["Error"]["Code"] == "ResourceNotFoundException":
                logger.info(f"Collection '{self.collection_id}' not found. Creating it...")
                try:
                    self.client.create_collection(CollectionId=self.collection_id)
                    logger.info(f"✅ AWS Rekognition collection '{self.collection_id}' created successfully.")
                except ClientError as ce:
                    logger.error(f"Failed to create collection '{self.collection_id}': {ce}")
                    raise ce
            else:
                logger.error(f"Error checking collection '{self.collection_id}': {e}")
                raise e

    def register_face(self, image_bytes: bytes, student_id: int) -> str:
        """
        Index a single face in the Rekognition collection.
        Returns the FaceId.
        """
        try:
            response = self.client.index_faces(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                ExternalImageId=str(student_id),
                DetectionAttributes=["ALL"],
                MaxFaces=1,
            )
            face_records = response.get("FaceRecords", [])
            if not face_records:
                raise Exception("No face detected in the image during indexing.")
            
            face_id = face_records[0]["Face"]["FaceId"]
            logger.info(f"Registered face for student={student_id}, face_id={face_id}")
            return face_id
        except ClientError as e:
            logger.error(f"Failed to index face for student={student_id}: {e}")
            raise e

    def register_face_pose(self, image_bytes: bytes, student_id: int, pose_index: int, pose_type: str) -> dict:
        """
        Index primary poses (1, 2, 4, 13, 15) in the Rekognition collection.
        For other poses, perform simple detection.
        """
        is_primary = pose_index in [1, 2, 4, 13, 15]
        
        if is_primary:
            try:
                response = self.client.index_faces(
                    CollectionId=self.collection_id,
                    Image={"Bytes": image_bytes},
                    ExternalImageId=f"{student_id}_{pose_index}",
                    DetectionAttributes=["ALL"],
                    MaxFaces=1,
                )
                face_records = response.get("FaceRecords", [])
                if face_records:
                    face = face_records[0]["Face"]
                    return {
                        "face_id": face["FaceId"],
                        "confidence": float(face.get("Confidence", 100.0)),
                        "is_primary": True,
                        "indexed": True
                    }
                else:
                    return {
                        "face_id": None,
                        "confidence": None,
                        "is_primary": True,
                        "indexed": False
                    }
            except ClientError as e:
                logger.error(f"Failed to index primary pose {pose_index} for student={student_id}: {e}")
                return {
                    "face_id": None,
                    "confidence": None,
                    "is_primary": True,
                    "indexed": False
                }
        else:
            # Non-primary poses: just run standard detection
            try:
                response = self.client.detect_faces(
                    Image={"Bytes": image_bytes},
                    Attributes=["DEFAULT"]
                )
                faces = response.get("FaceDetails", [])
                if faces:
                    return {
                        "face_id": None,
                        "confidence": float(faces[0].get("Confidence", 100.0)),
                        "is_primary": False,
                        "indexed": False
                    }
                else:
                    return {
                        "face_id": None,
                        "confidence": None,
                        "is_primary": False,
                        "indexed": False
                    }
            except ClientError as e:
                logger.error(f"Failed to verify non-primary pose {pose_index} for student={student_id}: {e}")
                return {
                    "face_id": None,
                    "confidence": None,
                    "is_primary": False,
                    "indexed": False
                }

    def verify_face(
        self,
        image_bytes: bytes,
        target_face_id: str,
        student_id: int | None = None,
        threshold: float = 85.0,
    ) -> dict:
        """
        Verify live face against registered face ID by searching the Rekognition
        collection.

        Strategy:
        - Use FaceMatchThreshold=75.0 so AWS returns ALL matches ≥ 75%.
        - Apply tier logic in Python using the configurable `threshold`:
            similarity >= threshold        → "present"     (high confidence)
            75.0 <= similarity < threshold → "manual_review" (low confidence)
            similarity < 75.0              → "rejected"

        Returns:
            {
                "matched": bool,
                "verified": bool,       # alias for matched (spec compliance)
                "confidence": float,
                "tier": str,            # "present" | "manual_review" | "rejected"
                "message": str,
            }
        """
        if image_bytes is None or len(image_bytes) == 0:
            raise ValueError("Image bytes cannot be null or empty")

        logger.info("Image received")
        logger.info(f"Image size: {len(image_bytes)} bytes")
        logger.info("CompareFaces started")

        # AWS pre-filter: return all matches ≥ 75% so we can apply our own tier
        AWS_MIN_THRESHOLD = 75.0

        try:
            logger.info(
                f"[REKOGNITION] search_faces_by_image: student_id={student_id}, "
                f"target_face_id={target_face_id}, tier_threshold={threshold:.1f}%"
            )
            response = self.client.search_faces_by_image(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                MaxFaces=10,
                FaceMatchThreshold=AWS_MIN_THRESHOLD,
            )
            logger.info(
                f"[REKOGNITION] AWS response received: "
                f"{len(response.get('FaceMatches', []))} matches found"
            )
        except ClientError as e:
            logger.error(f"[REKOGNITION] search_faces_by_image failed: {e}")
            return {
                "matched": False,
                "verified": False,
                "confidence": 0.0,
                "tier": "rejected",
                "message": str(e),
            }

        matches = response.get("FaceMatches", [])

        # Find the best matching face for this student
        best_similarity: float = 0.0
        best_match_found = False

        for match in matches:
            face = match["Face"]
            matched_face_id = face["FaceId"]
            external_image_id = face.get("ExternalImageId", "")
            similarity = float(match["Similarity"])

            # Match by direct face ID
            is_direct_match = (matched_face_id == target_face_id)

            # Match by student ID prefix (multi-pose: "123_1", "123_2", etc.)
            is_student_match = False
            if student_id is not None:
                prefix_1 = f"{student_id}_"
                prefix_2 = f"student_{student_id}_"
                is_student_match = (
                    external_image_id == str(student_id)
                    or external_image_id.startswith(prefix_1)
                    or external_image_id.startswith(prefix_2)
                )

            if is_direct_match or is_student_match:
                if similarity > best_similarity:
                    best_similarity = similarity
                    best_match_found = True
                    logger.info(
                        f"[REKOGNITION] Candidate match: face_id={matched_face_id}, "
                        f"external_id={external_image_id}, similarity={similarity:.2f}%"
                    )

        if not best_match_found:
            logger.warning(
                f"[REKOGNITION] No match found: target_face_id={target_face_id}, "
                f"student_id={student_id}, total_candidates={len(matches)}"
            )
            return {
                "matched": False,
                "verified": False,
                "confidence": 0.0,
                "tier": "rejected",
                "message": "No face match found in collection.",
            }

        # Apply strict threshold logic in Python
        confidence = best_similarity
        logger.info(f"Similarity score: {confidence}")
        if confidence >= threshold:
            tier = "present"
            matched = True
            message = f"Face matched successfully ({confidence:.1f}%)"
            logger.info(
                f"[REKOGNITION] MATCH ✅ student_id={student_id}, "
                f"confidence={confidence:.2f}%, tier=present"
            )
        else:
            tier = "rejected"
            matched = False
            message = f"Face confidence too low ({confidence:.1f}%). Match threshold is {threshold:.1f}%."
            logger.warning(
                f"[REKOGNITION] REJECTED student_id={student_id}, "
                f"confidence={confidence:.2f}%, required={threshold:.1f}%"
            )

        return {
            "matched": matched,
            "verified": matched,
            "confidence": round(confidence, 2),
            "tier": tier,
            "message": message,
        }

    def delete_face(self, face_id: str) -> bool:
        """Delete a single face ID from the Rekognition collection."""
        try:
            self.client.delete_faces(
                CollectionId=self.collection_id,
                FaceIds=[face_id]
            )
            logger.info(f"Deleted face_id={face_id} from collection")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete face_id={face_id}: {e}")
            return False

    def delete_faces(self, face_ids: list[str]) -> int:
        """Delete list of face IDs from the Rekognition collection."""
        if not face_ids:
            return 0
        try:
            response = self.client.delete_faces(
                CollectionId=self.collection_id,
                FaceIds=face_ids
            )
            deleted_count = len(response.get("DeletedFaces", []))
            logger.info(f"Deleted {deleted_count} faces from collection")
            return deleted_count
        except ClientError as e:
            logger.error(f"Failed to delete faces {face_ids}: {e}")
            return 0

    def compare_faces(self, source_bytes, target_bytes, threshold=80):
        """Compare two faces directly via compare_faces API."""
        if source_bytes is None or len(source_bytes) == 0:
            raise ValueError("Source image bytes cannot be null or empty")
        if target_bytes is None or len(target_bytes) == 0:
            raise ValueError("Target image bytes cannot be null or empty")

        logger.info("Image received")
        logger.info(f"Image size: {len(source_bytes)} bytes (source), {len(target_bytes)} bytes (target)")
        logger.info("CompareFaces started")

        try:
            response = self.client.compare_faces(
                SourceImage={"Bytes": source_bytes},
                TargetImage={"Bytes": target_bytes},
                SimilarityThreshold=threshold,
            )

            matches = response.get("FaceMatches", [])

            if matches:
                similarity = matches[0]["Similarity"]
                logger.info(f"Similarity score: {similarity}")

                return {
                    "matched": True,
                    "confidence": float(similarity),
                    "message": "Face matched successfully",
                }

            logger.info("Similarity score: 0 (no match)")
            return {
                "matched": False,
                "confidence": 0,
                "message": "No face match found",
            }

        except ClientError as e:
            logger.error(f"CompareFaces failed: {e}")
            return {
                "matched": False,
                "confidence": 0,
                "message": str(e),
            }

    def detect_faces(self, image_bytes):
        """Run Rekognition detect_faces on one image."""
        try:
            response = self.client.detect_faces(
                Image={"Bytes": image_bytes},
                Attributes=["ALL"],
            )
            return response
        except ClientError as e:
            return {
                "error": str(e)
            }


rekognition_service = RekognitionService()