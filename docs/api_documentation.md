# SmartAttend API Documentation

**Base URL**: `http://localhost:8000`  
**Auth**: JWT Bearer token — `Authorization: Bearer <access_token>`  
**Version**: v5

---

## Authentication (`/auth`)

### POST `/auth/register`
Register a new student account.

**Request Body**
```json
{
  "name": "Aarav Kumar",
  "reg_no": "21CSE001",
  "department": "Computer Science",
  "year": 2,
  "section": "A",
  "email": "aarav@example.com",
  "phone_number": "+91 9876543210",
  "password": "SecurePass1"
}
```

**Response 201**
```json
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer",
  "role": "student",
  "user": { "id": 1, "name": "Aarav Kumar", "reg_no": "21CSE001" }
}
```

---

### POST `/auth/login`
Authenticate user. Supports roles: `student`, `faculty`, `admin`.

**Request Body**
```json
{ "email": "user@example.com", "password": "SecurePass1", "role": "student" }
```

---

### POST `/auth/refresh`
Exchange refresh token for a new access + refresh token pair.

```json
{ "refresh_token": "eyJ..." }
```

---

### POST `/auth/face-register`
Register student's face using ArcFace (InsightFace). Accepts a single image.
Stores a 512-dim embedding in the `face_embeddings` table.

**Form Data**: `file` (image/jpeg or image/png)  
**Auth**: Student JWT required

---

### POST `/auth/face-register-auto` ⭐ Recommended
Batch automatic face registration. Accepts 30–200 frames captured during guided movements.
Backend filters blurry/duplicate frames and stores 30–50 unique embeddings.

**Form Data**: `files[]` (multiple images — one per frame)  
**Auth**: Student JWT required

**Response 200**
```json
{
  "success": true,
  "stored": 47,
  "total_input": 124,
  "rejected_blurry": 18,
  "rejected_no_face": 9,
  "rejected_duplicate": 50,
  "profile_url": "https://api.smartattend.app/static/faces/1.jpg"
}
```

---

### GET `/auth/me`
Get the currently authenticated user's profile (works for all roles).

---

## Faculty (`/faculty`)

> All endpoints require Faculty JWT.

### GET `/faculty/dashboard`
Returns sessions, classrooms, and subjects for the faculty.

---

### POST `/faculty/create-session`
Create an attendance session and generate a shareable attendance link.

**Request Body**
```json
{ "classroom_id": 1, "subject_id": 2, "attendance_code": "123456" }
```

> **Note**: `attendance_code` is an internal field only. It is NOT included in the WhatsApp message. Students attend via BLE + Face only.

**Response 201**
```json
{
  "id": 42,
  "classroom_name": "CLASSROOM_A101",
  "subject_name": "Data Structures",
  "is_active": true,
  "deep_link": "smartattend://attendance/42",
  "web_link": "https://smartattend.app/attendance/42",
  "whatsapp_url": "https://wa.me/?text=..."
}
```

---

### PUT `/faculty/end-session/{session_id}`  
### POST `/faculty/stop-session/{session_id}`
End an active session (PUT = REST standard, POST = spec alias).

---

### GET `/faculty/whatsapp-link?session_id={id}`
Get or regenerate the attendance link for a session.

### POST `/faculty/share-link?session_id={id}`
POST version (spec requirement).

---

### GET `/faculty/live-attendance?session_id={id}`
Real-time attendance list for an active session.

**Response 200**
```json
{
  "session_id": 42,
  "attendance_count": 12,
  "students": [
    { "student_name": "Aarav Kumar", "reg_no": "21CSE001", "face_confidence": 97.2, "rssi": -65 }
  ]
}
```

---

### GET `/faculty/attendance-report?period={daily|weekly|monthly}`
### GET `/faculty/reports/daily`
### GET `/faculty/reports/weekly`
### GET `/faculty/reports/monthly`
Attendance records for the faculty's sessions.

---

### GET `/faculty/export/{fmt}?period={period}`
### GET `/faculty/export/excel`
### GET `/faculty/export/pdf`
### GET `/faculty/export/csv`
Export attendance. Formats: `csv`, `xlsx`, `pdf`.

---

## Student (`/student` + `/attendance`)

> All endpoints require Student JWT.

### GET `/student/dashboard`
Overall and subject-wise attendance analytics.

---

### GET `/student/attendance-history?period={daily|weekly|monthly}`
Filtered attendance records.

---

### POST `/attendance/verify`
Pre-check session and BLE eligibility WITHOUT marking attendance.

**Form Data**: `session_id` (int), `rssi` (int)

**Response 200**
```json
{
  "eligible": true,
  "step": "ready",
  "session_id": 42,
  "classroom_name": "CLASSROOM_A101",
  "classroom_uuid": "FA:CE:B0:0C:12:34",
  "subject_name": "Data Structures"
}
```

---

### POST `/attendance/mark` ⭐ Primary Attendance Endpoint
Marks attendance after BLE + face verification. 

**Form Data (multipart)**:  
- `file` (image) — student's face photo  
- `session_id` (int) — from WhatsApp deep link  
- `rssi` (int) — BLE signal strength  

**Validation steps**: Session check → RSSI check → Department check → Duplicate check → ArcFace cosine similarity (≥ 0.75)

**Response 200 (success)**
```json
{
  "match": true,
  "confidence": 97.2,
  "message": "Attendance marked successfully ✅",
  "attendance_id": 123,
  "time": "09:05",
  "date": "2025-01-15"
}
```

**Error codes**: `403` BLE out of range, `403` wrong dept, `400` no face, `409` already marked, `404` session ended

---

## Admin (`/admin`)

> All endpoints require Admin JWT.

### GET `/admin/dashboard`
```json
{
  "total_students": 500,
  "total_faculty": 30,
  "total_sessions": 245,
  "system_attendance_rate": 82.5
}
```

### GET `/admin/students?search={q}&department={dept}`
### DELETE `/admin/students/{student_id}`
### GET `/admin/students/{student_id}/face-image`

### GET `/admin/faculty`
List all faculty members.

### POST `/admin/faculty`
Register a new faculty member. Since subjects require a valid faculty ID, they are assigned to a faculty in a two-step process: (1) create the faculty member, then (2) create subjects pointing to the faculty member's ID.

**Request Body**
```json
{
  "name": "Rajesh Kumar",
  "email": "rajesh@smartattend.com",
  "password": "Faculty@123",
  "department": "Computer Science"
}
```

### DELETE `/admin/faculty/{faculty_id}`
Delete a faculty member.

### GET `/admin/classrooms`
### POST `/admin/classrooms`
### DELETE `/admin/classrooms/{classroom_id}`

### GET `/admin/ble-beacons`
### POST `/admin/ble-beacons`
```json
{ "classroom_id": 1, "beacon_uuid": "FA:CE:B0:0C:12:34", "beacon_name": "CLASSROOM_A101", "rssi_threshold": -70 }
```
### PUT `/admin/ble-beacons/{beacon_id}`
### DELETE `/admin/ble-beacons/{beacon_id}`

### GET `/admin/subjects`
### POST `/admin/subjects`
Create a new subject and assign it to a faculty member by specifying their `faculty_id`.

**Request Body**
```json
{
  "subject_name": "Data Structures",
  "subject_code": "CS201",
  "department": "Computer Science",
  "faculty_id": 2
}
```

### GET `/admin/analytics`
Includes `low_attendance_alerts` (students < 75%).

### GET `/admin/export/{fmt}?period={period}&department={dept}`

---

## Full Attendance Flow

```
1. Faculty: POST /faculty/create-session
       ↓ returns deep_link + whatsapp_url (NO code in message)
2. Faculty: clicks "Share via WhatsApp" → WhatsApp opens
3. Student: taps link → App opens via deep link
       smartattend://attendance/42
4. App: DeepLinkService.setDeepLinkContext(sessionId=42)
5. App: BLE scan → validates classroom UUID matches session
6. Student: takes selfie
7. App: POST /attendance/mark (multipart)
       session_id=42, rssi=-65, file=face.jpg
8. Backend validates:
   ✓ Session active
   ✓ RSSI ≥ -70 dBm
   ✓ Department match
   ✓ No duplicate
   ✓ ArcFace cosine similarity ≥ 0.75
9. Attendance marked → success screen
   tier: 'present' | 'manual_review' | 'rejected'
```
