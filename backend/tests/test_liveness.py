"""
SmartAttend — Backend Tests: Liveness Service (v4)

Run with:
    pytest backend/tests/test_liveness.py -v

Tests cover:
  - generate_challenge(): valid structure and token
  - check_registration_frame_quality(): mock Rekognition responses
  - verify_liveness(): BLINK / SMILE / TURN_LEFT / TURN_RIGHT challenges
  - Token expiry and tamper detection
  - Edge cases: empty frames, bad images, multi-face
"""

import pytest
import time
from unittest.mock import patch, MagicMock
from jose import jwt

from app.services.liveness_service import liveness_service, ChallengeType, CHALLENGE_TTL_SECONDS
from app.core.config import settings


# ─── Fixtures ─────────────────────────────────────────────────

FAKE_STUDENT_ID = 42
FAKE_IMAGE_BYTES = b"\xff\xd8\xff\xe0"  # Minimal JPEG header stub


def _make_face_detail(
    brightness: float = 80.0,
    sharpness: float = 75.0,
    eyes_open_conf: float = 99.0,
    smile_conf: float = 10.0,
    yaw: float = 0.0,
    face_count: int = 1,
) -> dict:
    """Build a mocked Rekognition DetectFaces response."""
    face = {
        "Quality": {
            "Brightness": brightness,
            "Sharpness":  sharpness,
        },
        "EyesOpen": {"Confidence": eyes_open_conf, "Value": eyes_open_conf > 50},
        "Eyeglasses": {"Confidence": 10.0, "Value": False},
        "Smile":    {"Confidence": smile_conf, "Value": smile_conf > 50},
        "Pose":     {"Yaw": yaw, "Roll": 0.0, "Pitch": 0.0},
    }
    return {
        "FaceDetails": [face] * face_count,
        "ResponseMetadata": {"HTTPStatusCode": 200},
    }


# ═══════════════════════════════════════════════════════════════
# 1. generate_challenge
# ═══════════════════════════════════════════════════════════════

class TestGenerateChallenge:
    def test_returns_valid_structure(self):
        result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
        assert "challenge_type" in result
        assert "instruction" in result
        assert "token" in result
        assert "expires_in" in result
        assert result["expires_in"] == CHALLENGE_TTL_SECONDS

    def test_challenge_type_is_valid(self):
        valid_types = {"BLINK", "SMILE", "TURN_LEFT", "TURN_RIGHT"}
        for _ in range(20):  # Multiple runs to catch randomness
            result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
            assert result["challenge_type"] in valid_types

    def test_token_is_decodable(self):
        result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
        # Decode raw JWT to inspect payload
        payload = jwt.decode(
            result["token"],
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        assert payload["sub"] == str(FAKE_STUDENT_ID)  # sub is stored as str
        assert "challenge" in payload
        assert "exp" in payload

    def test_token_includes_student_id(self):
        result = liveness_service.generate_challenge(123)
        payload = jwt.decode(
            result["token"],
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        assert payload["sub"] == "123"  # stored as str

    def test_instruction_is_non_empty(self):
        result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
        assert len(result["instruction"]) > 5


# ═══════════════════════════════════════════════════════════════
# 2. check_registration_frame_quality
# ═══════════════════════════════════════════════════════════════

class TestRegistrationFrameQuality:
    def _run_quality_check(self, rekognition_response: dict) -> dict:
        with patch.object(
            liveness_service,
            "client",  # The boto3 client attribute on LivenessService
        ) as mock_client:
            mock_client.detect_faces.return_value = rekognition_response
            return liveness_service.check_registration_frame_quality(FAKE_IMAGE_BYTES)

    def test_good_image_passes(self):
        resp = _make_face_detail(brightness=85, sharpness=80)
        result = self._run_quality_check(resp)
        assert result["valid"] is True

    def test_no_face_fails(self):
        resp = {"FaceDetails": [], "ResponseMetadata": {"HTTPStatusCode": 200}}
        result = self._run_quality_check(resp)
        assert result["valid"] is False
        assert "face" in result["reason"].lower()

    def test_multiple_faces_fails(self):
        resp = _make_face_detail(face_count=2)
        result = self._run_quality_check(resp)
        assert result["valid"] is False
        assert "multiple" in result["reason"].lower()

    def test_low_brightness_fails(self):
        resp = _make_face_detail(brightness=20, sharpness=80)
        result = self._run_quality_check(resp)
        assert result["valid"] is False
        assert "bright" in result["reason"].lower() or "dark" in result["reason"].lower()

    def test_low_sharpness_fails(self):
        resp = _make_face_detail(brightness=80, sharpness=15)
        result = self._run_quality_check(resp)
        assert result["valid"] is False
        assert "blur" in result["reason"].lower() or "sharp" in result["reason"].lower() or "print" in result["reason"].lower()

    def test_returns_quality_scores(self):
        resp = _make_face_detail(brightness=85, sharpness=80)
        result = self._run_quality_check(resp)
        assert result["brightness"] == 85.0
        assert result["sharpness"] == 80.0


# ═══════════════════════════════════════════════════════════════
# 3. verify_liveness — individual challenge types
# ═══════════════════════════════════════════════════════════════

class TestVerifyLiveness:
    def _get_token(self, challenge_type: str) -> str:
        """Generate a real signed token for a specific challenge type."""
        payload = {
            "sub": str(FAKE_STUDENT_ID),  # service stores as str
            "type": "liveness_challenge",  # required by decode_challenge_token
            "challenge": challenge_type,
            "exp": int(time.time()) + CHALLENGE_TTL_SECONDS,
        }
        return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")

    def _mock_frames(self, count: int) -> list[bytes]:
        """Return dummy bytes for each frame."""
        return [FAKE_IMAGE_BYTES] * count

    def _run_verify(
        self, challenge_type: str, detect_responses: list[dict]
    ) -> dict:
        token = self._get_token(challenge_type)
        frames = self._mock_frames(len(detect_responses))
        responses_iter = iter(detect_responses)

        with patch.object(
            liveness_service,
            "client",  # boto3 client on LivenessService
        ) as mock_client:
            mock_client.detect_faces.side_effect = lambda **_: next(responses_iter)
            return liveness_service.verify_liveness(
                frames=frames, challenge_token=token
            )

    # ── BLINK ──────────────────────────────────────────
    def test_blink_passes_when_eyes_closed_in_one_frame(self):
        responses = [
            _make_face_detail(eyes_open_conf=10.0),  # eyes closed in frame 1
            _make_face_detail(eyes_open_conf=99.0),
            _make_face_detail(eyes_open_conf=99.0),
        ]
        result = self._run_verify("BLINK", responses)
        assert result["passed"] is True
        assert result["challenge_type"] == "BLINK"

    def test_blink_fails_when_eyes_always_open(self):
        responses = [
            _make_face_detail(eyes_open_conf=98.0),
            _make_face_detail(eyes_open_conf=97.0),
            _make_face_detail(eyes_open_conf=96.0),
        ]
        result = self._run_verify("BLINK", responses)
        assert result["passed"] is False

    # ── SMILE ──────────────────────────────────────────
    def test_smile_passes_when_smiling_in_one_frame(self):
        responses = [
            _make_face_detail(smile_conf=5.0),
            _make_face_detail(smile_conf=85.0),  # smiling
            _make_face_detail(smile_conf=10.0),
        ]
        result = self._run_verify("SMILE", responses)
        assert result["passed"] is True
        assert result["challenge_type"] == "SMILE"

    def test_smile_fails_when_not_smiling(self):
        responses = [
            _make_face_detail(smile_conf=20.0),
            _make_face_detail(smile_conf=25.0),
            _make_face_detail(smile_conf=15.0),
        ]
        result = self._run_verify("SMILE", responses)
        assert result["passed"] is False

    # ── TURN_LEFT ──────────────────────────────────────
    def test_turn_left_passes_when_yaw_negative(self):
        responses = [
            _make_face_detail(yaw=0.0),
            _make_face_detail(yaw=-20.0),   # turned left
            _make_face_detail(yaw=-5.0),
        ]
        result = self._run_verify("TURN_LEFT", responses)
        assert result["passed"] is True
        assert result["challenge_type"] == "TURN_LEFT"

    def test_turn_left_fails_when_facing_forward(self):
        responses = [
            _make_face_detail(yaw=0.0),
            _make_face_detail(yaw=2.0),
            _make_face_detail(yaw=-5.0),  # not enough
        ]
        result = self._run_verify("TURN_LEFT", responses)
        assert result["passed"] is False

    # ── TURN_RIGHT ─────────────────────────────────────
    def test_turn_right_passes_when_yaw_positive(self):
        responses = [
            _make_face_detail(yaw=0.0),
            _make_face_detail(yaw=22.0),   # turned right
            _make_face_detail(yaw=5.0),
        ]
        result = self._run_verify("TURN_RIGHT", responses)
        assert result["passed"] is True

    def test_turn_right_fails_when_facing_forward(self):
        responses = [
            _make_face_detail(yaw=0.0),
            _make_face_detail(yaw=5.0),   # not enough
            _make_face_detail(yaw=8.0),
        ]
        result = self._run_verify("TURN_RIGHT", responses)
        assert result["passed"] is False


# ═══════════════════════════════════════════════════════════════
# 4. Token edge cases
# ═══════════════════════════════════════════════════════════════

class TestTokenEdgeCases:
    def test_expired_token_fails(self):
        """Expired token raises HTTPException(401) — decode_challenge_token rejects it."""
        from fastapi import HTTPException as FastAPIHTTPException
        payload = {
            "sub": str(FAKE_STUDENT_ID),
            "type": "liveness_challenge",
            "challenge": "BLINK",
            "exp": int(time.time()) - 5,  # already expired
        }
        expired_token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        frames = [FAKE_IMAGE_BYTES] * 3

        with patch.object(liveness_service, "client") as mock_client:
            mock_client.detect_faces.return_value = _make_face_detail(eyes_open_conf=10.0)
            with pytest.raises(FastAPIHTTPException) as exc_info:
                liveness_service.verify_liveness(
                    frames=frames, challenge_token=expired_token
                )
        # Verify it's a 401 Unauthorized
        assert exc_info.value.status_code == 401
        assert "expired" in exc_info.value.detail.lower() or "invalid" in exc_info.value.detail.lower()

    def test_tampered_token_fails(self):
        """Tampered token raises HTTPException(401) — signature verification fails."""
        from fastapi import HTTPException as FastAPIHTTPException
        result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
        tampered = result["token"] + "tampered"

        with patch.object(liveness_service, "client") as mock_client:
            mock_client.detect_faces.return_value = _make_face_detail()
            with pytest.raises(FastAPIHTTPException) as exc_info:
                liveness_service.verify_liveness(
                    frames=[FAKE_IMAGE_BYTES],
                    challenge_token=tampered,
                )
        assert exc_info.value.status_code == 401

    def test_empty_frames_fails(self):
        result = liveness_service.generate_challenge(FAKE_STUDENT_ID)
        res = liveness_service.verify_liveness(
            frames=[],
            challenge_token=result["token"],
        )
        assert res["passed"] is False
        assert "frame" in res["message"].lower() or res["frames_analyzed"] == 0

    def test_quality_gate_rejects_dark_frame(self):
        """Frames that fail brightness check should not pass liveness."""
        # Build a token that works
        payload = {
            "sub": str(FAKE_STUDENT_ID),
            "type": "liveness_challenge",
            "challenge": "BLINK",
            "exp": int(time.time()) + CHALLENGE_TTL_SECONDS,
        }
        token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm="HS256")
        dark_response = _make_face_detail(brightness=15, sharpness=70)

        with patch.object(liveness_service, "client") as mock_client:
            mock_client.detect_faces.return_value = dark_response
            result = liveness_service.verify_liveness(
                frames=[FAKE_IMAGE_BYTES] * 3,
                challenge_token=token,
            )
        # Dark images = likely printed/spoofed photo → frames rejected → no analyzed frames
        assert result["passed"] is False
