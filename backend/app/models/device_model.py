# ============================================================
# SmartAttend — DeviceBinding ORM Model (v7)
# Permanently ties a student account to one Android device.
# Separate from AttendanceDeviceLog (session-scoped, in models.py).
# ============================================================

import enum
from sqlalchemy import Column, Integer, String, DateTime, Enum as SAEnum, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class DeviceStatus(str, enum.Enum):
    active           = "active"
    inactive         = "inactive"
    pending_transfer = "pending_transfer"


class DeviceBinding(Base):
    """
    Permanent binding between one student account and one Android device.

    A student can own exactly one active DeviceBinding at a time.
    Transfers are admin-approved: status moves to pending_transfer, then a new
    binding is created when the student logs in on the new device.

    Key identifiers stored:
    - android_id:        Android ANDROID_ID (hardware, survives most resets)
    - installation_uuid: Generated on first install, stored in EncryptedSharedPrefs
    - app_set_id:        Google App Set ID (per-device, per-app-store-account)
    - public_key:        EC P-256 public key (PEM) for signature verification

    Never changes between logins; survives app reinstall if
    EncryptedSharedPreferences are backed up.
    """
    __tablename__ = "device_bindings"

    id                = Column(Integer, primary_key=True, index=True)
    student_id        = Column(
        Integer,
        ForeignKey("students.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,   # One binding per student
        index=True,
    )

    # ── Android identifiers ───────────────────────────────────
    installation_uuid = Column(String(36), nullable=False, index=True)
    android_id        = Column(String(64), nullable=False, index=True)
    app_set_id        = Column(String(64), nullable=True)

    # ── Device metadata (informational) ──────────────────────
    manufacturer      = Column(String(64), nullable=True)
    brand             = Column(String(64), nullable=True)
    model             = Column(String(64), nullable=True)
    android_version   = Column(String(16), nullable=True)
    app_version       = Column(String(16), nullable=True)

    # ── Cryptographic public key ──────────────────────────────
    # EC P-256 keypair generated in Android Keystore.
    # Only the public key (PEM) is stored here.
    public_key        = Column(String(1000), nullable=True)

    # ── Status machine: active → pending_transfer → (new active) ─
    status            = Column(
        SAEnum(DeviceStatus),
        nullable=False,
        default=DeviceStatus.active,
        server_default=DeviceStatus.active.value,
    )

    # ── Timestamps ────────────────────────────────────────────
    registered_at     = Column(DateTime, nullable=False, default=func.now())
    last_login        = Column(DateTime, nullable=True)

    # ── Relationship ──────────────────────────────────────────
    student = relationship("Student", backref="device_binding")

    def __repr__(self) -> str:
        return (
            f"<DeviceBinding student_id={self.student_id} "
            f"status={self.status} model={self.model}>"
        )
