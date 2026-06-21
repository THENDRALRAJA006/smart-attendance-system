# ============================================================
# SmartAttend — AWS Rekognition Service (v4)
# Face registration and verification with anti-spoof + confidence tiers
#
# v4 changes:
#   - register_face_pose(): index individual pose images
#   - verify_face_with_tiers(): returns present/manual_review/rejected
#   - delete_student_faces(): batch-delete all FaceIds for a student
# ============================================================

import logging
from botocore.exceptions import ClientError
import boto3
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)

# ─── Confidence tier thresholds ──────────────────────────────
TIER_PRESENT       = 95.0   # >= 95% → automatically marked present
TIER_MANUAL_REVIEW = 90.0   # 90-95% → stored, flagged for faculty review
# < 90% → rejected, not marked

# Poses to index in Rekognition (best angles for recognition accuracy)
PRIMARY_POSES = {1, 2, 4, 13, 15}  # front faces + slight angles (5 of 15)


class RekognitionService:
    """
    Handles all AWS Rekognition operations:
    - Collection management
    - Face indexing (registration) — single and multi-pose
    - Face searching (verification) — with confidence tier logic
    - Face deletion
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

    # ─── Register Face (single image, legacy) ────────────────
    def register_face(self, image_bytes: bytes, student_id: int) -> str:
        """
        Index a student's face into the Rekognition collection.
        Legacy method — kept for backward compatibility.

        Returns:
            AWS FaceId string
        """
        try:
            response = self.client.index_faces(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                ExternalImageId=f"student_{student_id}",
                DetectionAttributes=["DEFAULT"],
                MaxFaces=1,
                QualityFilter="AUTO",
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

    # ─── v4: Register one pose image ─────────────────────────
    def register_face_pose(
        self,
        image_bytes: bytes,
        student_id: int,
        pose_index: int,
        pose_type: str,
    ) -> dict:
        """
        Index a single guided-pose image into the Rekognition collection.
        Only poses in PRIMARY_POSES are indexed (best recognition angles).

        ExternalImageId format: student_{id}_pose_{index:02d}

        Args:
            image_bytes: Raw JPEG/PNG image bytes
            student_id: Database student ID
            pose_index: 1-15
            pose_type: Human-readable label (e.g. 'front_face', 'left_15')

        Returns:
            {
                "face_id": str | None,
                "confidence": float | None,
                "indexed": bool,
                "is_primary": bool,
                "reason": str
            }
        """
        is_primary = pose_index in PRIMARY_POSES

        if not is_primary:
            # Upload to S3 only; don't index in Rekognition to keep collection lean
            logger.info(
                f"Pose {pose_index} ({pose_type}) for student {student_id}: "
                "S3 only (not a primary pose)"
            )
            return {
                "face_id": None,
                "confidence": None,
                "indexed": False,
                "is_primary": False,
                "reason": "Non-primary pose — stored in S3 only",
            }

        try:
            external_id = f"student_{student_id}_pose_{pose_index:02d}"
            response = self.client.index_faces(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                ExternalImageId=external_id,
                DetectionAttributes=["DEFAULT"],
                MaxFaces=1,
                QualityFilter="AUTO",
            )

            face_records = response.get("FaceRecords", [])
            unindexed = response.get("UnindexedFaces", [])

            if not face_records:
                reason = "No face detected"
                if unindexed:
                    reasons = unindexed[0].get("Reasons", [])
                    reason = ", ".join(reasons) if reasons else reason
                logger.warning(
                    f"Pose {pose_index} not indexed for student {student_id}: {reason}"
                )
                return {
                    "face_id": None,
                    "confidence": None,
                    "indexed": False,
                    "is_primary": True,
                    "reason": reason,
                }

            face_id = face_records[0]["Face"]["FaceId"]
            confidence = face_records[0]["Face"]["Confidence"]

            logger.info(
                f"Indexed pose {pose_index} ({pose_type}) for student {student_id}: "
                f"FaceId={face_id}, Confidence={confidence:.1f}%"
            )

            return {
                "face_id": face_id,
                "confidence": confidence,
                "indexed": True,
                "is_primary": True,
                "reason": "Indexed successfully",
            }

        except ClientError as e:
            logger.error(
                f"Rekognition register_face_pose error: "
                f"student={student_id}, pose={pose_index}: {e}"
            )
            return {
                "face_id": None,
                "confidence": None,
                "indexed": False,
                "is_primary": True,
                "reason": f"AWS error: {str(e)}",
            }

    # ─── v4: Verify face with confidence tiers ────────────────
    def verify_face_with_tiers(self, image_bytes: bytes, student_id: int) -> dict:
        """
        Search for a student's face using their ExternalImageId prefix.
        Returns tiered confidence result.

        Tiers:
            >= 95%   → present
            90-95%   → manual_review
            < 90%    → rejected

        Args:
            image_bytes: Live photo bytes
            student_id: Database student ID

        Returns:
            {
                "tier": "present" | "manual_review" | "rejected",
                "match": bool,
                "confidence": float,
                "face_id": str | None,
                "message": str
            }
        """
        try:
            # Step 1: Detect face quality in submitted image
            detect_response = self.client.detect_faces(
                Image={"Bytes": image_bytes},
                Attributes=["DEFAULT"],
            )
            face_details = detect_response.get("FaceDetails", [])

            if not face_details:
                return {
                    "tier": "rejected",
                    "match": False,
                    "confidence": 0.0,
                    "face_id": None,
                    "message": "No face detected in submitted image",
                }

            if len(face_details) > 1:
                return {
                    "tier": "rejected",
                    "match": False,
                    "confidence": 0.0,
                    "face_id": None,
                    "message": "Multiple faces detected. Ensure only you are in frame.",
                }

            # Step 2: Search collection — threshold set low to capture all candidates
            logger.info(
                f"[AWS_SEARCH_FACES] Calling SearchFacesByImage: "
                f"CollectionId={self.collection_id}, "
                f"Image bytes size={len(image_bytes)} bytes, "
                f"FaceMatchThreshold={TIER_MANUAL_REVIEW}"
            )
            search_response = self.client.search_faces_by_image(
                CollectionId=self.collection_id,
                Image={"Bytes": image_bytes},
                MaxFaces=5,
                FaceMatchThreshold=TIER_MANUAL_REVIEW,  # 90% — we'll filter tiers ourselves
            )

            face_matches = search_response.get("FaceMatches", [])

            if not face_matches:
                logger.info("[AWS_SIMILARITY] SearchFacesByImage returned no matches.")
                return {
                    "tier": "rejected",
                    "match": False,
                    "confidence": 0.0,
                    "face_id": None,
                    "message": "Face does not match any registered student",
                }

            logger.info(
                f"[AWS_SIMILARITY] SearchFacesByImage returned {len(face_matches)} match(es):"
            )
            for m in face_matches:
                logger.info(
                    f"  - Match: FaceId={m['Face'].get('FaceId')}, "
                    f"ExternalImageId={m['Face'].get('ExternalImageId')}, "
                    f"Similarity={m['Similarity']:.2f}%"
                )

            # Step 3: Filter matches belonging to THIS student
            student_prefix = f"student_{student_id}"
            student_matches = [
                m for m in face_matches
                if m["Face"].get("ExternalImageId", "").startswith(student_prefix)
            ]

            if not student_matches:
                # Check if face matched another student (security concern)
                top_match = face_matches[0]
                other_id = top_match["Face"].get("ExternalImageId", "unknown")
                logger.warning(
                    f"[AWS_SIMILARITY] Security warning: Face matched a different registered student: {other_id} "
                    f"(Similarity={top_match['Similarity']:.2f}%)"
                )
                return {
                    "tier": "rejected",
                    "match": False,
                    "confidence": top_match["Similarity"],
                    "face_id": None,
                    "message": f"Face matched a different registered student",
                }

            # Take the best match for this student
            best = max(student_matches, key=lambda m: m["Similarity"])
            similarity = best["Similarity"]
            face_id = best["Face"]["FaceId"]

            # Step 4: Apply confidence tiers
            if similarity >= TIER_PRESENT:
                tier = "present"
                match = True
                message = f"Face verified ✅ ({similarity:.1f}% confidence)"
            elif similarity >= TIER_MANUAL_REVIEW:
                tier = "manual_review"
                match = True  # Allowed but flagged
                message = (
                    f"Face partially matched ({similarity:.1f}% confidence). "
                    "Attendance flagged for faculty review."
                )
            else:
                tier = "rejected"
                match = False
                message = (
                    f"Face confidence too low ({similarity:.1f}%). "
                    "Please ensure good lighting and look directly at camera."
                )

            logger.info(
                f"[AWS_SIMILARITY] Resolved similarity for student_id={student_id}: "
                f"similarity={similarity:.1f}%, face_id={face_id}, tier={tier}"
            )

            return {
                "tier": tier,
                "match": match,
                "confidence": similarity,
                "face_id": face_id,
                "message": message,
            }

        except self.client.exceptions.InvalidParameterException:
            return {
                "tier": "rejected",
                "match": False,
                "confidence": 0.0,
                "face_id": None,
                "message": "No face detected in image",
            }
        except ClientError as e:
            logger.error(f"Rekognition verify_face_with_tiers error: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Face verification failed. AWS error.",
            )

    # ─── Legacy: Verify face (single FaceId) ─────────────────
    def verify_face(self, image_bytes: bytes, student_face_id: str) -> dict:
        """
        Legacy face verification against a specific FaceId.
        Kept for backward compatibility with existing routes.

        Returns:
            dict with keys: match (bool), confidence (float), message (str)
        """
        try:
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
                    "message": (
                        f"Confidence {similarity:.1f}% below threshold "
                        f"{self.confidence_threshold}%"
                    ),
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

    # ─── Delete single face ───────────────────────────────────
    def delete_face(self, face_id: str) -> bool:
        """Remove a single registered face from the collection."""
        try:
            self.client.delete_faces(
                CollectionId=self.collection_id,
                FaceIds=[face_id],
            )
            return True
        except ClientError as e:
            logger.error(f"Failed to delete face {face_id}: {e}")
            return False

    # ─── v4: Delete all faces for a student ──────────────────
    def delete_student_faces(self, student_id: int) -> int:
        """
        Remove all indexed faces for a student from the collection.
        Uses ExternalImageId prefix search.

        Returns:
            Number of faces deleted
        """
        prefix = f"student_{student_id}"
        try:
            # List all faces with this student's prefix
            response = self.client.list_faces(
                CollectionId=self.collection_id,
                MaxResults=100,
            )
            all_faces = response.get("Faces", [])

            # Keep paging
            while response.get("NextToken"):
                response = self.client.list_faces(
                    CollectionId=self.collection_id,
                    MaxResults=100,
                    NextToken=response["NextToken"],
                )
                all_faces.extend(response.get("Faces", []))

            student_face_ids = [
                f["FaceId"]
                for f in all_faces
                if f.get("ExternalImageId", "").startswith(prefix)
            ]

            if not student_face_ids:
                logger.info(f"No Rekognition faces found for student {student_id}")
                return 0

            self.client.delete_faces(
                CollectionId=self.collection_id,
                FaceIds=student_face_ids,
            )
            count = len(student_face_ids)
            logger.info(
                f"Deleted {count} Rekognition face(s) for student {student_id}"
            )
            return count

        except ClientError as e:
            logger.error(
                f"Failed to delete student faces for student {student_id}: {e}"
            )
            return 0

    # ─── Delete faces by FaceId list ─────────────────────────
    def delete_faces(self, face_ids: list[str]) -> int:
        """
        Delete a list of specific Rekognition FaceIds from the collection.

        Used by DELETE /auth/face-reset when we already have the FaceIds
        stored in the student_faces table.

        Args:
            face_ids: List of Rekognition FaceId UUIDs

        Returns:
            Number of faces deleted
        """
        if not face_ids:
            return 0

        deleted = 0
        try:
            # Rekognition allows max 1000 FaceIds per delete call
            for i in range(0, len(face_ids), 1000):
                batch = face_ids[i : i + 1000]
                response = self.client.delete_faces(
                    CollectionId=self.collection_id,
                    FaceIds=batch,
                )
                deleted += len(response.get("DeletedFaces", []))

            logger.info(
                f"[REKOGNITION] Deleted {deleted} faces from collection"
            )
            return deleted

        except ClientError as e:
            logger.error(f"[REKOGNITION] delete_faces failed: {e}")
            return deleted  # Return partial count


# ─── Singleton ───────────────────────────────────────────────
rekognition_service = RekognitionService()
