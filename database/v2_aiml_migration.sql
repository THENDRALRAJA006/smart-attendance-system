-- ============================================================
-- SmartAttend — V2 Migration: III AIML-C Semester V
-- Run AFTER schema.sql / migrate_fresh.sql
-- ============================================================

USE smart_attendance;

SET FOREIGN_KEY_CHECKS = 0;

-- ──────────────────────────────────────────────────────────────
-- 1. Add department column to faculty (if not exists)
-- ──────────────────────────────────────────────────────────────
ALTER TABLE faculty
  ADD COLUMN department VARCHAR(100) NULL AFTER password_hash;

-- ──────────────────────────────────────────────────────────────
-- 2. Create faculty_subjects junction table
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS faculty_subjects (
    id          INT AUTO_INCREMENT PRIMARY KEY,
    faculty_id  INT NOT NULL,
    subject_id  INT NOT NULL,

    UNIQUE KEY uq_faculty_subject (faculty_id, subject_id),

    FOREIGN KEY (faculty_id) REFERENCES faculty(id) ON DELETE CASCADE,
    FOREIGN KEY (subject_id) REFERENCES subjects(id) ON DELETE CASCADE,

    INDEX idx_fs_faculty (faculty_id),
    INDEX idx_fs_subject (subject_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ──────────────────────────────────────────────────────────────
-- 3. Create class_timetable table
-- ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS class_timetable (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    class_name    VARCHAR(50)  NOT NULL COMMENT 'e.g. III AIML-C',
    semester      TINYINT      NOT NULL COMMENT 'e.g. 5',
    day_of_week   ENUM('Monday','Tuesday','Wednesday','Thursday','Friday','Saturday') NOT NULL,
    period        TINYINT      NOT NULL COMMENT 'Period number (1-8)',
    subject_id    INT          NOT NULL,
    faculty_id    INT          NOT NULL,
    classroom_id  INT          NULL,
    start_time    TIME         NOT NULL,
    end_time      TIME         NOT NULL,
    created_at    DATETIME     DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (subject_id)   REFERENCES subjects(id)   ON DELETE CASCADE,
    FOREIGN KEY (faculty_id)   REFERENCES faculty(id)    ON DELETE CASCADE,
    FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE SET NULL,

    INDEX idx_tt_class (class_name, semester),
    INDEX idx_tt_day (day_of_week)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- ──────────────────────────────────────────────────────────────
-- 4. Insert Faculty for III AIML-C
--    Password: Faculty@123
--    Hash: $2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa
-- ──────────────────────────────────────────────────────────────
INSERT IGNORE INTO faculty (name, email, password_hash, department) VALUES
('Ms. Nikitha B',          'nikitha@smartattend.com',      '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Mrs. Starlin M.A',       'starlin@smartattend.com',      '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Mr. Shree Mahesh K',     'shreemahesh@smartattend.com',  '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Ms. Ramya M',             'ramya@smartattend.com',        '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Dr. M.R. Ajaypradeep N', 'ajaypradeep@smartattend.com',  '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Dr. C. Subashini',        'subashini@smartattend.com',    '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Mr. Rajkumar V',          'rajkumar@smartattend.com',     '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML'),
('Mrs. Lizy A',             'lizy@smartattend.com',         '$2b$12$TgZYYhfemUCTGcyIab0eauEJLdyrQ/Hne/EF6ZAyiP./FtZba55xa', 'AI & ML');

-- ──────────────────────────────────────────────────────────────
-- 5. Insert Subjects for III AIML-C Semester V
--    faculty_id references the primary faculty for the subject
-- ──────────────────────────────────────────────────────────────
-- We need the faculty IDs. Using email lookups via subqueries.

INSERT IGNORE INTO subjects (subject_name, subject_code, department, faculty_id) VALUES
(
    'Deep Learning', 'AD23511', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'nikitha@smartattend.com')
),
(
    'Computer Networks', 'CS23511', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'starlin@smartattend.com')
),
(
    'Natural Language Processing', 'AL23531', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'shreemahesh@smartattend.com')
),
(
    'Business Analytics', 'CB23531', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'ramya@smartattend.com')
),
(
    'Disaster Risk Reduction and Management', 'MX23511', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'subashini@smartattend.com')
),
(
    'Big Data Analytics', 'AD23V12', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'rajkumar@smartattend.com')
),
(
    'Exploratory Data Analysis', 'AL23V11', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'lizy@smartattend.com')
),
(
    'Tableau - Data Visualization', 'AD23JC3', 'AI & ML',
    (SELECT id FROM faculty WHERE email = 'starlin@smartattend.com')
);

-- ──────────────────────────────────────────────────────────────
-- 6. Link faculty ↔ subjects via junction table
--    This supports many-to-many (e.g. NLP has 2 faculty)
-- ──────────────────────────────────────────────────────────────

-- Deep Learning (AD23511) → Ms. Nikitha B
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'nikitha@smartattend.com' AND s.subject_code = 'AD23511';

-- Computer Networks (CS23511) → Mrs. Starlin M.A
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'starlin@smartattend.com' AND s.subject_code = 'CS23511';

-- Natural Language Processing (AL23531) → Mr. Shree Mahesh K
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'shreemahesh@smartattend.com' AND s.subject_code = 'AL23531';

-- Natural Language Processing (AL23531) → Ms. Ramya M
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'ramya@smartattend.com' AND s.subject_code = 'AL23531';

-- Business Analytics (CB23531) → Ms. Ramya M
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'ramya@smartattend.com' AND s.subject_code = 'CB23531';

-- Business Analytics (CB23531) → Dr. M.R. Ajaypradeep N
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'ajaypradeep@smartattend.com' AND s.subject_code = 'CB23531';

-- Disaster Risk Reduction and Management (MX23511) → Dr. C. Subashini
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'subashini@smartattend.com' AND s.subject_code = 'MX23511';

-- Big Data Analytics (AD23V12) → Mr. Rajkumar V
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'rajkumar@smartattend.com' AND s.subject_code = 'AD23V12';

-- Exploratory Data Analysis (AL23V11) → Mrs. Lizy A
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'lizy@smartattend.com' AND s.subject_code = 'AL23V11';

-- Tableau - Data Visualization (AD23JC3) → Mrs. Starlin M.A
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'starlin@smartattend.com' AND s.subject_code = 'AD23JC3';


-- ──────────────────────────────────────────────────────────────
-- Verification queries (uncomment to test)
-- ──────────────────────────────────────────────────────────────
-- SELECT f.name AS faculty, s.subject_name, s.subject_code
-- FROM faculty_subjects fs
-- JOIN faculty f ON fs.faculty_id = f.id
-- JOIN subjects s ON fs.subject_id = s.id
-- ORDER BY f.name;

SELECT 'V2 Migration complete — III AIML-C Semester V loaded!' AS status;
