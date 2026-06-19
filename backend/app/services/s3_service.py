# ============================================================
# SmartAttend — AWS S3 Service
# Face image storage and retrieval
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

    All face images are stored under:
        s3://<bucket>/<prefix>/student_<id>.jpg
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

    # ─── Upload Face Image ───────────────────────────────────
    def upload_face_image(self, image_bytes: bytes, student_id: int) -> str:
        """
        Upload a student's face image to S3.

        Args:
            image_bytes: Raw JPEG/PNG image bytes
            student_id: Database student ID

        Returns:
            Public S3 URL of the uploaded image

        Raises:
            HTTPException: If upload fails
        """
        key = f"{self.prefix}/student_{student_id}.jpg"

        try:
            self.client.put_object(
                Bucket=self.bucket,
                Key=key,
                Body=image_bytes,
                ContentType="image/jpeg",
                # Object is private by default — access via presigned URL
            )

            # Return the S3 URI (not public URL — use presigned for display)
            s3_url = f"s3://{self.bucket}/{key}"
            logger.info(f"Uploaded face image for student {student_id}: {s3_url}")
            return s3_url

        except ClientError as e:
            logger.error(f"S3 upload failed for student {student_id}: {e}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Failed to upload face image to storage",
            )

    # ─── Get Presigned URL ───────────────────────────────────
    def get_presigned_url(self, student_id: int, expires_in: int = 3600) -> str | None:
        """
        Generate a time-limited presigned URL to view the face image.

        Args:
            student_id: Database student ID
            expires_in: URL validity in seconds (default 1 hour)

        Returns:
            Presigned URL string, or None if object doesn't exist
        """
        key = f"{self.prefix}/student_{student_id}.jpg"

        try:
            url = self.client.generate_presigned_url(
                "get_object",
                Params={"Bucket": self.bucket, "Key": key},
                ExpiresIn=expires_in,
            )
            return url
        except ClientError as e:
            logger.warning(f"Could not generate presigned URL for student {student_id}: {e}")
            return None

    # ─── Delete Face Image ───────────────────────────────────
    def delete_face_image(self, student_id: int) -> bool:
        """
        Delete a student's face image from S3.

        Args:
            student_id: Database student ID

        Returns:
            True if deleted, False on error
        """
        key = f"{self.prefix}/student_{student_id}.jpg"

        try:
            self.client.delete_object(Bucket=self.bucket, Key=key)
            logger.info(f"Deleted face image for student {student_id}")
            return True
        except ClientError as e:
            logger.error(f"Failed to delete face image for student {student_id}: {e}")
            return False

    # ─── Ensure Bucket Exists ────────────────────────────────
    def ensure_bucket(self) -> None:
        """
        Verify the S3 bucket exists and is accessible.
        Called during app startup.
        """
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


# ─── Singleton ───────────────────────────────────────────────
s3_service = S3Service()
