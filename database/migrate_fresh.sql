-- SmartAttend — Migration: recreate tables in smart_attendance DB
USE smart_attendance;

SET FOREIGN_KEY_CHECKS = 0;

-- STUDENTS
CREATE TABLE IF NOT EXISTS students (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    reg_no        VARCHAR(20)  NOT NULL UNIQUE,
    department    VARCHAR(100) NOT NULL,
    year          TINYINT(1)   NOT NULL,
    section       VARCHAR(5)   NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    face_id       VARCHAR(255) NULL,
    face_image_url VARCHAR(500) NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_students_email (email),
    INDEX idx_students_reg_no (reg_no)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- FACULTY
CREATE TABLE IF NOT EXISTS faculty (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_faculty_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ADMINS
CREATE TABLE IF NOT EXISTS admins (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- CLASSROOMS
CREATE TABLE IF NOT EXISTS classrooms (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    room_name        VARCHAR(50)  NOT NULL UNIQUE,
    ble_uuid         VARCHAR(100) NOT NULL UNIQUE,
    attendance_code  VARCHAR(6)   NULL,
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_classrooms_room_name (room_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- SUBJECTS
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

-- SESSIONS
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
    INDEX idx_sessions_active (is_active),
    INDEX idx_sessions_faculty (faculty_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ATTENDANCE
CREATE TABLE IF NOT EXISTS attendance (
    id               INT AUTO_INCREMENT PRIMARY KEY,
    student_id       INT         NOT NULL,
    classroom_id     INT         NOT NULL,
    subject_id       INT         NOT NULL,
    session_id       INT         NULL,
    date             DATE        NOT NULL,
    time             VARCHAR(10) NOT NULL,
    status           ENUM('present','absent','late') DEFAULT 'present',
    rssi             INT         NULL,
    face_confidence  FLOAT       NULL,
    marked_at        DATETIME    DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_student_session (student_id, session_id),
    FOREIGN KEY (student_id)   REFERENCES students(id)   ON DELETE CASCADE,
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id)   REFERENCES subjects(id)   ON DELETE CASCADE,
    FOREIGN KEY (session_id)   REFERENCES sessions(id)   ON DELETE SET NULL,
    INDEX idx_attendance_student (student_id),
    INDEX idx_attendance_date (date),
    INDEX idx_attendance_session (session_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- Seed: default admin
INSERT IGNORE INTO admins (name, email, password_hash) VALUES
('Admin', 'admin@smartattend.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMeSSa55rFu6a0KQUh1UHC5REi');

-- Seed: default faculty
INSERT IGNORE INTO faculty (name, email, password_hash) VALUES
('Dr. Faculty', 'faculty@smartattend.com', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMeSSa55rFu6a0KQUh1UHC5REi');

-- Seed: classroom beacon
INSERT IGNORE INTO classrooms (room_name, ble_uuid) VALUES
('CLASSROOM_A101', 'A1B2C3D4-E5F6-7890-ABCD-EF1234567890');

-- Seed: subject
INSERT IGNORE INTO subjects (subject_name, subject_code, department, faculty_id) VALUES
('Data Structures', 'CS201', 'Computer Science', 1);

SELECT 'SmartAttend schema loaded successfully!' AS status;
