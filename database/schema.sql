-- ============================================================
-- SmartAttend — MySQL Database Schema
-- ============================================================

CREATE DATABASE IF NOT EXISTS smart_attend
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE smart_attend;

-- ──────────────────────────────────────────────────────────────
-- STUDENTS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS students (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    reg_no        VARCHAR(20)  NOT NULL UNIQUE,
    department    VARCHAR(100) NOT NULL,
    year          TINYINT(1)   NOT NULL CHECK (year BETWEEN 1 AND 4),
    section       VARCHAR(5)   NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    mobile        VARCHAR(20)  NULL,
    password_hash VARCHAR(255) NOT NULL,
    face_id       VARCHAR(255) NULL COMMENT 'AWS Rekognition FaceId',
    face_image_url VARCHAR(500) NULL COMMENT 'S3 URI: s3://bucket/faces/student_{id}.jpg',
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_students_email (email),
    INDEX idx_students_reg_no (reg_no),
    INDEX idx_students_dept (department)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- FACULTY
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS faculty (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_faculty_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- ADMINS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS admins (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- CLASSROOMS (ESP32 BLE Beacons)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS classrooms (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    room_name        VARCHAR(50)  NOT NULL UNIQUE COMMENT 'e.g. CLASSROOM_A101',
    ble_uuid         VARCHAR(100) NOT NULL UNIQUE COMMENT 'ESP32 BLE UUID',
    attendance_code  VARCHAR(6)   NULL,
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_classrooms_room_name (room_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- SUBJECTS
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS subjects (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    subject_name VARCHAR(100) NOT NULL,
    subject_code VARCHAR(20)  NULL,
    department   VARCHAR(100) NULL,
    faculty_id   INT          NOT NULL,
    created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (faculty_id) REFERENCES faculty(id) ON DELETE CASCADE,
    INDEX idx_subjects_faculty (faculty_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- SESSIONS (Faculty-created attendance sessions)
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    classroom_id     INT         NOT NULL,
    subject_id       INT         NOT NULL,
    faculty_id       INT         NOT NULL,
    attendance_code  VARCHAR(6)  NOT NULL,
    start_time       DATETIME    DEFAULT CURRENT_TIMESTAMP,
    end_time         DATETIME    NULL,
    is_active        BOOLEAN     DEFAULT TRUE,
    created_at       DATETIME    DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id)   REFERENCES subjects(id)   ON DELETE CASCADE,
    FOREIGN KEY (faculty_id)   REFERENCES faculty(id)    ON DELETE CASCADE,
    INDEX idx_sessions_classroom (classroom_id),
    INDEX idx_sessions_active (is_active),
    INDEX idx_sessions_faculty (faculty_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- ──────────────────────────────────────────────────────────────
-- ATTENDANCE
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    student_id       INT         NOT NULL,
    classroom_id     INT         NOT NULL,
    subject_id       INT         NOT NULL,
    session_id       INT         NULL,
    date             DATE        NOT NULL,
    time             VARCHAR(10) NOT NULL COMMENT 'HH:MM',
    status           ENUM('present', 'absent', 'late') DEFAULT 'present',
    rssi             INT         NULL COMMENT 'BLE signal strength in dBm',
    face_confidence  FLOAT       NULL COMMENT 'AWS Rekognition similarity %',
    marked_at        DATETIME    DEFAULT CURRENT_TIMESTAMP,
    
    -- Prevent duplicate attendance per student per session
    UNIQUE KEY uq_student_session (student_id, session_id),
    
    FOREIGN KEY (student_id)   REFERENCES students(id)   ON DELETE CASCADE,
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id)   REFERENCES subjects(id)   ON DELETE CASCADE,
    FOREIGN KEY (session_id)   REFERENCES sessions(id)   ON DELETE SET NULL,
    
    INDEX idx_attendance_student (student_id),
    INDEX idx_attendance_date (date),
    INDEX idx_attendance_session (session_id),
    INDEX idx_attendance_subject (subject_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
