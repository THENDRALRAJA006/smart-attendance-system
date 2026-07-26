"""v8_attendance_device_log

Revision ID: e2f3a4b5c6d7
Revises: d1e2f3a4b5c6
Create Date: 2026-07-22 21:00:00.000000

Changes:
  - Create ``attendance_device_log`` table.
  - Records which Android device (ANDROID_ID) was used per attendance session.
  - Unique constraint (session_id, device_id) prevents two students using
    the same phone in the same class session.
  - Scoped to session only — the phone is free in any other session.
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e2f3a4b5c6d7"
down_revision: Union[str, Sequence[str], None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    v8 — Session-scoped Device Deduplication:
    Create attendance_device_log table.
    One row per (session_id, device_id) pair.
    The unique index enforces the "one phone per session" rule at DB level.
    """
    op.create_table(
        "attendance_device_log",

        # ── Primary key ───────────────────────────────────────
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),

        # ── Foreign keys ──────────────────────────────────────
        sa.Column(
            "session_id",
            sa.Integer,
            sa.ForeignKey("sessions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "student_id",
            sa.Integer,
            sa.ForeignKey("students.id", ondelete="CASCADE"),
            nullable=False,
        ),

        # ── Device identifier ─────────────────────────────────
        sa.Column("device_id", sa.String(64), nullable=False),

        # ── Timestamp ─────────────────────────────────────────
        sa.Column(
            "attendance_time",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )

    # ── Indexes ───────────────────────────────────────────────
    op.create_index(
        "ix_adl_session_id",
        "attendance_device_log",
        ["session_id"],
        unique=False,
    )
    op.create_index(
        "ix_adl_student_id",
        "attendance_device_log",
        ["student_id"],
        unique=False,
    )
    op.create_index(
        "ix_adl_device_id",
        "attendance_device_log",
        ["device_id"],
        unique=False,
    )
    # ── Core uniqueness constraint: one device per session ────
    op.create_index(
        "uq_device_session",
        "attendance_device_log",
        ["session_id", "device_id"],
        unique=True,
    )


def downgrade() -> None:
    """Drop attendance_device_log table and its indexes."""
    op.drop_index("uq_device_session",   table_name="attendance_device_log")
    op.drop_index("ix_adl_device_id",    table_name="attendance_device_log")
    op.drop_index("ix_adl_student_id",   table_name="attendance_device_log")
    op.drop_index("ix_adl_session_id",   table_name="attendance_device_log")
    op.drop_table("attendance_device_log")
