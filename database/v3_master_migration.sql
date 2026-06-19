-- ============================================================
-- SmartAttend — v3 Master Migration
-- Applies all schema gaps identified in implementation plan
-- Run against existing: smart_attendance or smart_attend DB
-- ============================================================

-- Use the canonical DB name per spec
CREATE DATABASE IF NOT EXISTS smart_attendance_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smart_attendance_db;

-- ──────────────────────────────────────────────────────────────
-- 1. STUDENTS — add phone_number if missing
-- ──────────────────────────────────────────────────────────────
ALTER TABLE students
    ADD COLUMN IF NOT EXISTS phone_number VARCHAR(20) NULL COMMENT 'Student mobile number'
    AFTER email;


-- ──────────────────────────────────────────────────────────────
-- 2. FACULTY — add department column if missing
-- ──────────────────────────────────────────────────────────────
ALTER TABLE faculty
    ADD COLUMN IF NOT EXISTS department VARCHAR(100) NULL
    AFTER name;


-- ──────────────────────────────────────────────────────────────
-- 3. ATTENDANCE_LINKS — unique shareable session tokens
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_links (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    session_id    INT          NOT NULL,
    token         VARCHAR(64)  NOT NULL UNIQUE COMMENT 'UUID token for the link',
    deep_link     VARCHAR(500) NOT NULL COMMENT 'smartattend://attendance/{session_id}',
    web_link      VARCHAR(500) NOT NULL COMMENT 'https://smartattend.app/attendance/{session_id}',
    whatsapp_url  TEXT         NOT NULL COMMENT 'Pre-filled wa.me URL',
    is_active     BOOLEAN      DEFAULT TRUE,
    expires_at    DATETIME     NULL COMMENT 'NULL = no expiry (session end time used)',
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE,
    INDEX idx_links_session (session_id),
    INDEX idx_links_token (token)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- 4. FACE_PROFILES — normalized face data per student
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS face_profiles (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    student_id       INT          NOT NULL UNIQUE,
    face_id          VARCHAR(255) NOT NULL COMMENT 'AWS Rekognition FaceId',
    s3_key           VARCHAR(500) NOT NULL COMMENT 'S3 object key',
    s3_url           VARCHAR(500) NOT NULL COMMENT 'Full S3 URI',
    confidence       FLOAT        NULL    COMMENT 'Indexing confidence from Rekognition',
    registered_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE,
    INDEX idx_face_student (student_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- 5. BLE_BEACONS — ESP32 beacon configuration
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS ble_beacons (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    classroom_id    INT          NOT NULL UNIQUE COMMENT 'Maps 1-to-1 with classrooms',
    beacon_uuid     VARCHAR(100) NOT NULL UNIQUE COMMENT 'ESP32 BLE UUID / MAC',
    beacon_name     VARCHAR(100) NOT NULL COMMENT 'e.g. CLASSROOM_A101',
    rssi_threshold  INT          NOT NULL DEFAULT -70 COMMENT 'Min RSSI dBm for attendance',
    tx_power        INT          NULL COMMENT 'Beacon TX power (dBm)',
    is_active       BOOLEAN      DEFAULT TRUE,
    last_seen_at    DATETIME     NULL,
    created_at      DATETIME     DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE,
    INDEX idx_beacons_classroom (classroom_id),
    INDEX idx_beacons_uuid (beacon_uuid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- 6. Seed BLE beacons from existing classrooms (if any)
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO ble_beacons (classroom_id, beacon_uuid, beacon_name, rssi_threshold)
SELECT id, ble_uuid, room_name, -70
FROM classrooms;


-- ──────────────────────────────────────────────────────────────
-- Done
-- ──────────────────────────────────────────────────────────────
SELECT 'v3 migration complete' AS status;
