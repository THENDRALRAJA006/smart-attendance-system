-- ============================================================
-- SmartAttend — AWS RDS MySQL Schema (v3)
-- Run this script in AWS CloudShell or any MySQL client to
-- bootstrap the smart_attendance database with all tables.
--
-- Host  : smart-attendance-db.cwh6sya6karz.us-east-1.rds.amazonaws.com
-- Port  : 3306
-- User  : admin
-- DB    : smart_attendance
-- ============================================================

-- 1. Create the database if it does not already exist
CREATE DATABASE IF NOT EXISTS smart_attendance
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE smart_attendance;

-- ────────────────────────────────────────────────────────────
-- 2. Core user tables
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS students (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100)  NOT NULL,
    reg_no         VARCHAR(20)   NOT NULL UNIQUE,
    department     VARCHAR(100)  NOT NULL,
    year           INT           NOT NULL,
    section        VARCHAR(5)    NOT NULL,
    email          VARCHAR(150)  NOT NULL UNIQUE,
    phone_number   VARCHAR(20),
    password_hash  VARCHAR(255)  NOT NULL,
    face_id        VARCHAR(255),        -- AWS Rekognition FaceId (quick-access copy)
    face_image_url VARCHAR(500),        -- S3 URI
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_students_reg_no (reg_no),
    INDEX idx_students_email  (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS faculty (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    department    VARCHAR(100),
    email         VARCHAR(150)  NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_faculty_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS admins (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(150)  NOT NULL UNIQUE,
    password_hash VARCHAR(255)  NOT NULL,
    created_at    DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admins_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 3. Classroom & BLE beacon tables
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS classrooms (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    room_name       VARCHAR(50)   NOT NULL UNIQUE,   -- e.g. CLASSROOM_A101
    ble_uuid        VARCHAR(100)  NOT NULL UNIQUE,
    attendance_code VARCHAR(6),
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS ble_beacons (
    id             INT AUTO_INCREMENT PRIMARY KEY,
    classroom_id   INT           NOT NULL UNIQUE,
    beacon_uuid    VARCHAR(100)  NOT NULL UNIQUE,
    beacon_name    VARCHAR(100)  NOT NULL,
    rssi_threshold INT           NOT NULL DEFAULT -70,
    tx_power       INT,
    is_active      TINYINT(1)    NOT NULL DEFAULT 1,
    last_seen_at   DATETIME,
    created_at     DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_beacon_classroom
        FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 4. Face profile table (normalised face data)
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS face_profiles (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    student_id    INT           NOT NULL UNIQUE,
    face_id       VARCHAR(255)  NOT NULL,  -- AWS Rekognition FaceId
    s3_key        VARCHAR(500)  NOT NULL,  -- S3 object key
    s3_url        VARCHAR(500)  NOT NULL,  -- Full S3 URI
    confidence    FLOAT,
    registered_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_face_student
        FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 5. Subjects, faculty–subject mapping, timetable
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS subjects (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100)  NOT NULL,
    subject_code VARCHAR(20),
    department   VARCHAR(100),
    faculty_id   INT           NOT NULL,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_subject_faculty
        FOREIGN KEY (faculty_id) REFERENCES faculty(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS faculty_subjects (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    faculty_id INT NOT NULL,
    subject_id INT NOT NULL,
    UNIQUE KEY uq_faculty_subject (faculty_id, subject_id),
    CONSTRAINT fk_fs_faculty  FOREIGN KEY (faculty_id) REFERENCES faculty(id)  ON DELETE CASCADE,
    CONSTRAINT fk_fs_subject  FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS class_timetable (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    class_name   VARCHAR(50)  NOT NULL,
    semester     INT          NOT NULL,
    day_of_week  VARCHAR(10)  NOT NULL,
    period       INT          NOT NULL,
    subject_id   INT          NOT NULL,
    faculty_id   INT          NOT NULL,
    classroom_id INT,
    start_time   VARCHAR(10)  NOT NULL,  -- HH:MM
    end_time     VARCHAR(10)  NOT NULL,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_tt_subject   FOREIGN KEY (subject_id)   REFERENCES subjects(id)    ON DELETE CASCADE,
    CONSTRAINT fk_tt_faculty   FOREIGN KEY (faculty_id)   REFERENCES faculty(id)     ON DELETE CASCADE,
    CONSTRAINT fk_tt_classroom FOREIGN KEY (classroom_id) REFERENCES classrooms(id)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 6. Sessions and attendance-link tables
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS sessions (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    classroom_id    INT          NOT NULL,
    subject_id      INT          NOT NULL,
    faculty_id      INT          NOT NULL,
    attendance_code VARCHAR(6)   NOT NULL,  -- internal only, not exposed to students
    start_time      DATETIME DEFAULT CURRENT_TIMESTAMP,
    end_time        DATETIME,
    is_active       TINYINT(1)   NOT NULL DEFAULT 1,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_sess_classroom FOREIGN KEY (classroom_id) REFERENCES classrooms(id),
    CONSTRAINT fk_sess_subject   FOREIGN KEY (subject_id)   REFERENCES subjects(id),
    CONSTRAINT fk_sess_faculty   FOREIGN KEY (faculty_id)   REFERENCES faculty(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS attendance_links (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    session_id   INT          NOT NULL,
    token        VARCHAR(64)  NOT NULL UNIQUE,
    deep_link    VARCHAR(500) NOT NULL,   -- smartattend://attendance/{session_id}
    web_link     VARCHAR(500) NOT NULL,   -- https://smartattend.app/attendance/{session_id}
    whatsapp_url TEXT         NOT NULL,
    is_active    TINYINT(1)   NOT NULL DEFAULT 1,
    expires_at   DATETIME,
    created_at   DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_al_session FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 7. Attendance records
-- ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS attendance (
    id              INT AUTO_INCREMENT PRIMARY KEY,
    student_id      INT          NOT NULL,
    classroom_id    INT          NOT NULL,
    subject_id      INT          NOT NULL,
    session_id      INT,
    date            DATE         NOT NULL,
    time            VARCHAR(10)  NOT NULL,   -- HH:MM
    status          VARCHAR(10)  NOT NULL DEFAULT 'present',  -- present|absent|late
    rssi            INT,
    face_confidence FLOAT,
    marked_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_student_session (student_id, session_id),
    CONSTRAINT fk_att_student   FOREIGN KEY (student_id)   REFERENCES students(id),
    CONSTRAINT fk_att_classroom FOREIGN KEY (classroom_id) REFERENCES classrooms(id),
    CONSTRAINT fk_att_subject   FOREIGN KEY (subject_id)   REFERENCES subjects(id),
    CONSTRAINT fk_att_session   FOREIGN KEY (session_id)   REFERENCES sessions(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ────────────────────────────────────────────────────────────
-- 8. Seed: default admin account  (password = Admin@1234)
-- ────────────────────────────────────────────────────────────
-- bcrypt hash of "Admin@1234" — change on first login!
INSERT IGNORE INTO admins (name, email, password_hash)
VALUES (
    'System Admin',
    'admin@smartattend.com',
    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW'
);

-- ────────────────────────────────────────────────────────────
-- 9. Verification: list all created tables
-- ────────────────────────────────────────────────────────────
SHOW TABLES;
