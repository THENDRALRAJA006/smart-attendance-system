# SmartAttend — Setup Guide

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Flutter | ≥3.5.0 | Mobile app |
| Python | ≥3.11 | Backend |
| MySQL | ≥8.0 | Database |
| Arduino IDE | ≥2.0 | ESP32 firmware |

---

## 1. MySQL Database Setup

```bash
# Login to MySQL
mysql -u root -p

# Run schema
mysql -u root -p < database/schema.sql

# Run seed data
mysql -u root -p < database/seed.sql
```

---

## 2. FastAPI Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv

# Activate (Windows)
venv\Scripts\activate

# Activate (Linux/Mac)
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env with your DB credentials and JWT secret
# No AWS keys needed — face recognition is local (ArcFace)

# Generate real password hashes for seed data
python -c "from passlib.context import CryptContext; ctx = CryptContext(schemes=['bcrypt']); print(ctx.hash('Admin@123'))"

# Start development server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# API Docs available at:
# http://localhost:8000/docs
# http://localhost:8000/redoc
```

---

## 3. ArcFace (InsightFace) Setup

SmartAttend AI uses **InsightFace buffalo_l** for local face recognition.
**No AWS account, API key, or cloud service is required.**

### Automatic Download
On first startup, the backend automatically downloads the InsightFace `buffalo_l` model
(~200MB) to `~/.insightface/`. This only happens once.

```bash
# Verify insightface is installed
pip install insightface onnxruntime

# Test model download manually (optional)
python -c "from insightface.app import FaceAnalysis; app = FaceAnalysis(name='buffalo_l'); app.prepare(ctx_id=-1)"
```

### Environment Variables (add to `.env`)
```env
# ArcFace cosine similarity thresholds (0.0-1.0 scale)
ARCFACE_SIMILARITY_THRESHOLD=0.75   # >= 0.75 → present
ARCFACE_REVIEW_THRESHOLD=0.65       # 0.65-0.74 → manual_review; < 0.65 → rejected
ARCFACE_MODEL_PATH=~/.insightface
```

> ✅ No AWS credentials, S3 buckets, or Rekognition collections are needed.

---

## 4. Flutter App Setup

```bash
cd (project root — smart_attendance_system/)

# Get dependencies
flutter pub get

# Update API base URL
# Edit: lib/core/constants/app_constants.dart
# Change baseUrl to your backend IP

# For Android Emulator:
#   baseUrl = 'http://10.0.2.2:8000'

# For Physical Device (same WiFi as PC):
#   baseUrl = 'http://YOUR_PC_IP:8000'

# Android permissions (already configured in AndroidManifest.xml)
# Required: BLUETOOTH, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, CAMERA,
#           INTERNET, ACCESS_FINE_LOCATION

# Run app
flutter run
```

### Android Permissions (add to `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## 5. ESP32 BLE Beacon Setup

1. **Install Arduino IDE** ≥ 2.0
2. **Add ESP32 Board**: 
   - File → Preferences → Additional Board Manager URLs:
   - `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
3. **Install Board**: Tools → Board Manager → Search "esp32" → Install
4. **Open firmware**: `esp32/ble_beacon/ble_beacon.ino`
5. **Configure** `CLASSROOM_NAME` and `CLASSROOM_UUID` for each device
6. **Upload**: Select ESP32 board, Connect USB, Upload

---

## 6. Default Credentials

| Role | Email | Password |
|------|-------|---------|
| Admin | admin@smartattend.com | Admin@123 |
| Faculty | rajesh@smartattend.com | Faculty@123 |
| Student | arjun@student.com | Student@123 |

> **⚠ Change all passwords in production!**

---

## 7. Quick Start Sequence

```
1. Start MySQL
2. Run schema.sql + seed.sql
3. Configure .env
4. Start FastAPI: uvicorn main:app --reload
5. Flash ESP32 with ble_beacon.ino
6. Open Flutter app
7. Login → Scan BLE → Verify Face → Mark Attendance ✓
```
