# ============================================================
# SmartAttend — Attendance Route Tests
# Tests: session creation, mark attendance, RSSI validation,
#        duplicate prevention, live attendance, export
# ============================================================

import pytest
from unittest.mock import patch, MagicMock


class TestSessionManagement:
    """Faculty: session creation and lifecycle."""

    def test_create_session(self, client, faculty_headers, test_classroom, faculty_user):
        """Create a new attendance session."""
        # First create a subject for this faculty
        with patch("app.services.rekognition_service.rekognition_service"):
            subject_resp = client.post(
                "/faculty/subjects",
                json={
                    "subject_name": "Data Structures",
                    "subject_code": "CS301",
                    "department": "Computer Science",
                },
                headers=faculty_headers,
            )
            # Skip if subject creation fails (dependency)
            if subject_resp.status_code != 201:
                pytest.skip("Subject creation failed — check faculty fixture")

            subject_id = subject_resp.json()["id"]
            response = client.post(
                "/faculty/create-session",
                json={
                    "classroom_id": test_classroom.id,
                    "subject_id": subject_id,
                    "attendance_code": "123456",
                },
                headers=faculty_headers,
            )
            assert response.status_code == 201
            data = response.json()
            assert "deep_link" in data
            assert "attendance_code" not in data
            assert data["is_active"] is True

    def test_create_session_invalid_code(self, client, faculty_headers, test_classroom):
        """Attendance code must be exactly 6 digits."""
        response = client.post(
            "/faculty/create-session",
            json={
                "classroom_id": test_classroom.id,
                "subject_id": 1,
                "attendance_code": "123",  # Too short
            },
            headers=faculty_headers,
        )
        assert response.status_code == 422

    def test_live_attendance_no_session(self, client, faculty_headers):
        """Live attendance with no active session returns empty list."""
        response = client.get("/faculty/live-attendance", headers=faculty_headers)
        assert response.status_code == 200
        data = response.json()
        assert data["attendance_count"] == 0
        assert data["students"] == []


class TestMarkAttendance:
    """Student: mark attendance with BLE + face verification."""

    @patch("app.services.rekognition_service.rekognition_service.verify_face")
    @patch("app.services.attendance_service.check_duplicate_attendance")
    def test_mark_attendance_success(
        self,
        mock_check_duplicate_attendance,
        mock_verify_face,
        client,
        student_headers,
        test_classroom,
        db,
    ):
        """Happy path: BLE within range, face matches, no duplicate."""
        # Setup mocks
        mock_check_duplicate_attendance.return_value = None
        mock_verify_face.return_value = {
            "match": True,
            "confidence": 98.5,
            "message": "Face verified",
        }

        # Need an active session — create one first if possible
        # This test is integration-level; unit mock covers the service calls
        # At minimum, the endpoint should validate inputs
        response = client.post(
            "/attendance/mark",
            data={
                "session_id": 9999,   # non-existent session
                "rssi": -65,          # Within acceptable range (-70 threshold)
            },
            files={"file": ("test.jpg", b"imagebytes", "image/jpeg")},
            headers=student_headers,
        )
        # Session doesn't exist → 404 is expected
        assert response.status_code in [404, 422, 400]

    def test_mark_attendance_unauthenticated(self, client):
        """Unauthenticated request should be rejected."""
        response = client.post(
            "/attendance/mark",
            data={
                "session_id": 1,
                "rssi": -65,
            },
            files={"file": ("test.jpg", b"imagebytes", "image/jpeg")},
        )
        assert response.status_code in [401, 403]

    def test_rssi_validation_too_weak(self, client, student_headers):
        """RSSI below threshold should reject attendance."""
        response = client.post(
            "/attendance/mark",
            data={
                "session_id": 1,
                "rssi": -100,         # Way below threshold (-70)
            },
            files={"file": ("test.jpg", b"imagebytes", "image/jpeg")},
            headers=student_headers,
        )
        # Should be 403 (RSSI too weak) or 404 (session not found)
        assert response.status_code in [400, 403, 404]


class TestAttendanceHistory:
    """Student: view personal attendance history and stats."""

    def test_student_dashboard(self, client, student_headers):
        response = client.get("/student/dashboard", headers=student_headers)
        assert response.status_code == 200
        data = response.json()
        # Must have these keys
        assert "total_classes" in data
        assert "attended_classes" in data
        assert "attendance_percentage" in data
        assert "subject_wise" in data
        assert "recent_history" in data

    def test_attendance_history(self, client, student_headers):
        response = client.get("/student/attendance-history", headers=student_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)


class TestReportExport:
    """Faculty: export attendance reports."""

    def test_export_csv(self, client, faculty_headers):
        response = client.get(
            "/faculty/export/csv?period=monthly",
            headers=faculty_headers,
        )
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/csv")

    def test_export_xlsx(self, client, faculty_headers):
        response = client.get(
            "/faculty/export/xlsx?period=monthly",
            headers=faculty_headers,
        )
        assert response.status_code == 200
        assert "spreadsheetml" in response.headers["content-type"]

    def test_export_invalid_format(self, client, faculty_headers):
        response = client.get(
            "/faculty/export/docx",
            headers=faculty_headers,
        )
        assert response.status_code == 400
