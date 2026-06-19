# SmartAttend — Testing Guide

## Overview

The SmartAttend test suite uses **pytest** for the backend and **Flutter test** for the mobile app.

---

## Backend Testing (pytest)

### Setup

```powershell
# From project root (Windows PowerShell)

# The venv is pre-created with Python 3.12 at backend\.venv312\
# Activate it:
backend\.venv312\Scripts\Activate.ps1

# All requirements are already installed. To reinstall:
backend\.venv312\Scripts\pip install -r backend\requirements.txt

# Run tests from the project root:
backend\.venv312\Scripts\pytest backend\tests\ -v
```

### Running Tests

```bash
# Run all tests
pytest tests/ -v

# Run with short traceback
pytest tests/ -v --tb=short

# Run a specific test file
pytest tests/test_auth.py -v

# Run a specific test class
pytest tests/test_auth.py::TestLogin -v

# Run a specific test function
pytest tests/test_auth.py::TestLogin::test_student_login_success -v

# Run with coverage report
pip install pytest-cov
pytest tests/ -v --cov=app --cov-report=html
# Open htmlcov/index.html in browser
```

### Test Files

| File | Coverage |
|---|---|
| `tests/conftest.py` | Fixtures: DB session, test users, JWT helpers |
| `tests/test_auth.py` | Register, Login (all roles), Token Refresh, Protected Routes |
| `tests/test_attendance.py` | Session creation, Mark attendance, RSSI validation, History, Export |
| `tests/test_admin.py` | Dashboard, Student/Faculty/Classroom CRUD, Analytics, System Export |

### Test Architecture

- **Database**: In-memory SQLite (replaces MySQL in tests — no real DB needed)
- **AWS Services**: Mocked with `unittest.mock.patch`
- **FastAPI**: Uses `TestClient` from `httpx`
- **Isolation**: Each test function gets a fresh DB session with rollback

---

## Flutter Testing

### Setup

```bash
# From project root
flutter pub get
```

### Running Flutter Tests

```bash
# Run all widget tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html  # Requires lcov

# Analyze code (catch obvious errors)
flutter analyze
```

---

## Manual End-to-End Testing

### Prerequisites

1. Start MySQL: `mysql -u root -p1234`
2. Create database: `mysql -u root -p1234 -e "CREATE DATABASE IF NOT EXISTS smart_attendance;"`
3. Load schema: `mysql -u root -p1234 smart_attendance < database/schema.sql`
4. Load seed data: `mysql -u root -p1234 smart_attendance < database/seed.sql`
5. Start backend: `backend\.venv312\Scripts\uvicorn backend.app.main:app --reload --port 8000`
6. Open API docs: `http://localhost:8000/docs`

### Flow 1: Student Registration + Face Registration

1. `POST /auth/register` — Register with valid email/password
2. Copy `access_token` from response
3. `POST /auth/face-register` (multipart) — Upload a face image
4. Verify `face_id` is returned and stored in DB

### Flow 2: Faculty Creates Session → Student Marks Attendance

1. Faculty: `POST /auth/login` (role: faculty)
2. Faculty: `POST /faculty/create-session` → note session ID
3. Faculty: `GET /faculty/whatsapp-link?session_id={id}` → copy `deep_link`
4. Open `smartattend://attendance/{id}` on device
5. Student: BLE scan detects beacon
6. Student: `POST /student/mark-attendance` with valid RSSI
7. Faculty: `GET /faculty/live-attendance?session_id={id}` → student appears

### Flow 3: Faculty Exports Report

1. Faculty: `GET /faculty/export/xlsx?period=monthly`
2. Download the `.xlsx` file
3. Open in Excel — verify purple header row and data

### Flow 4: Admin Analytics

1. Admin: `POST /auth/login` (role: admin)
2. Admin: `GET /admin/analytics`
3. Verify `department_stats` and `monthly_trends` are populated

---

## Test Data

### Default Credentials (from `seed.sql`)

| Role | Email | Password |
|---|---|---|
| Admin | `admin@smartattend.com` | `Admin@1234` |
| Faculty | `faculty@smartattend.com` | `Faculty@1234` |
| Student | `student@smartattend.com` | `Student@1234` |

### BLE Beacon

- **UUID**: `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`
- **Name**: `CLASSROOM_A101`
- **RSSI Threshold**: -75 dBm (configurable in `app_constants.dart`)

---

## Known Limitations

1. **BLE testing requires a physical Android device** — emulators cannot scan BLE beacons
2. **Face registration requires AWS credentials** — use `FACE_CONFIDENCE_THRESHOLD=0.0` for testing without real faces
3. **iOS deep links (HTTPS)** require `assetlinks.json` on the deployed server — use custom scheme (`smartattend://`) for development
