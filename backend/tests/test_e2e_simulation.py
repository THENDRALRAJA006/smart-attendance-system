# ============================================================
# SmartAttend — E2E Workflow Simulation Script
# Runs a full simulated student journey on AWS RDS database
# ============================================================

import sys
import os
import random
from datetime import datetime
from fastapi.testclient import TestClient

# Add parent directory to path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from main import app
from app.core.database import SessionLocal
from app.models.models import Student, Faculty, Classroom, Subject, Session as SessionModel, Attendance, FaceEmbedding, FaceProfile

def run_e2e_simulation():
    print("==================================================")
    print(" SmartAttend — Starting E2E Simulation")
    print("==================================================")

    # Initialize DB Session
    db = SessionLocal()
    client = TestClient(app)

    # Find existing records for simulation context
    faculty = db.query(Faculty).first()
    classroom = db.query(Classroom).first()
    subject = db.query(Subject).first()

    if not faculty or not classroom or not subject:
        print("x ERROR: DB must be seeded with faculty, classrooms, and subjects first!")
        db.close()
        return False

    print(f"Using faculty: {faculty.name} (ID: {faculty.id})")
    print(f"Using classroom: {classroom.room_name} (ID: {classroom.id})")
    print(f"Using subject: {subject.subject_name} (ID: {subject.id})")

    # Generate unique credentials
    suffix = random.randint(1000, 9999)
    email = f"e2e_student_{suffix}@test.com"
    reg_no = f"E2E-{suffix}"
    password = "StudentPassword@123"
    name = f"E2E Student {suffix}"

    print(f"\nStep 1: Registering new student account...")
    reg_payload = {
        "name": name,
        "reg_no": reg_no,
        "department": subject.department or "Computer Science",
        "year": 2,
        "section": "A",
        "email": email,
        "password": password
    }
    
    reg_resp = client.post("/auth/register", json=reg_payload)
    if reg_resp.status_code != 201:
        print(f"x Registration failed: {reg_resp.text}")
        db.close()
        return False
    
    reg_data = reg_resp.json()
    student_id = reg_data["user"]["id"]
    access_token = reg_data["access_token"]
    student_headers = {"Authorization": f"Bearer {access_token}"}
    print(f"ok Registered student successfully! ID: {student_id}")

    # Load mock face image
    image_path = r"static/faces/99999.jpg"
    if not os.path.exists(image_path):
        print(f"x ERROR: Mock image not found at {image_path}")
        db.close()
        return False
        
    with open(image_path, "rb") as f:
        image_bytes = f.read()

    print(f"\nStep 2: Performing batch auto-capture face registration...")
    # Send 5 frames of the same image to simulate auto-capture
    files = [("files", ("frame_0.jpg", image_bytes, "image/jpeg")) for _ in range(5)]
    
    face_reg_resp = client.post(
        "/auth/face-register-auto",
        files=files,
        headers=student_headers
    )
    if face_reg_resp.status_code != 200:
        print(f"x Face registration failed: {face_reg_resp.text}")
        # Clean up student
        db.query(Student).filter(Student.id == student_id).delete()
        db.commit()
        db.close()
        return False
        
    print(f"ok Face registered successfully! Stored embeddings count: {face_reg_resp.json()['stored']}")

    print(f"\nStep 3: Simulating account login...")
    login_payload = {
        "email": email,
        "password": password,
        "role": "student"
    }
    login_resp = client.post("/auth/login", json=login_payload)
    if login_resp.status_code != 200:
        print(f"x Login failed: {login_resp.text}")
        db.close()
        return False
    print(f"ok Login successful!")

    print(f"\nStep 4: Performing standalone face verification check...")
    verify_file = {"file": ("test_verify.jpg", image_bytes, "image/jpeg")}
    face_verify_resp = client.post(
        "/auth/face-verify",
        files=verify_file,
        headers=student_headers
    )
    if face_verify_resp.status_code != 200:
        print(f"x Face verification endpoint error: {face_verify_resp.text}")
        return False
    
    verify_data = face_verify_resp.json()
    print(f"ok Face Verification check successful! Matched: {verify_data['matched']}, Confidence: {verify_data['confidence']:.2f}%")
    if not verify_data["matched"]:
        print("x ERROR: Face should match registered embeddings.")
        return False

    print(f"\nStep 5: Creating active attendance session...")
    session = SessionModel(
        classroom_id=classroom.id,
        subject_id=subject.id,
        faculty_id=faculty.id,
        attendance_code="123456",
        is_active=True,
        start_time=datetime.now()
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    print(f"ok Created active session ID: {session.id}")

    print(f"\nStep 6: Marking attendance with BLE and Face Verification...")
    mark_payload = {
        "session_id": session.id,
        "rssi": -60 # Within range threshold (-75)
    }
    mark_file = {"file": ("selfie.jpg", image_bytes, "image/jpeg")}
    
    mark_resp = client.post(
        "/attendance/mark",
        data=mark_payload,
        files=mark_file,
        headers=student_headers
    )
    
    if mark_resp.status_code != 200:
        print(f"x Marking attendance failed: {mark_resp.text}")
        # Clean up session
        db.delete(session)
        db.commit()
        return False
        
    mark_data = mark_resp.json()
    print(f"ok Attendance marked successfully! Status: {mark_data.get('tier')}")

    print(f"\nStep 7: Verifying attendance record in database...")
    db.rollback() # Clear SQLAlchemy session cache / transaction to see the fresh insert
    attendance_record = db.query(Attendance).filter(
        Attendance.student_id == student_id,
        Attendance.session_id == session.id
    ).first()
    
    if not attendance_record:
        print("x ERROR: Attendance record not found in DB!")
        return False
    print(f"ok Confirmed database attendance record ID: {attendance_record.id}")

    print(f"\nStep 8: Cleaning up test data from AWS RDS...")
    
    # 1. Delete child attendance records
    db.query(Attendance).filter(Attendance.student_id == student_id).delete()
    db.commit()
    
    # 2. Delete the created session
    db.query(SessionModel).filter(SessionModel.id == session.id).delete()
    db.commit()
    
    # 3. Delete student face embeddings
    db.query(FaceEmbedding).filter(FaceEmbedding.student_id == student_id).delete()
    db.commit()
    
    # 4. Delete face profiles
    db.query(FaceProfile).filter(FaceProfile.student_id == student_id).delete()
    db.commit()
    
    # 5. Delete student record
    db.query(Student).filter(Student.id == student_id).delete()
    db.commit()

    # Clean up any leftover students from previous runs starting with e2e_student_
    leftover_students = db.query(Student).filter(Student.email.like("e2e_student_%")).all()
    for ls in leftover_students:
        try:
            db.query(Attendance).filter(Attendance.student_id == ls.id).delete()
            db.query(FaceEmbedding).filter(FaceEmbedding.student_id == ls.id).delete()
            db.query(FaceProfile).filter(FaceProfile.student_id == ls.id).delete()
            db.delete(ls)
            db.commit()
            print(f"Cleaned up leftover test student ID: {ls.id}")
        except Exception as e:
            db.rollback()
            print(f"Skipped leftover student ID {ls.id} due to: {e}")

    print("ok Cleaned up database successfully.")

    print("\n==================================================")
    print(" ok ALL E2E SIMULATION STEPS COMPLETED SUCCESSFULLY!")
    print("==================================================")
    db.close()
    return True

if __name__ == "__main__":
    success = run_e2e_simulation()
    sys.exit(0 if success else 1)
