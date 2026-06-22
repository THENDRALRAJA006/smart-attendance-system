# ============================================================
# SmartAttend - AWS Rekognition Service
# ============================================================

import os
import boto3
from botocore.exceptions import ClientError


class RekognitionService:
    def __init__(self):
        self.client = boto3.client(
            "rekognition",
            aws_access_key_id=os.getenv("AWS_ACCESS_KEY_ID"),
            aws_secret_access_key=os.getenv("AWS_SECRET_ACCESS_KEY"),
            region_name=os.getenv("AWS_REGION", "ap-south-1"),
        )

    def compare_faces(self, source_bytes, target_bytes, threshold=80):
        try:
            response = self.client.compare_faces(
                SourceImage={"Bytes": source_bytes},
                TargetImage={"Bytes": target_bytes},
                SimilarityThreshold=threshold,
            )

            matches = response.get("FaceMatches", [])

            if matches:
                similarity = matches[0]["Similarity"]

                return {
                    "matched": True,
                    "confidence": float(similarity),
                    "message": "Face matched successfully",
                }

            return {
                "matched": False,
                "confidence": 0,
                "message": "No face match found",
            }

        except ClientError as e:
            return {
                "matched": False,
                "confidence": 0,
                "message": str(e),
            }

    def detect_faces(self, image_bytes):
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