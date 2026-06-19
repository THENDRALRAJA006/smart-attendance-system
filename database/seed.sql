-- ============================================================
-- SmartAttend — Seed Data
-- Run AFTER schema.sql
-- ============================================================

USE smart_attend;

-- ──────────────────────────────────────────────────────────────
-- ADMIN (default: admin@smartattend.com / Admin@123)
-- Bcrypt hash of 'Admin@123'
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO admins (name, email, password_hash) VALUES (
    'System Admin',
    'admin@smartattend.com',
    '$2b$12$pbnaHjh7hdFGFJT0mjy45uYz9BheV8VRU7qsby.m3W7R7vPS0nkzW'
);

-- ──────────────────────────────────────────────────────────────
-- FACULTY (password: Faculty@123)
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO faculty (name, email, password_hash) VALUES
(
    'Dr. Rajesh Kumar',
    'rajesh@smartattend.com',
    '$2b$12$cGM40TC.8mYCt904.JI29OEBBPBpMoh8jbr5XMHP1sEhuSi3r7m2S'
),
(
    'Prof. Anita Singh',
    'anita@smartattend.com',
    '$2b$12$cGM40TC.8mYCt904.JI29OEBBPBpMoh8jbr5XMHP1sEhuSi3r7m2S'
);

-- ──────────────────────────────────────────────────────────────
-- CLASSROOMS (ESP32 BLE Beacons)
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO classrooms (room_name, ble_uuid) VALUES
('CLASSROOM_A101', '12345678-1234-1234-1234-1234567890AB'),
('CLASSROOM_A102', '12345678-1234-1234-1234-1234567890CD'),
('CLASSROOM_B201', '12345678-1234-1234-1234-1234567890EF'),
('LAB_CS01',       '12345678-1234-1234-1234-1234567890FF');

-- ──────────────────────────────────────────────────────────────
-- SUBJECTS
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO subjects (subject_name, subject_code, department, faculty_id) VALUES
('Data Structures & Algorithms', 'CS301', 'Computer Science', 1),
('Database Management Systems', 'CS302', 'Computer Science', 1),
('Operating Systems',            'CS303', 'Computer Science', 2),
('Computer Networks',            'CS304', 'Computer Science', 2),
('Machine Learning',             'CS401', 'Computer Science', 1);

-- ──────────────────────────────────────────────────────────────
-- SAMPLE STUDENT (password: Student@123)
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO students (name, reg_no, department, year, section, email, password_hash) VALUES
(
    'Arjun Sharma',
    '21CS001',
    'Computer Science',
    3,
    'A',
    'arjun@student.com',
    '$2b$12$IdGhRLLvpVPoPIgWR87JrOB9evYQnOgUB1gvBVZui7aqJaliqKgBq'
),
(
    'Priya Patel',
    '21CS002',
    'Computer Science',
    3,
    'A',
    'priya@student.com',
    '$2b$12$IdGhRLLvpVPoPIgWR87JrOB9evYQnOgUB1gvBVZui7aqJaliqKgBq'
);

-- ──────────────────────────────────────────────────────────────
-- NOTE: The password hash above is a placeholder.
-- Generate real hashes with:
--   python -c "from passlib.context import CryptContext; ctx = CryptContext(schemes=['bcrypt']); print(ctx.hash('Admin@123'))"
-- ──────────────────────────────────────────────────────────────

-- ──────────────────────────────────────────────────────────────
-- III AIML-C Semester V Data
-- For class-specific faculty and subject data, run:
--   SOURCE database/v2_aiml_migration.sql
-- This adds 8 faculty, 8 subjects, and faculty_subjects mappings.
-- ──────────────────────────────────────────────────────────────
