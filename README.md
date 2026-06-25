# SmartAttend AI 🎓

**Production-Ready AI-Powered Smart Attendance System**

[![Flutter](https://img.shields.io/badge/Flutter-3.5+-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql)](https://mysql.com)
[![InsightFace](https://img.shields.io/badge/InsightFace-ArcFace-7B2FBE)](https://github.com/deepinsight/insightface)
[![ESP32](https://img.shields.io/badge/ESP32-BLE-E7352C)](https://www.espressif.com)

---

## Overview

SmartAttend AI is a **multi-factor biometric attendance system** that requires:

1. ✅ **Authentication** — Student must be logged in (JWT)
2. 📡 **BLE Proximity** — Must be within classroom BLE range (RSSI > -70 dBm)
3. 👤 **Face Verification** — ArcFace (InsightFace) cosine similarity ≥ 0.75
4. ⏱ **Active Session** — Faculty must have started a session

**Zero AWS dependency** — Face recognition runs entirely on the server using local InsightFace embeddings.

---

## Architecture

```
Flutter App ──JWT──▶ FastAPI ──▶ MySQL
                         │
                         ├──▶ InsightFace (ArcFace buffalo_l) — local face embeddings
                         └──▶ BLE RSSI (validated client-side via ESP32 beacons)

ESP32 BLE Beacon ──RSSI──▶ Flutter Scanner
```

### Face Recognition Tiers

| Cosine Similarity | Result |
|---|---|
| `>= 0.75` | ✅ **Present** (auto-marked) |
| `0.65 – 0.74` | ⚠️ **Manual Review** (flagged for faculty) |
| `< 0.65` | ❌ **Rejected** |

---

## Project Structure

```
smart_attendance_system/
│
├── lib/                          # Flutter App
│   ├── core/
│   │   ├── theme/app_theme.dart  # Dark glassmorphism theme
│   │   ├── constants/            # API URLs, BLE config, ArcFace thresholds
│   │   ├── network/api_client.dart # Dio + JWT interceptor
│   │   └── services/             # BLE, Camera, Storage
│   ├── controllers/              # GetX: Auth, Student, Attendance, Faculty, Admin
│   ├── models/                   # Data models
│   ├── screens/                  # 11 screens
│   └── widgets/                  # Shared widgets
│
├── backend/                      # FastAPI Backend
│   ├── main.py                   # App entry
│   └── app/
│       ├── core/                 # Config, DB, Security, Deps
│       ├── models/models.py      # SQLAlchemy ORM
│       ├── schemas/schemas.py    # Pydantic schemas
│       ├── routes/               # auth, student, faculty, admin, attendance
│       └── services/             # face_service (ArcFace), attendance, reports
│
├── database/
│   ├── schema.sql                # MySQL DDL
│   └── seed.sql                  # Sample data
│
├── esp32/
│   └── ble_beacon/ble_beacon.ino # Arduino firmware
│
└── docs/
    ├── api_documentation.md
    ├── setup_guide.md
    └── deployment_guide.md
```

---

## Quick Start

```bash
# 1. Database
mysql -u root -p < database/schema.sql
mysql -u root -p < database/seed.sql

# 2. Backend
cd backend
python -m venv venv && venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env   # Fill in DB credentials and JWT secret (no AWS needed)
uvicorn main:app --reload

# 3. Flutter
flutter pub get
flutter run

# 4. ESP32
# Open esp32/ble_beacon/ble_beacon.ino in Arduino IDE
# Configure CLASSROOM_NAME and CLASSROOM_UUID
# Upload to ESP32
```

---

## Features

### Student
- Register with full profile + **Automatic Face Registration** (ArcFace, 8-movement guide)
- BLE classroom scanner with signal strength display
- Multi-factor attendance: BLE + Face + Session (manual selfie capture)
- Dashboard with attendance % ring chart
- Subject-wise attendance with threshold alerts
- Full attendance history (daily/weekly/monthly)

### Faculty
- Create sessions with 6-digit attendance codes
- Real-time active session management
- Attendance reports by period
- Export: Excel / CSV / PDF

### Admin
- System analytics dashboard
- Full CRUD: Students, Faculty, Classrooms, Subjects
- Department-wise statistics

---

## Default Credentials

| Role | Email | Password |
|------|-------|---------|
| Admin | admin@smartattend.com | Admin@123 |
| Faculty | rajesh@smartattend.com | Faculty@123 |
| Student | arjun@student.com | Student@123 |

> ⚠️ **Change all passwords before production deployment!**

---

## Docs

- [Setup Guide](docs/setup_guide.md)
- [API Documentation](docs/api_documentation.md)  
- [Deployment Guide](docs/deployment_guide.md)
- [Swagger UI](http://localhost:8000/docs) (after starting backend)
