# SmartAttend Deployment Guide

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.12+ | Backend runtime |
| MySQL | 8.0+ | Database |
| Flutter | 3.x | Mobile app |
| AWS Account | — | Rekognition + S3 |
| ESP32 board | — | BLE beacon hardware |

---

## 1. Database Setup

```sql
CREATE DATABASE smart_attendance_db CHARACTER SET utf8mb4;
CREATE USER 'smartattend'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON smart_attendance_db.* TO 'smartattend'@'localhost';
FLUSH PRIVILEGES;
```

Run the master migration:
```bash
mysql -u smartattend -p smart_attendance_db < database/v3_master_migration.sql
```

---

## 2. Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv .venv312
.venv312\Scripts\activate        # Windows
source .venv312/bin/activate     # Linux/macOS

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
```

### `.env` Configuration

```env
# Database
DATABASE_URL=mysql+pymysql://smartattend:your_password@localhost:3306/smart_attendance_db

# JWT
SECRET_KEY=your-super-secret-jwt-key-min-32-chars
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# AWS
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=ap-south-1
AWS_S3_BUCKET=smartattend-faces
AWS_REKOGNITION_COLLECTION=smartattend-faces
REKOGNITION_CONFIDENCE_THRESHOLD=90.0

# App
APP_BASE_URL=https://smartattend.app
ALLOWED_ORIGINS=http://localhost:3000,https://smartattend.app

# BLE
BLE_RSSI_THRESHOLD=-70
```

### Start Backend

```bash
# Development
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Production
gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### API Documentation (auto-generated)
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

---

## 3. AWS Setup

### S3 Bucket
```bash
aws s3api create-bucket \
  --bucket smartattend-faces \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1
```

### Rekognition Collection
```bash
aws rekognition create-collection \
  --collection-id smartattend-faces \
  --region ap-south-1
```

### IAM Policy (minimum required)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "rekognition:IndexFaces",
        "rekognition:SearchFacesByImage",
        "rekognition:DeleteFaces",
        "s3:PutObject",
        "s3:GetObject",
        "s3:GetPresignedUrl"
      ],
      "Resource": [
        "arn:aws:s3:::smartattend-faces/*",
        "arn:aws:rekognition:ap-south-1:*:collection/smartattend-faces"
      ]
    }
  ]
}
```

---

## 4. Flutter App Setup

```bash
cd smart_attendance_system  # project root

# Install dependencies
flutter pub get

# Configure API endpoint
# Edit: lib/core/constants/app_constants.dart
# Set: baseUrl = 'http://YOUR_SERVER_IP:8000'
```

### Android Deep Link Setup

In `android/app/src/main/AndroidManifest.xml`:
```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <!-- Custom scheme -->
  <data android:scheme="smartattend" android:host="attendance" />
  <!-- HTTPS deep link -->
  <data android:scheme="https" android:host="smartattend.app" android:pathPrefix="/attendance" />
</intent-filter>
```

### iOS Deep Link Setup

In `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>smartattend</string>
    </array>
  </dict>
</array>
```

Universal Links require an HTTPS server with `apple-app-site-association` JSON at:
`https://smartattend.app/.well-known/apple-app-site-association`

### Build

```bash
# Android APK (debug)
flutter build apk --debug

# Android APK (release)
flutter build apk --release

# Android App Bundle (Play Store)
flutter build appbundle

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## 5. ESP32 BLE Beacon Setup

Flash the ESP32 with BLE beacon firmware:

```cpp
// esp32_beacon/main.cpp
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEBeacon.h>

#define BEACON_UUID "FA-CE-B0-0C-12-34"  // Set per classroom
#define TX_POWER    -59

void setup() {
  BLEDevice::init("SmartAttend-A101");  // room name
  BLEServer *server = BLEDevice::createServer();
  BLEAdvertising *adv = server->getAdvertising();
  
  BLEBeacon beacon;
  beacon.setManufacturerId(0x4C00);
  beacon.setProximityUUID(BLEUUID(BEACON_UUID));
  beacon.setMajor(1);
  beacon.setMinor(1);
  beacon.setSignalPower(TX_POWER);
  
  BLEAdvertisementData data;
  data.setFlags(0x04);
  data.setManufacturerData(std::string(beacon.getData().c_str(), beacon.getData().length()));
  adv->setAdvertisementData(data);
  adv->start();
}

void loop() {}
```

Register each beacon in the Admin dashboard:
```
POST /admin/ble-beacons
{ "classroom_id": 1, "beacon_uuid": "FA-CE-B0-0C-12-34", "rssi_threshold": -70 }
```

---

## 6. Admin Account Setup

```bash
# Create admin via script or direct DB insert
python create_admin.py \
  --name "System Admin" \
  --email "admin@example.com" \
  --password "Admin@2025"
```

Or via MySQL:
```sql
INSERT INTO admins (name, email, password_hash)
VALUES ('System Admin', 'admin@example.com', '<bcrypt_hash>');
```

---

## 7. Production Checklist

- [ ] Set `SECRET_KEY` to a cryptographically random 64+ char string
- [ ] Configure HTTPS (Nginx + Let's Encrypt)
- [ ] Set `ALLOWED_ORIGINS` to your production domain only
- [ ] Restrict S3 bucket to backend IP
- [ ] Set `ACCESS_TOKEN_EXPIRE_MINUTES=15` in production
- [ ] Enable MySQL SSL connections
- [ ] Configure automated database backups
- [ ] Register Android App Link domain verification JSON
- [ ] Configure iOS Universal Links AASA file

---

## 8. Nginx Configuration (Production)

```nginx
server {
    listen 443 ssl;
    server_name smartattend.app api.smartattend.app;

    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 60;
        client_max_body_size 10M;  # for face image uploads
    }

    location /.well-known/apple-app-site-association {
        root /var/www/smartattend;
        add_header Content-Type application/json;
    }

    location /.well-known/assetlinks.json {
        root /var/www/smartattend;
        add_header Content-Type application/json;
    }
}
```

---

## 9. Testing the Flow

1. **Register admin**: POST `/auth/register` (then update role in DB to admin)
2. **Admin creates classroom**: POST `/admin/classrooms`
3. **Admin registers beacon**: POST `/admin/ble-beacons`
4. **Admin creates faculty**: POST `/admin/faculty`
5. **Admin creates subject**: POST `/admin/subjects`
6. **Faculty logs in**: POST `/auth/login` (role: faculty)
7. **Faculty creates session**: POST `/faculty/create-session`
8. **Faculty shares WhatsApp link**: Use returned `whatsapp_url`
9. **Student registers**: POST `/auth/register`
10. **Student registers face**: POST `/auth/face-register`
11. **Student taps link**: App opens with `session_id=42`
12. **Student scans BLE**: `POST /attendance/verify`
13. **Student takes selfie**: `POST /attendance/mark`
14. **Faculty views live**: `GET /faculty/live-attendance`
15. **Faculty exports report**: `GET /faculty/export/xlsx`
