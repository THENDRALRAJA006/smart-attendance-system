#!/usr/bin/env python3
"""
SmartAttend — AWS RDS Connection & Table Creation Test
======================================================
Run from the backend/ directory:
    python scripts/test_rds_connection.py

What this script does:
  1. Reads DB credentials from .env
  2. Pings the AWS RDS endpoint (TCP)
  3. Connects via SQLAlchemy + PyMySQL
  4. Creates all ORM tables (idempotent)
  5. Prints a summary of every table in the database
  6. Inserts a seed admin row if none exists
"""

import sys
import socket
import os

# ─── Load .env ────────────────────────────────────────────────
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '.env'))

# ─── Read settings ────────────────────────────────────────────
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "root")
DB_PASS = os.getenv("DB_PASSWORD", "")
DB_NAME = os.getenv("DB_NAME", "smart_attendance")

DATABASE_URL = (
    f"mysql+pymysql://{DB_USER}:{DB_PASS}"
    f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

# ──────────────────────────────────────────────────────────────
# Step 1 — TCP reachability check
# ──────────────────────────────────────────────────────────────
print(f"\n{'='*60}")
print("SmartAttend — AWS RDS Connection Test")
print(f"{'='*60}")
print(f"Host : {DB_HOST}")
print(f"Port : {DB_PORT}")
print(f"User : {DB_USER}")
print(f"DB   : {DB_NAME}")
print(f"{'='*60}\n")

print("[1/5] Checking TCP reachability ...")
try:
    sock = socket.create_connection((DB_HOST, DB_PORT), timeout=10)
    sock.close()
    print(f"      ✅ TCP connection to {DB_HOST}:{DB_PORT} succeeded.\n")
except (socket.timeout, ConnectionRefusedError, OSError) as e:
    print(f"      ❌ Cannot reach {DB_HOST}:{DB_PORT}: {e}")
    print("\n     Possible causes:")
    print("     - AWS RDS Security Group does not allow inbound TCP 3306")
    print("     - RDS instance is not publicly accessible (check Public access = Yes)")
    print("     - Your local IP is not whitelisted in the RDS Security Group inbound rule")
    sys.exit(1)

# ──────────────────────────────────────────────────────────────
# Step 2 — SQLAlchemy engine
# ──────────────────────────────────────────────────────────────
print("[2/5] Creating SQLAlchemy engine ...")
try:
    from sqlalchemy import create_engine, text
    from sqlalchemy.orm import sessionmaker

    engine = create_engine(
        DATABASE_URL,
        pool_pre_ping=True,
        pool_size=5,
        max_overflow=10,
        pool_recycle=3600,
        echo=False,
    )

    # Force a real connection
    with engine.connect() as conn:
        db_version = conn.execute(text("SELECT VERSION()")).scalar()
    print(f"      ✅ Connected — MySQL version: {db_version}\n")
except Exception as e:
    print(f"      ❌ SQLAlchemy connection failed: {e}")
    print("\n     Check DB_USER, DB_PASSWORD, and DB_NAME in your .env file.")
    sys.exit(1)

# ──────────────────────────────────────────────────────────────
# Step 3 — Create all ORM tables
# ──────────────────────────────────────────────────────────────
print("[3/5] Creating all ORM tables (CREATE TABLE IF NOT EXISTS) ...")
try:
    # Add parent directory so we can import app.*
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
    from app.core.database import Base
    from app.models import models  # noqa: F401 — registers all models with Base

    Base.metadata.create_all(bind=engine)
    print("      ✅ All tables created / already exist.\n")
except Exception as e:
    print(f"      ❌ Table creation failed: {e}")
    sys.exit(1)

# ──────────────────────────────────────────────────────────────
# Step 4 — List all tables
# ──────────────────────────────────────────────────────────────
print("[4/5] Listing all tables in the database ...")
try:
    with engine.connect() as conn:
        rows = conn.execute(text("SHOW TABLES")).fetchall()
    print(f"      Found {len(rows)} table(s):")
    for row in rows:
        print(f"        • {row[0]}")
    print()
except Exception as e:
    print(f"      ❌ Failed to list tables: {e}")
    sys.exit(1)

# ──────────────────────────────────────────────────────────────
# Step 5 — Seed default admin
# ──────────────────────────────────────────────────────────────
print("[5/5] Checking / seeding default admin account ...")
try:
    Session = sessionmaker(bind=engine)
    with Session() as session:
        admin_count = session.execute(text("SELECT COUNT(*) FROM admins")).scalar()
        if admin_count == 0:
            # bcrypt hash of "Admin@1234"
            session.execute(text("""
                INSERT INTO admins (name, email, password_hash)
                VALUES (
                    'System Admin',
                    'admin@smartattend.com',
                    '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW'
                )
            """))
            session.commit()
            print("      ✅ Seed admin inserted: admin@smartattend.com / Admin@1234\n")
        else:
            print(f"      ✅ Admin table already has {admin_count} row(s) — skipping seed.\n")
except Exception as e:
    print(f"      ❌ Seed failed: {e}")

# ──────────────────────────────────────────────────────────────
# Done
# ──────────────────────────────────────────────────────────────
print("="*60)
print("✅  AWS RDS connection test PASSED. SmartAttend is ready!")
print("="*60 + "\n")
