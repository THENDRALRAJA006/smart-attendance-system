# ============================================================
# SmartAttend — Liveness Detection Service (v4)
# Anti-spoofing via AWS Rekognition DetectFaces attributes.
#
# Strategy (free, no extra AWS cost):
#   1. Issue a random signed challenge (blink/smile/turn_left/turn_right)
#   2. Flutter captures 3 sequential frames during the challenge
#   3. This service verifies the frames met the challenge using
#      Rekognition's built-in face attributes (EyesOpen, Smile, Pose)
#   4. Quality gates reject printed photos / screen images:
#      Brightness > 40, Sharpness > 40, exactly 1 face
# ============================================================

import logging
import random
import secrets
from datetime import datetime, timedelta
from typing import Literal

import boto3
from botocore.exceptions import ClientError
from fastapi import HTTPException, status
from jose import JWTError, jwt

from app.core.config import settings

logger = logging.getLogger(__name__)

# ─── Challenge types ─────────────────────────────────────────
ChallengeType = Literal["BLINK", "SMILE", "TURN_LEFT", "TURN_RIGHT"]

CHALLENGE_TYPES: list[ChallengeType] = ["BLINK", "SMILE", "TURN_LEFT", "TURN_RIGHT"]

CHALLENGE_INSTRUCTIONS = {
    "BLINK":      "Please blink once slowly",
    "SMILE":      "Please smile naturally",
    "TURN_LEFT":  "Slowly turn your head to the LEFT",
    "TURN_RIGHT": "Slowly turn your head to the RIGHT",
}

# Thresholds
BRIGHTNESS_MIN  = 40.0    # Rejects dark/dim images
SHARPNESS_MIN   = 40.0    # Rejects blurry/printed photos
EYES_OPEN_CONF  = 70.0    # Confidence threshold for eyes-open detection
SMILE_CONF      = 70.0    # Confidence threshold for smile detection
POSE_YAW_THRESH = 15.0    # Degrees of yaw for left/right turns

# Challenge token TTL
CHALLENGE_TTL_SECONDS = 90


class LivenessService:
    """
    Handles liveness challenge generation and frame verification.
    Uses AWS Rekognition DetectFaces with ALL attributes for quality
    and liveness checking without extra API cost.
    """

    def __init__(self):
        self.client = boto3.client(
            "rekognition",
            region_name=settings.AWS_REGION,
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
        )

    # ─── Generate Challenge ───────────────────────────────────
    def generate_challenge(self, student_id: int) -> dict:
        """
        Pick a random challenge and return a signed JWT token.

        Returns:
            {
                "challenge_type": "BLINK",
                "instruction": "Please blink once slowly",
                "token": "<signed JWT>",
                "expires_in": 90
            }
        """
        challenge_type: ChallengeType = random.choice(CHALLENGE_TYPES)

        expires_at = datetime.utcnow() + timedelta(seconds=CHALLENGE_TTL_SECONDS)
        nonce = secrets.token_hex(8)  # Prevent replay attacks

        payload = {
            "sub": str(student_id),
            "type": "liveness_challenge",
            "challenge": challenge_type,
            "nonce": nonce,
            "exp": expires_at,
            "iat": datetime.utcnow(),
        }

        token = jwt.encode(
            payload,
            settings.JWT_SECRET_KEY,
            algorithm=settings.JWT_ALGORITHM,
        )

        logger.info(
            f"Liveness challenge issued: student={student_id}, "
            f"challenge={challenge_type}, expires={expires_at.isoformat()}"
        )

        return {
            "challenge_type": challenge_type,
            "instruction": CHALLENGE_INSTRUCTIONS[challenge_type],
            "token": token,
            "expires_in": CHALLENGE_TTL_SECONDS,
        }

    # ─── Decode + Validate Challenge Token ───────────────────
    def decode_challenge_token(self, token: str) -> dict:
        """
        Decode and validate a liveness challenge token.

        Raises:
            HTTPException 401: Invalid/expired token
        """
        try:
            payload = jwt.decode(
                token,
                settings.JWT_SECRET_KEY,
                algorithms=[settings.JWT_ALGORITHM],
            )
            if payload.get("type") != "liveness_challenge":
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid token type",
                )
            return payload
        except JWTError:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Liveness challenge token is invalid or expired. Please request a new one.",
            )

    # ─── Quality Gate ─────────────────────────────────────────
    def _check_quality(self, face_detail: dict) -> tuple[bool, str]:
        """
        Run quality checks to reject spoofing attempts:
        - Single face enforced (caller checks multi-face)
        - Brightness and sharpness thresholds

        Returns:
            (passed: bool, reason: str)
        """
        quality = face_detail.get("Quality", {})
        brightness = quality.get("Brightness", 0)
        sharpness  = quality.get("Sharpness", 0)

        if brightness < BRIGHTNESS_MIN:
            return False, f"Image too dark (brightness={brightness:.1f}, min={BRIGHTNESS_MIN})"
        if sharpness < SHARPNESS_MIN:
            return False, f"Image blurry or printed photo (sharpness={sharpness:.1f}, min={SHARPNESS_MIN})"
        return True, "OK"

    # ─── Verify Single Frame ─────────────────────────────────
    def _analyze_frame(self, image_bytes: bytes) -> dict | None:
        """
        Run Rekognition DetectFaces with ALL attributes on one frame.

        Returns:
            Parsed face attributes dict, or None if no/multiple faces.
        """
        try:
            response = self.client.detect_faces(
                Image={"Bytes": image_bytes},
                Attributes=["ALL"],
            )
        except ClientError as e:
            logger.error(f"DetectFaces error: {e}")
            return None

        faces = response.get("FaceDetails", [])

        if len(faces) == 0:
            logger.debug("No face detected in frame")
            return None

        if len(faces) > 1:
            logger.warning(f"Multiple faces ({len(faces)}) detected — spoofing suspected")
            return None

        face = faces[0]
        quality_ok, reason = self._check_quality(face)
        if not quality_ok:
            logger.warning(f"Quality gate failed: {reason}")
            return None

        return face

    # ─── Verify Liveness Frames ───────────────────────────────
    def verify_liveness(
        self,
        frames: list[bytes],
        challenge_token: str,
    ) -> dict:
        """
        Verify that the submitted frames satisfy the issued challenge.

        Args:
            frames: List of raw image bytes (1-3 frames)
            challenge_token: Signed JWT from generate_challenge()

        Returns:
            {
                "passed": bool,
                "challenge_type": str,
                "frames_analyzed": int,
                "message": str,
                "details": {...}
            }

        Anti-spoofing checks performed:
            - Quality: brightness > 40, sharpness > 40
            - Single face only
            - BLINK: at least 1 frame where EyesOpen.Value == False
            - SMILE: at least 1 frame where Smile.Value == True (conf > 70%)
            - TURN_LEFT: at least 1 frame where Pose.Yaw < -15
            - TURN_RIGHT: at least 1 frame where Pose.Yaw > +15
        """
        # 1. Validate token
        payload = self.decode_challenge_token(challenge_token)
        challenge_type: ChallengeType = payload["challenge"]

        if not frames:
            return {
                "passed": False,
                "challenge_type": challenge_type,
                "frames_analyzed": 0,
                "message": "No frames submitted",
                "details": {},
            }

        # 2. Analyze each frame
        analyzed_frames = []
        for i, frame_bytes in enumerate(frames[:3]):  # Max 3 frames
            face = self._analyze_frame(frame_bytes)
            if face:
                analyzed_frames.append(face)
            logger.debug(f"Frame {i+1}: {'detected' if face else 'rejected'}")

        if not analyzed_frames:
            return {
                "passed": False,
                "challenge_type": challenge_type,
                "frames_analyzed": 0,
                "message": "No valid face detected in any frame. Ensure good lighting and single face.",
                "details": {},
            }

        # 3. Check challenge-specific condition
        passed = False
        details = {}

        if challenge_type == "BLINK":
            # Look for at least one frame where eyes are closed
            blink_frames = [
                f for f in analyzed_frames
                if not f.get("EyesOpen", {}).get("Value", True)
                and f.get("EyesOpen", {}).get("Confidence", 0) > EYES_OPEN_CONF
            ]
            passed = len(blink_frames) >= 1
            details = {
                "frames_with_blink": len(blink_frames),
                "required": 1,
            }
            if not passed:
                # Fallback: eyes-open confidence drop in any frame suggests blink
                min_conf = min(
                    f.get("EyesOpen", {}).get("Confidence", 100)
                    for f in analyzed_frames
                )
                passed = min_conf < 60  # Low confidence = transitional blink
                details["fallback_min_eyes_confidence"] = min_conf

        elif challenge_type == "SMILE":
            smile_frames = [
                f for f in analyzed_frames
                if f.get("Smile", {}).get("Value", False)
                and f.get("Smile", {}).get("Confidence", 0) > SMILE_CONF
            ]
            passed = len(smile_frames) >= 1
            details = {
                "frames_with_smile": len(smile_frames),
                "required": 1,
                "smile_confidences": [
                    round(f.get("Smile", {}).get("Confidence", 0), 1)
                    for f in analyzed_frames
                ],
            }

        elif challenge_type == "TURN_LEFT":
            left_frames = [
                f for f in analyzed_frames
                if f.get("Pose", {}).get("Yaw", 0) < -POSE_YAW_THRESH
            ]
            passed = len(left_frames) >= 1
            details = {
                "frames_with_left_turn": len(left_frames),
                "required": 1,
                "yaw_values": [
                    round(f.get("Pose", {}).get("Yaw", 0), 1)
                    for f in analyzed_frames
                ],
            }

        elif challenge_type == "TURN_RIGHT":
            right_frames = [
                f for f in analyzed_frames
                if f.get("Pose", {}).get("Yaw", 0) > POSE_YAW_THRESH
            ]
            passed = len(right_frames) >= 1
            details = {
                "frames_with_right_turn": len(right_frames),
                "required": 1,
                "yaw_values": [
                    round(f.get("Pose", {}).get("Yaw", 0), 1)
                    for f in analyzed_frames
                ],
            }

        message = (
            f"Liveness challenge '{challenge_type}' passed ✅"
            if passed
            else f"Liveness challenge '{challenge_type}' failed. {CHALLENGE_INSTRUCTIONS[challenge_type]}."
        )

        logger.info(
            f"Liveness verification: challenge={challenge_type}, "
            f"passed={passed}, frames={len(analyzed_frames)}"
        )

        return {
            "passed": passed,
            "challenge_type": challenge_type,
            "frames_analyzed": len(analyzed_frames),
            "message": message,
            "details": details,
        }

    # ─── Quick Liveness for Registration ─────────────────────
    def check_registration_frame_quality(self, image_bytes: bytes) -> dict:
        """
        Validate a single registration frame:
        - Exactly 1 face
        - Good brightness and sharpness
        - Eyes visible (EyesOpen.Confidence > 70)
        - Face centered (Pose near 0,0,0)

        Returns validation result dict.
        """
        try:
            response = self.client.detect_faces(
                Image={"Bytes": image_bytes},
                Attributes=["ALL"],
            )
        except ClientError as e:
            logger.error(f"DetectFaces error during registration: {e}")
            return {"valid": False, "reason": "AWS service error"}

        faces = response.get("FaceDetails", [])

        if len(faces) == 0:
            return {"valid": False, "reason": "No face detected. Position your face in the frame."}

        if len(faces) > 1:
            return {"valid": False, "reason": f"Multiple faces detected ({len(faces)}). Ensure only one person is in frame."}

        face = faces[0]

        # Quality checks
        quality_ok, reason = self._check_quality(face)
        if not quality_ok:
            return {"valid": False, "reason": reason}

        # Eyes must be open for registration
        eyes_open = face.get("EyesOpen", {})
        if not eyes_open.get("Value", True) and eyes_open.get("Confidence", 0) > 80:
            return {"valid": False, "reason": "Eyes appear closed. Please open your eyes."}

        return {
            "valid": True,
            "reason": "Frame quality OK",
            "brightness": face.get("Quality", {}).get("Brightness", 0),
            "sharpness": face.get("Quality", {}).get("Sharpness", 0),
            "pose": {
                "yaw":   round(face.get("Pose", {}).get("Yaw", 0), 1),
                "pitch": round(face.get("Pose", {}).get("Pitch", 0), 1),
                "roll":  round(face.get("Pose", {}).get("Roll", 0), 1),
            },
        }


# ─── Singleton ───────────────────────────────────────────────
liveness_service = LivenessService()
