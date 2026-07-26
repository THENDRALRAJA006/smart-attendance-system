"""v9_admin_extensions

Revision ID: f3g4h5i6j7k8
Revises: e2f3a4b5c6d7
Create Date: 2026-07-22 22:00:00.000000

Changes:
  - Add is_active (default True) to students table
  - Add is_active (default True) + phone_number to faculty table
  - Add is_active (default True) + phone_number to admins table
  - Create audit_logs table
  - Create system_settings table with default seed values
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "f3g4h5i6j7k8"
down_revision: Union[str, Sequence[str], None] = "e2f3a4b5c6d7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. students: add is_active ────────────────────────────
    op.add_column(
        "students",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )

    # ── 2. faculty: add is_active + phone_number ──────────────
    op.add_column(
        "faculty",
        sa.Column("phone_number", sa.String(20), nullable=True),
    )
    op.add_column(
        "faculty",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )

    # ── 3. admins: add is_active + phone_number ───────────────
    op.add_column(
        "admins",
        sa.Column("phone_number", sa.String(20), nullable=True),
    )
    op.add_column(
        "admins",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )

    # ── 4. audit_logs table ───────────────────────────────────
    op.create_table(
        "audit_logs",
        sa.Column("id",          sa.Integer,      primary_key=True, autoincrement=True),
        sa.Column("actor_id",    sa.Integer,      nullable=True),
        sa.Column("actor_name",  sa.String(100),  nullable=True),
        sa.Column("actor_role",  sa.String(20),   nullable=False, server_default="admin"),
        sa.Column("action",      sa.String(100),  nullable=False),
        sa.Column("target_type", sa.String(50),   nullable=True),
        sa.Column("target_id",   sa.Integer,      nullable=True),
        sa.Column("detail",      sa.Text,         nullable=True),
        sa.Column("ip_address",  sa.String(45),   nullable=True),
        sa.Column("user_agent",  sa.String(500),  nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime,
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index("ix_al_actor_id",    "audit_logs", ["actor_id"])
    op.create_index("ix_al_action",      "audit_logs", ["action"])
    op.create_index("ix_al_target_type", "audit_logs", ["target_type"])
    op.create_index("ix_al_created_at",  "audit_logs", ["created_at"])

    # ── 5. system_settings table ──────────────────────────────
    op.create_table(
        "system_settings",
        sa.Column("id",         sa.Integer,     primary_key=True, autoincrement=True),
        sa.Column("key",        sa.String(100), nullable=False, unique=True),
        sa.Column("value",      sa.Text,        nullable=True),
        sa.Column("category",   sa.String(30),  nullable=False, server_default="general"),
        sa.Column("label",      sa.String(200), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime,
            nullable=True,
            server_default=sa.text("CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index("ix_ss_key",      "system_settings", ["key"],      unique=True)
    op.create_index("ix_ss_category", "system_settings", ["category"])

    # ── 6. Seed default system settings ───────────────────────
    op.bulk_insert(
        sa.table(
            "system_settings",
            sa.column("key",      sa.String),
            sa.column("value",    sa.String),
            sa.column("category", sa.String),
            sa.column("label",    sa.String),
        ),
        [
            {"key": "college_name",           "value": "SmartAttend College",       "category": "general",    "label": "College Name"},
            {"key": "college_logo_url",       "value": "",                          "category": "general",    "label": "College Logo URL"},
            {"key": "timezone",               "value": "Asia/Kolkata",              "category": "general",    "label": "Timezone"},
            {"key": "working_days",           "value": "Mon,Tue,Wed,Thu,Fri",       "category": "attendance", "label": "Working Days"},
            {"key": "attendance_window_min",  "value": "30",                        "category": "attendance", "label": "Attendance Window (minutes)"},
            {"key": "min_attendance_pct",     "value": "75",                        "category": "attendance", "label": "Minimum Attendance %"},
            {"key": "face_match_threshold",   "value": "0.75",                      "category": "face",       "label": "Face Match Threshold"},
            {"key": "face_review_threshold",  "value": "0.65",                      "category": "face",       "label": "Face Review Threshold"},
            {"key": "ble_rssi_threshold",     "value": "-80",                       "category": "ble",        "label": "BLE RSSI Threshold (dBm)"},
            {"key": "session_device_dedup",   "value": "true",                      "category": "security",   "label": "Session Device Deduplication"},
            {"key": "max_login_attempts",     "value": "5",                         "category": "security",   "label": "Max Login Attempts"},
            {"key": "jwt_expiry_minutes",     "value": "60",                        "category": "security",   "label": "JWT Expiry (minutes)"},
        ],
    )


def downgrade() -> None:
    op.drop_table("system_settings")
    op.drop_table("audit_logs")
    op.drop_column("admins",   "is_active")
    op.drop_column("admins",   "phone_number")
    op.drop_column("faculty",  "is_active")
    op.drop_column("faculty",  "phone_number")
    op.drop_column("students", "is_active")
