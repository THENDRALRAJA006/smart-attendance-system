# ============================================================
# SmartAttend — Auth Route Tests
# Tests: register, login (all roles), refresh token, face verify
# ============================================================

import pytest


class TestStudentRegistration:
    """POST /auth/register"""

    def test_register_success(self, client):
        response = client.post("/auth/register", json={
            "name": "New Student",
            "reg_no": "CS2024001",
            "department": "Computer Science",
            "year": 1,
            "section": "B",
            "email": "newstudent@test.com",
            "password": "Password@123",
        })
        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["role"] == "student"
        assert data["user"]["reg_no"] == "CS2024001"

    def test_register_duplicate_email(self, client):
        """Duplicate email should return 409."""
        payload = {
            "name": "Another Student",
            "reg_no": "CS2024002",
            "department": "CS",
            "year": 2,
            "section": "A",
            "email": "newstudent@test.com",  # already used above
            "password": "Password@123",
        }
        response = client.post("/auth/register", json=payload)
        assert response.status_code == 409
        assert "Email already registered" in response.json()["detail"]

    def test_register_weak_password(self, client):
        """Weak password (< 8 chars) should return 422."""
        response = client.post("/auth/register", json={
            "name": "Bad Password",
            "reg_no": "CS2024003",
            "department": "CS",
            "year": 1,
            "section": "A",
            "email": "badpwd@test.com",
            "password": "weak",
        })
        assert response.status_code == 422

    def test_register_invalid_year(self, client):
        """Year must be 1–4."""
        response = client.post("/auth/register", json={
            "name": "Invalid Year",
            "reg_no": "CS2024004",
            "department": "CS",
            "year": 5,
            "section": "A",
            "email": "badyear@test.com",
            "password": "Password@123",
        })
        assert response.status_code == 422


class TestLogin:
    """POST /auth/login"""

    def test_student_login_success(self, client, student_user):
        response = client.post("/auth/login", json={
            "email": "student@test.com",
            "password": "Student@1234",
            "role": "student",
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["role"] == "student"

    def test_faculty_login_success(self, client, faculty_user):
        response = client.post("/auth/login", json={
            "email": "faculty@test.com",
            "password": "Faculty@1234",
            "role": "faculty",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["role"] == "faculty"

    def test_admin_login_success(self, client, admin_user):
        response = client.post("/auth/login", json={
            "email": "admin@test.com",
            "password": "Admin@1234",
            "role": "admin",
        })
        assert response.status_code == 200
        data = response.json()
        assert data["role"] == "admin"

    def test_wrong_password(self, client, student_user):
        response = client.post("/auth/login", json={
            "email": "student@test.com",
            "password": "WrongPassword@1",
            "role": "student",
        })
        assert response.status_code == 401

    def test_wrong_role(self, client, student_user):
        """Student email + faculty role should fail."""
        response = client.post("/auth/login", json={
            "email": "student@test.com",
            "password": "Student@1234",
            "role": "faculty",
        })
        assert response.status_code == 401

    def test_invalid_role_string(self, client):
        response = client.post("/auth/login", json={
            "email": "any@test.com",
            "password": "Password@1",
            "role": "superuser",  # invalid role
        })
        assert response.status_code == 422


class TestTokenRefresh:
    """POST /auth/refresh"""

    def test_refresh_token_success(self, client, student_user):
        # First login to get refresh token
        login_resp = client.post("/auth/login", json={
            "email": "student@test.com",
            "password": "Student@1234",
            "role": "student",
        })
        refresh_token = login_resp.json()["refresh_token"]

        # Exchange for new tokens
        response = client.post("/auth/refresh", json={
            "refresh_token": refresh_token
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data

    def test_invalid_refresh_token(self, client):
        response = client.post("/auth/refresh", json={
            "refresh_token": "invalid.token.here"
        })
        assert response.status_code == 401


class TestProtectedRoutes:
    """Tests that protected routes reject unauthenticated requests."""

    def test_student_profile_unauthenticated(self, client):
        response = client.get("/student/dashboard")
        assert response.status_code in [401, 403]

    def test_faculty_dashboard_unauthenticated(self, client):
        response = client.get("/faculty/dashboard")
        assert response.status_code in [401, 403]

    def test_admin_dashboard_unauthenticated(self, client):
        response = client.get("/admin/dashboard")
        assert response.status_code in [401, 403]
