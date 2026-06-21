-- ============================================================
-- SmartAttend — RIT AIML Production Seed SQL
-- College  : Rajalakshmi Institute of Technology
-- Dept     : Artificial Intelligence & Machine Learning
-- Class    : III AIML C  |  Semester: V
-- Generated: 2026-06-20
-- ============================================================
-- Run: mysql -h <RDS_HOST> -u admin -p smart_attendance < seed_rit_aiml.sql
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────────────────
-- 1. ADMIN
-- ─────────────────────────────────────────────────────────────
-- Password: Admin@1234 (bcrypt hash)
INSERT INTO admins (name, email, password_hash, created_at)
VALUES (
  'Super Admin RIT',
  'admin@smartattend.com',
  '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMUJamed3/btrIxnLqDGsa.PGC',
  NOW()
)
ON DUPLICATE KEY UPDATE
  name          = VALUES(name),
  password_hash = VALUES(password_hash);

-- ─────────────────────────────────────────────────────────────
-- 2. FACULTY  (password: Faculty@123)
-- ─────────────────────────────────────────────────────────────
-- NOTE: bcrypt hashes are generated at runtime by the Python seed script.
-- These are placeholder hashes for SQL export reference only.
-- Use the Python seed script for accurate bcrypt hashes.
INSERT INTO faculty (name, email, password_hash, department, created_at) VALUES
('Nikitha B',      'nikitha@smartattend.com',      '$2b$12$placeholder_nikitha_hash_xxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Starlin M.A',    'starlin@smartattend.com',      '$2b$12$placeholder_starlin_hash_xxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Shree Mahesh K', 'shreemahesh@smartattend.com',  '$2b$12$placeholder_shreemahesh_hash_xxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Ramya M',        'ramya@smartattend.com',        '$2b$12$placeholder_ramya_hash_xxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Ajaypradeep N',  'ajaypradeep@smartattend.com',  '$2b$12$placeholder_ajaypradeep_hash_xxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('C Subashini',    'subashini@smartattend.com',    '$2b$12$placeholder_subashini_hash_xxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Rajkumar V',     'rajkumar@smartattend.com',     '$2b$12$placeholder_rajkumar_hash_xxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Lizy A',         'lizy@smartattend.com',         '$2b$12$placeholder_lizy_hash_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Divya M',        'divya@smartattend.com',        '$2b$12$placeholder_divya_hash_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW()),
('Lavanya',        'lavanya@smartattend.com',      '$2b$12$placeholder_lavanya_hash_xxxxxxxxxxxxxxxxxxxxxxx', 'Artificial Intelligence and Machine Learning', NOW())
ON DUPLICATE KEY UPDATE
  name          = VALUES(name),
  department    = VALUES(department);

-- ─────────────────────────────────────────────────────────────
-- 3. SUBJECTS
-- ─────────────────────────────────────────────────────────────
-- faculty_id references are resolved by subquery on email
INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Deep Learning', 'AD23511', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'nikitha@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Computer Networks', 'CS23511', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'starlin@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Natural Language Processing', 'AL23531', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'shreemahesh@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Business Analytics', 'CB23531', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'ramya@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Disaster Risk Reduction and Management', 'MX23511', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'ajaypradeep@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Big Data Analytics', 'AD23V12', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'rajkumar@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Exploratory Data Analysis', 'AL23V11', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'lizy@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Tableau Data Visualization', 'AD23IC3', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'divya@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Deep Learning Laboratory', 'AD23521', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'nikitha@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

INSERT INTO subjects (subject_name, subject_code, department, faculty_id, created_at)
SELECT 'Computer Networks Laboratory', 'CS23521', 'Artificial Intelligence and Machine Learning', id, NOW()
FROM faculty WHERE email = 'starlin@smartattend.com'
ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), faculty_id = VALUES(faculty_id);

-- ─────────────────────────────────────────────────────────────
-- 4. CLASSROOMS
-- ─────────────────────────────────────────────────────────────
INSERT INTO classrooms (room_name, ble_uuid, created_at) VALUES
('CLASSROOM_A101', UUID(), NOW()),
('CLASSROOM_A102', UUID(), NOW()),
('LAB_DL',         UUID(), NOW()),
('LAB_CN',         UUID(), NOW()),
('LAB_NLP',        UUID(), NOW())
ON DUPLICATE KEY UPDATE room_name = VALUES(room_name);

-- ─────────────────────────────────────────────────────────────
-- 5. FACULTY–SUBJECT LINKS
-- ─────────────────────────────────────────────────────────────
INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'nikitha@smartattend.com'   AND s.subject_code = 'AD23511';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'starlin@smartattend.com'   AND s.subject_code = 'CS23511';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'shreemahesh@smartattend.com' AND s.subject_code = 'AL23531';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'ramya@smartattend.com'     AND s.subject_code = 'CB23531';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'ajaypradeep@smartattend.com' AND s.subject_code = 'MX23511';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'rajkumar@smartattend.com'  AND s.subject_code = 'AD23V12';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'lizy@smartattend.com'      AND s.subject_code = 'AL23V11';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'divya@smartattend.com'     AND s.subject_code = 'AD23IC3';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'nikitha@smartattend.com'   AND s.subject_code = 'AD23521';

INSERT IGNORE INTO faculty_subjects (faculty_id, subject_id)
SELECT f.id, s.id FROM faculty f, subjects s
WHERE f.email = 'starlin@smartattend.com'   AND s.subject_code = 'CS23521';

-- ─────────────────────────────────────────────────────────────
-- 6. STUDENTS (112) — password: Student@123
-- ─────────────────────────────────────────────────────────────
INSERT INTO students (name, reg_no, email, password_hash, department, year, section, created_at) VALUES
('Student 001','AIML001','aiml001@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 002','AIML002','aiml002@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 003','AIML003','aiml003@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 004','AIML004','aiml004@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 005','AIML005','aiml005@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 006','AIML006','aiml006@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 007','AIML007','aiml007@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 008','AIML008','aiml008@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 009','AIML009','aiml009@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 010','AIML010','aiml010@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 011','AIML011','aiml011@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 012','AIML012','aiml012@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 013','AIML013','aiml013@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 014','AIML014','aiml014@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 015','AIML015','aiml015@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 016','AIML016','aiml016@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 017','AIML017','aiml017@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 018','AIML018','aiml018@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 019','AIML019','aiml019@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 020','AIML020','aiml020@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 021','AIML021','aiml021@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 022','AIML022','aiml022@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 023','AIML023','aiml023@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 024','AIML024','aiml024@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 025','AIML025','aiml025@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 026','AIML026','aiml026@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 027','AIML027','aiml027@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 028','AIML028','aiml028@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 029','AIML029','aiml029@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 030','AIML030','aiml030@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 031','AIML031','aiml031@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 032','AIML032','aiml032@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 033','AIML033','aiml033@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 034','AIML034','aiml034@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 035','AIML035','aiml035@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 036','AIML036','aiml036@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 037','AIML037','aiml037@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 038','AIML038','aiml038@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 039','AIML039','aiml039@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 040','AIML040','aiml040@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 041','AIML041','aiml041@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 042','AIML042','aiml042@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 043','AIML043','aiml043@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 044','AIML044','aiml044@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 045','AIML045','aiml045@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 046','AIML046','aiml046@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 047','AIML047','aiml047@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 048','AIML048','aiml048@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 049','AIML049','aiml049@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 050','AIML050','aiml050@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 051','AIML051','aiml051@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 052','AIML052','aiml052@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 053','AIML053','aiml053@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 054','AIML054','aiml054@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 055','AIML055','aiml055@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 056','AIML056','aiml056@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 057','AIML057','aiml057@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 058','AIML058','aiml058@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 059','AIML059','aiml059@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 060','AIML060','aiml060@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 061','AIML061','aiml061@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 062','AIML062','aiml062@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 063','AIML063','aiml063@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 064','AIML064','aiml064@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 065','AIML065','aiml065@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 066','AIML066','aiml066@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 067','AIML067','aiml067@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 068','AIML068','aiml068@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 069','AIML069','aiml069@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 070','AIML070','aiml070@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 071','AIML071','aiml071@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 072','AIML072','aiml072@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 073','AIML073','aiml073@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 074','AIML074','aiml074@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 075','AIML075','aiml075@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 076','AIML076','aiml076@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 077','AIML077','aiml077@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 078','AIML078','aiml078@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 079','AIML079','aiml079@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 080','AIML080','aiml080@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 081','AIML081','aiml081@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 082','AIML082','aiml082@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 083','AIML083','aiml083@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 084','AIML084','aiml084@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 085','AIML085','aiml085@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 086','AIML086','aiml086@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 087','AIML087','aiml087@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 088','AIML088','aiml088@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 089','AIML089','aiml089@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 090','AIML090','aiml090@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 091','AIML091','aiml091@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 092','AIML092','aiml092@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 093','AIML093','aiml093@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 094','AIML094','aiml094@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 095','AIML095','aiml095@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 096','AIML096','aiml096@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 097','AIML097','aiml097@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 098','AIML098','aiml098@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 099','AIML099','aiml099@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 100','AIML100','aiml100@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 101','AIML101','aiml101@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 102','AIML102','aiml102@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 103','AIML103','aiml103@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 104','AIML104','aiml104@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 105','AIML105','aiml105@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 106','AIML106','aiml106@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 107','AIML107','aiml107@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 108','AIML108','aiml108@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 109','AIML109','aiml109@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 110','AIML110','aiml110@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 111','AIML111','aiml111@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW()),
('Student 112','AIML112','aiml112@smartattend.com','$2b$12$StudentPasswordHash_placeholder_xxxxxxxxxxxxxxxx','Artificial Intelligence and Machine Learning',3,'C',NOW())
ON DUPLICATE KEY UPDATE name = VALUES(name), department = VALUES(department);

SET FOREIGN_KEY_CHECKS = 1;

-- ─────────────────────────────────────────────────────────────
-- CREDENTIAL REFERENCE
-- ─────────────────────────────────────────────────────────────
/*
ADMIN LOGIN
  Email   : admin@smartattend.com
  Password: Admin@1234

FACULTY LOGINS  (all use: Faculty@123)
  nikitha@smartattend.com      -> Nikitha B       -> Deep Learning
  starlin@smartattend.com      -> Starlin M.A     -> Computer Networks
  shreemahesh@smartattend.com  -> Shree Mahesh K  -> NLP
  ramya@smartattend.com        -> Ramya M         -> Business Analytics
  ajaypradeep@smartattend.com  -> Ajaypradeep N   -> Disaster Risk Mgmt
  subashini@smartattend.com    -> C Subashini      -> (unassigned)
  rajkumar@smartattend.com     -> Rajkumar V      -> Big Data Analytics
  lizy@smartattend.com         -> Lizy A          -> Exploratory Data Analysis
  divya@smartattend.com        -> Divya M         -> Tableau Visualization
  lavanya@smartattend.com      -> Lavanya         -> (unassigned)

STUDENT LOGINS  (all use: Student@123)
  aiml001@smartattend.com  (reg: AIML001)
  aiml002@smartattend.com  (reg: AIML002)
  ...
  aiml112@smartattend.com  (reg: AIML112)

NOTE: SQL file uses placeholder bcrypt hashes.
      Run the Python seed script for real hashes in production.
*/
