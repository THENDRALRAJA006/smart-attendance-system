# ============================================================
# SmartAttend — pytest Fixtures & Test Configuration
# Uses in-memory SQLite database for isolation
# ============================================================

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.database import Base, get_db
from app.core.security import hash_password, create_access_token
from app.models.models import Student, Faculty, Admin, Classroom, Subject
from main import app

# ─── In-Memory SQLite Test Database ─────────────────────────
SQLITE_URL = "sqlite:///./test_smartattend.db"

engine = create_engine(
    SQLITE_URL,
    connect_args={"check_same_thread": False},
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


# ─── Override DB Dependency ──────────────────────────────────
def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db


# ─── Create / Drop Tables ────────────────────────────────────
@pytest.fixture(scope="session", autouse=True)
def setup_database():
    """Create all tables before test session, drop after."""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


# ─── Test Client ─────────────────────────────────────────────
@pytest.fixture(scope="session")
def client():
    """Shared test client for all tests."""
    with TestClient(app) as c:
        yield c


# ─── Test DB Session ─────────────────────────────────────────
@pytest.fixture(scope="function")
def db():
    """Fresh DB session per test."""
    session = TestingSessionLocal()
    yield session
    session.rollback()
    session.close()


# ─── Seed: Admin User ────────────────────────────────────────
@pytest.fixture(scope="session")
def admin_user(setup_database):
    """Create a test admin user."""
    session = TestingSessionLocal()
    admin = Admin(
        name="Test Admin",
        email="admin@test.com",
        password_hash=hash_password("Admin@1234"),
    )
    session.add(admin)
    session.commit()
    session.refresh(admin)
    session.close()
    return admin


# ─── Seed: Faculty User ──────────────────────────────────────
@pytest.fixture(scope="session")
def faculty_user(setup_database):
    """Create a test faculty user."""
    session = TestingSessionLocal()
    faculty = Faculty(
        name="Prof. Smith",
        email="faculty@test.com",
        password_hash=hash_password("Faculty@1234"),
    )
    session.add(faculty)
    session.commit()
    session.refresh(faculty)
    session.close()
    return faculty


# ─── Seed: Student User ──────────────────────────────────────
@pytest.fixture(scope="session")
def student_user(setup_database):
    """Create a test student user."""
    session = TestingSessionLocal()
    student = Student(
        name="Test Student",
        reg_no="CS2021001",
        department="Computer Science",
        year=2,
        section="A",
        email="student@test.com",
        password_hash=hash_password("Student@1234"),
    )
    session.add(student)
    session.commit()
    session.refresh(student)
    session.close()
    return student


# ─── Seed: Classroom ─────────────────────────────────────────
@pytest.fixture(scope="session")
def test_classroom(setup_database):
    """Create a test classroom."""
    session = TestingSessionLocal()
    classroom = Classroom(
        room_name="CLASSROOM_A101",
        ble_uuid="A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    )
    session.add(classroom)
    session.commit()
    session.refresh(classroom)
    session.close()
    return classroom


# ─── JWT Token Helpers ───────────────────────────────────────
@pytest.fixture
def student_token(student_user):
    return create_access_token(subject=student_user.id, role="student")


@pytest.fixture
def faculty_token(faculty_user):
    return create_access_token(subject=faculty_user.id, role="faculty")


@pytest.fixture
def admin_token(admin_user):
    return create_access_token(subject=admin_user.id, role="admin")


@pytest.fixture
def student_headers(student_token):
    return {"Authorization": f"Bearer {student_token}"}


@pytest.fixture
def faculty_headers(faculty_token):
    return {"Authorization": f"Bearer {faculty_token}"}


@pytest.fixture
def admin_headers(admin_token):
    return {"Authorization": f"Bearer {admin_token}"}
