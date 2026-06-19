# ============================================================
# SmartAttend — Admin Route Tests
# Tests: dashboard, CRUD for students/faculty/classrooms/subjects,
#        analytics, system-wide export
# ============================================================

import pytest


class TestAdminDashboard:
    """GET /admin/dashboard"""

    def test_dashboard_success(self, client, admin_headers):
        response = client.get("/admin/dashboard", headers=admin_headers)
        assert response.status_code == 200
        data = response.json()
        assert "total_students" in data
        assert "total_faculty" in data
        assert "total_departments" in data
        assert "total_classrooms" in data
        assert "system_attendance_rate" in data

    def test_dashboard_requires_admin(self, client, student_headers):
        """Students cannot access admin endpoints."""
        response = client.get("/admin/dashboard", headers=student_headers)
        assert response.status_code in [401, 403]


class TestStudentCRUD:
    """Admin: manage student accounts."""

    def test_list_students(self, client, admin_headers):
        response = client.get("/admin/students", headers=admin_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_get_student_by_id(self, client, admin_headers, student_user):
        response = client.get(
            f"/admin/students/{student_user.id}",
            headers=admin_headers,
        )
        assert response.status_code == 200
        data = response.json()
        assert data["email"] == "student@test.com"

    def test_get_student_not_found(self, client, admin_headers):
        response = client.get("/admin/students/99999", headers=admin_headers)
        assert response.status_code == 404

    def test_delete_student(self, client, admin_headers):
        """Create then delete a student."""
        # Create
        create_resp = client.post("/auth/register", json={
            "name": "Delete Me",
            "reg_no": "DELETE001",
            "department": "CS",
            "year": 1,
            "section": "A",
            "email": "deleteme@test.com",
            "password": "Password@123",
        })
        if create_resp.status_code != 201:
            pytest.skip("Could not create student for delete test")

        student_id = create_resp.json()["user"]["id"]
        response = client.delete(
            f"/admin/students/{student_id}",
            headers=admin_headers,
        )
        assert response.status_code in [200, 204]


class TestFacultyCRUD:
    """Admin: manage faculty accounts."""

    def test_list_faculty(self, client, admin_headers):
        response = client.get("/admin/faculty", headers=admin_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_create_faculty(self, client, admin_headers):
        response = client.post("/admin/faculty", json={
            "name": "New Faculty",
            "email": "newfaculty@test.com",
            "password": "Faculty@1234",
        }, headers=admin_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["email"] == "newfaculty@test.com"

    def test_create_faculty_duplicate_email(self, client, admin_headers, faculty_user):
        response = client.post("/admin/faculty", json={
            "name": "Duplicate",
            "email": "faculty@test.com",  # Already exists in fixture
            "password": "Faculty@1234",
        }, headers=admin_headers)
        assert response.status_code == 409


class TestClassroomCRUD:
    """Admin: manage classrooms."""

    def test_list_classrooms(self, client, admin_headers):
        response = client.get("/admin/classrooms", headers=admin_headers)
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_create_classroom(self, client, admin_headers):
        response = client.post("/admin/classrooms", json={
            "room_name": "CLASSROOM_B202",
            "ble_uuid": "B2B2B2B2-C3C3-D4D4-E5E5-F6F6F6F6F6F6",
        }, headers=admin_headers)
        assert response.status_code == 201
        data = response.json()
        assert data["room_name"] == "CLASSROOM_B202"


class TestAnalytics:
    """GET /admin/analytics"""

    def test_analytics_structure(self, client, admin_headers):
        response = client.get("/admin/analytics", headers=admin_headers)
        assert response.status_code == 200
        data = response.json()
        assert "department_stats" in data
        assert "monthly_trends" in data
        assert "recent_sessions" in data
        # Monthly trends should cover 6 months
        assert len(data["monthly_trends"]) == 6

    def test_analytics_requires_admin(self, client, faculty_headers):
        response = client.get("/admin/analytics", headers=faculty_headers)
        assert response.status_code in [401, 403]


class TestSystemExport:
    """GET /admin/export/{fmt}"""

    def test_admin_export_csv(self, client, admin_headers):
        response = client.get("/admin/export/csv?period=monthly", headers=admin_headers)
        assert response.status_code == 200
        assert response.headers["content-type"].startswith("text/csv")

    def test_admin_export_xlsx(self, client, admin_headers):
        response = client.get("/admin/export/xlsx?period=monthly", headers=admin_headers)
        assert response.status_code == 200
        assert "spreadsheetml" in response.headers["content-type"]

    def test_admin_export_invalid_format(self, client, admin_headers):
        response = client.get("/admin/export/zip", headers=admin_headers)
        assert response.status_code == 400
