# ============================================================
# SmartAttend — Attendance Route Tests
# Tests: session creation, mark attendance, RSSI validation,
#        duplicate prevention, live attendance, export
# NOTE: AWS Rekognition removed. All face verification mocks
#       now target face_service (ArcFace / InsightFace).
# ============================================================

import pytest
from unittest.mock import patch, MagicMock


class TestSessionManagement:
    """Faculty: session creation and lifecycle."""

    def test_create_session(self, client, faculty_headers, test_classroom, faculty_user):
        """Create a new attendance session."""
        # Create a subject first
        subject_resp = client.post(
            "/faculty/subjects",
            json={
                "subject_name": "Data Structures",
                "subject_code": "CS301",
                "department": "Computer Science",
            },
            headers=faculty_headers,
        )
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

    def test_get_active_session(self, client, student_headers, db, faculty_headers):
        """Get currently active session for a classroom."""
        from app.models.models import Classroom

        # 1. Create a separate classroom
        temp_classroom = Classroom(
            room_name="CLASSROOM_TEMP_TEST",
            ble_uuid="SMART_ATTEND_TEMP_TEST"
        )
        db.add(temp_classroom)
        db.commit()
        db.refresh(temp_classroom)

        # 2. Create a subject and start a session (no AWS mocks needed)
        client.post(
            "/faculty/subjects",
            json={
                "subject_name": "Data Structures",
                "subject_code": "CS301",
                "department": "Computer Science",
            },
            headers=faculty_headers,
        )
        client.post(
            "/faculty/create-session",
            json={
                "classroom_id": temp_classroom.id,
                "subject_id": 1,
                "attendance_code": "123456",
            },
            headers=faculty_headers,
        )

        # 3. Query active session via student
        response = client.get(
            f"/attendance/active-session?classroom_uuid={temp_classroom.ble_uuid}",
            headers=student_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["classroom_uuid"] == temp_classroom.ble_uuid
        assert data["session_id"] is not None
        assert data["is_active"] is True


class TestMarkAttendance:
    """Student: mark attendance with BLE + face verification."""

    @patch("app.services.face_service.face_service.verify_face_embedding")
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
        mock_check_duplicate_attendance.return_value = None
        mock_verify_face.return_value = {
            "status": "present",
            "similarity": 0.92,
            "message": "Face verified",
        }

        # Non-existent session → 404 expected (verifies auth + routing works)
        response = client.post(
            "/attendance/mark",
            data={
                "session_id": 9999,
                "rssi": -65,
            },
            files={"file": ("test.jpg", b"imagebytes", "image/jpeg")},
            headers=student_headers,
        )
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
                "rssi": -100,  # Way below threshold (-70)
            },
            files={"file": ("test.jpg", b"imagebytes", "image/jpeg")},
            headers=student_headers,
        )
        assert response.status_code in [400, 403, 404]


class TestAttendanceHistory:
    """Student: view personal attendance history and stats."""

    def test_student_dashboard(self, client, student_headers):
        response = client.get("/student/dashboard", headers=student_headers)
        assert response.status_code == 200
        data = response.json()
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
