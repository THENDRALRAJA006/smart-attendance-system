# ============================================================
# SmartAttend — AWS Rekognition Service
# Face registration and verification with anti-spoof
# ============================================================

import boto3
import logging
from botocore.exceptions import ClientError
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)


class RekognitionService:
    """
    Handles all AWS Rekognition operations:
    - Collection management
    - Face indexing (registration)
    - Face searching (verification)
    """

    def __init__(self):
        self.client = boto3.client(
            "rekognition",
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        self.collection_id = settings.AWS_REKOGNITION_COLLECTION_ID
        self.confidence_threshold = settings.FACE_CONFIDENCE_THRESHOLD

    # ─── Ensure collection exists ────────────────────────────
    def ensure_collection(self) -> None:
        """Create the face collection if it doesn't exist."""
        try:
            self.client.create_collection(CollectionId=self.collection_id)
            logger.info(f"Created Rekognition collection: {self.collection_id}")
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code == "ResourceAlreadyExistsException":
                logger.debug(f"Collection already exists: {self.collection_id}")
            else:
                logger.error(f"Failed to create collection: {e}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail="AWS Rekognition service unavailable",
                )

    # ─── Register Face ───────────────────────────────────────
    def register_face(self, image_bytes: bytes, student_id: int) -> str:
        """
        Index a student's face into the Rekognition collection.
        
        Args:
            image_bytes: Raw JPEG/PNG image bytes
            student_id: Database student ID (used as external image ID)
        
        Returns:
            AWS FaceId string for storage
        
        Raises:
            HTTPException: If no face detected or multiple faces found
        """
        try:
            response = self.client.index_faces(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                ExternalImageId=f"student_{student_id}",
                DetectionAttributes=["DEFAULT"],
                MaxFaces=1,
                QualityFilter="AUTO",  # Filter low-quality images
            )

            face_records = response.get("FaceRecords", [])
            unindexed = response.get("UnindexedFaces", [])

            if not face_records:
                reason = ""
                if unindexed:
                    reason = unindexed[0].get("Reasons", ["Unknown"])[0]
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"No face detected in image. {reason}",
                )

            face_id = face_records[0]["Face"]["FaceId"]
            confidence = face_records[0]["Face"]["Confidence"]
            logger.info(
                f"Registered face for student {student_id}: "
                f"FaceId={face_id}, Confidence={confidence:.1f}%"
            )
            return face_id

        except ClientError as e:
            logger.error(f"Rekognition register_face error: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Face registration failed. AWS error.",
            )

    # ─── Verify Face ─────────────────────────────────────────
    def verify_face(self, image_bytes: bytes, student_face_id: str) -> dict:
        """
        Search for a face in the collection and verify it matches.
        
        Args:
            image_bytes: Raw image of person attempting attendance
            student_face_id: Stored FaceId of the registered student
        
        Returns:
            dict with keys: match (bool), confidence (float), face_id (str)
        """
        try:
            # Step 1: Detect face in submitted image
            detect_response = self.client.detect_faces(
                Image={"Bytes": image_bytes},
                Attributes=["DEFAULT"],
            )
            
            face_details = detect_response.get("FaceDetails", [])
            if not face_details:
                return {
                    "match": False,
                    "confidence": 0.0,
                    "message": "No face detected in submitted image",
                }

            # Step 2: Search collection for matching face
            search_response = self.client.search_faces_by_image(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                MaxFaces=1,
                FaceMatchThreshold=self.confidence_threshold,
            )

            face_matches = search_response.get("FaceMatches", [])
            
            if not face_matches:
                return {
                    "match": False,
                    "confidence": 0.0,
                    "message": "Face does not match registered student",
                }

            best_match = face_matches[0]
            matched_face_id = best_match["Face"]["FaceId"]
            similarity = best_match["Similarity"]

            # Step 3: Verify it's the same student
            if matched_face_id != student_face_id:
                return {
                    "match": False,
                    "confidence": similarity,
                    "message": "Face matched a different person",
                }

            if similarity < self.confidence_threshold:
                return {
                    "match": False,
                    "confidence": similarity,
                    "message": f"Confidence {similarity:.1f}% below threshold {self.confidence_threshold}%",
                }

            logger.info(
                f"Face verified: FaceId={matched_face_id}, "
                f"Similarity={similarity:.1f}%"
            )
            return {
                "match": True,
                "confidence": similarity,
                "message": "Face verified successfully",
            }

        except self.client.exceptions.InvalidParameterException:
            return {
                "match": False,
                "confidence": 0.0,
                "message": "No face detected in image",
            }
        except ClientError as e:
            logger.error(f"Rekognition verify_face error: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Face verification failed. AWS error.",
            )

    # ─── Delete Face ─────────────────────────────────────────
    def delete_face(self, face_id: str) -> bool:
        """Remove a registered face from the collection."""
        try:
            self.client.delete_faces(
                CollectionId=self.collection_id,
                FaceIds=[face_id],
            )
            return True
        except ClientError as e:
            logger.error(f"Failed to delete face {face_id}: {e}")
            return False


# ─── Singleton ───────────────────────────────────────────────
rekognition_service = RekognitionService()
