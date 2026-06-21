# ============================================================
# SmartAttend — AWS S3 Service (v4)
# Face image storage — supports 15-pose folder structure
#
# Folder layout (v4):
#   students/{student_id}/face_{pose_index:02d}.jpg  ← 15 guided poses
#   faces/student_{student_id}.jpg                   ← legacy single-image
# ============================================================

import io
import logging
from botocore.exceptions import ClientError
import boto3
from fastapi import HTTPException, status
from app.core.config import settings

logger = logging.getLogger(__name__)


class S3Service:
    """
    Handles face image storage in AWS S3.

    v4 adds multi-pose support:
      - upload_face_image_pose() for each of the 15 guided poses
      - delete_all_poses() to wipe all 15 images when re-registering
      - list_pose_images() to enumerate a student's uploaded poses
    """

    def __init__(self):
        self.client = boto3.client(
            "s3",
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )
        self.bucket = settings.S3_BUCKET_NAME
        self.prefix = settings.S3_FACE_PREFIX

    # ─── v4: Upload one pose image ───────────────────────────
    def upload_face_image_pose(
        self, image_bytes: bytes, student_id: int, pose_index: int
    ) -> tuple[str, str]:
        """
        Upload a single guided-pose image to S3.

        Key format: students/{student_id}/face_{pose_index:02d}.jpg

        Args:
            image_bytes: Raw JPEG image bytes
            student_id: Database student ID
            pose_index: 1-15 (pose sequence number)

        Returns:
            (s3_key, s3_url) tuple
        """
        key = f"students/{student_id}/face_{pose_index:02d}.jpg"

        try:
            self.client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=image_bytes,
                ContentType="image/jpeg",
            )
            s3_url = f"s3://{self.bucket}/{key}"
            logger.info(
                f"Uploaded pose {pose_index} for student {student_id}: {s3_url}"
            )
            return key, s3_url

        except ClientError as e:
            logger.error(
                f"S3 upload failed: student={student_id}, pose={pose_index}: {e}"
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Failed to upload pose {pose_index} to storage",
            )

    # ─── v4: Delete all 15 pose images for a student ─────────
    def delete_all_poses(self, student_id: int) -> int:
        """
        Delete all pose images under students/{student_id}/.

        Returns:
            Number of objects deleted
        """
        prefix = f"students/{student_id}/"
        try:
            paginator = self.client.get_paginator("list_objects_v2")
            pages = paginator.paginate(Bucket=self.bucket, Prefix=prefix)

            objects_to_delete = []
            for page in pages:
                for obj in page.get("Contents", []):
                    objects_to_delete.append({"Key": obj["Key"]})

            if not objects_to_delete:
                logger.info(f"No pose images found for student {student_id}")
                return 0

            self.client.delete_objects(
                Bucket=self.bucket,
                Delete={"Objects": objects_to_delete, "Quiet": True},
            )
            count = len(objects_to_delete)
            logger.info(f"Deleted {count} pose images for student {student_id}")
            return count

        except ClientError as e:
            logger.error(f"Failed to delete poses for student {student_id}: {e}")
            return 0

    # ─── v4: Get presigned URL for one pose ──────────────────
    def get_pose_presigned_url(
        self, student_id: int, pose_index: int, expires_in: int = 3600
    ) -> str | None:
        """Generate time-limited presigned URL for a specific pose image."""
        key = f"students/{student_id}/face_{pose_index:02d}.jpg"
        try:
            url = self.client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": key},
                ExpiresIn=expires_in,
            )
            return url
        except ClientError as e:
            logger.warning(
                f"Could not presign pose URL: student={student_id}, pose={pose_index}: {e}"
            )
            return None

    # ─── v4: List all uploaded poses ─────────────────────────
    def list_pose_images(self, student_id: int) -> list[dict]:
        """
        List all uploaded pose images for a student.

        Returns:
            List of {key, url, pose_index} dicts sorted by pose_index
        """
        prefix = f"students/{student_id}/"
        try:
            response = self.client.list_objects_v2(
                Bucket=self.bucket, Prefix=prefix
            )
            items = []
            for obj in response.get("Contents", []):
                key = obj["Key"]
                filename = key.split("/")[-1]
                try:
                    pose_index = int(
                        filename.replace("face_", "").replace(".jpg", "")
                    )
                except ValueError:
                    pose_index = 0
                items.append({
                    "key": key,
                    "url": f"s3://{self.bucket}/{key}",
                    "pose_index": pose_index,
                })
            return sorted(items, key=lambda x: x["pose_index"])
        except ClientError as e:
            logger.error(f"Failed to list poses for student {student_id}: {e}")
            return []

    # ─── Legacy: Upload single face image (backward compat) ──
    def upload_face_image(self, image_bytes: bytes, student_id: int) -> str:
        """
        Upload single face image to legacy path: faces/student_{id}.jpg
        Kept for backward compatibility.
        """
        key = f"{self.prefix}/student_{student_id}.jpg"
        try:
            self.client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=image_bytes,
                ContentType="image/jpeg",
            )
            s3_url = f"s3://{self.bucket}/{key}"
            logger.info(
                f"Uploaded legacy face image for student {student_id}: {s3_url}"
            )
            return s3_url
        except ClientError as e:
            logger.error(f"S3 upload failed for student {student_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Failed to upload face image to storage",
            )

    # ─── Legacy: Get Presigned URL ───────────────────────────
    def get_presigned_url(self, student_id: int, expires_in: int = 3600) -> str | None:
        """Generate presigned URL for legacy single face image."""
        key = f"{self.prefix}/student_{student_id}.jpg"
        try:
            url = self.client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": key},
                ExpiresIn=expires_in,
            )
            return url
        except ClientError as e:
            logger.warning(
                f"Could not generate presigned URL for student {student_id}: {e}"
            )
            return None

    # ─── Legacy: Delete single face image ────────────────────
    def delete_face_image(self, student_id: int) -> bool:
        """Delete legacy single face image."""
        key = f"{self.prefix}/student_{student_id}.jpg"
        try:
            self.client.delete_object(Bucket=self.bucket, Key=key)
            logger.info(f"Deleted legacy face image for student {student_id}")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete face image for student {student_id}: {e}")
            return False

    # ─── Ensure Bucket Exists ────────────────────────────────
    def ensure_bucket(self) -> None:
        """Verify the S3 bucket exists and is accessible. Called on startup."""
        try:
            self.client.head_bucket(Bucket=self.bucket)
            logger.info(f"✅ S3 bucket accessible: {self.bucket}")
        except ClientError as e:
            error_code = e.response["Error"]["Code"]
            if error_code == "404":
                logger.error(f"S3 bucket not found: {self.bucket}")
                raise HTTPException(
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                    detail=f"S3 bucket '{self.bucket}' not found",
                )
            logger.warning(f"S3 bucket check warning: {e}")

    # ─── v4: Delete all pose images for a student ───────────
    def delete_student_folder(self, student_id: int) -> int:
        """
        Delete all images under the students/{student_id}/ prefix in S3.

        Used by DELETE /auth/face-reset.

        Returns:
            Number of objects deleted
        """
        prefix = f"students/{student_id}/"
        try:
            # List all objects under the student prefix
            response = self.client.list_objects_v2(
                Bucket=self.bucket, Prefix=prefix
            )
            objects = response.get("Contents", [])

            # Paginate if needed
            while response.get("IsTruncated"):
                response = self.client.list_objects_v2(
                    Bucket=self.bucket,
                    Prefix=prefix,
                    ContinuationToken=response["NextContinuationToken"],
                )
                objects.extend(response.get("Contents", []))

            if not objects:
                logger.info(f"[S3] No images found for student {student_id}")
                return 0

            # Batch delete (max 1000 per call)
            deleted = 0
            for i in range(0, len(objects), 1000):
                batch = objects[i : i + 1000]
                self.client.delete_objects(
                    Bucket=self.bucket,
                    Delete={"Objects": [{"Key": obj["Key"]} for obj in batch]},
                )
                deleted += len(batch)

            logger.info(
                f"[S3] Deleted {deleted} images for student_id={student_id}"
            )
            return deleted

        except ClientError as e:
            logger.error(
                f"[S3] Failed to delete student folder for student_id={student_id}: {e}"
            )
            return 0


# ─── Singleton ───────────────────────────────────────────────
s3_service = S3Service()
