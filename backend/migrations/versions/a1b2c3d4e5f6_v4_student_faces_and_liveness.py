"""v4_student_faces_and_liveness

Revision ID: a1b2c3d4e5f6
Revises: c254aef50dab
Create Date: 2026-06-21 03:00:00.000000

Changes:
  - Creates student_faces table (15-pose face registration storage)
  - Adds liveness_verified, confidence_tier, attendance_method columns to attendance
"""
from typing import Sequence, Union

# pyrefly: ignore [missing-import]
import sqlalchemy as sa
# pyrefly: ignore [missing-import]
from alembic import op


# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f6"
down_revision: Union[str, Sequence[str], None] = "c254aef50dab"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    v4 upgrade:
    1. Create student_faces table — stores all 15 guided-pose images per student
    2. Add liveness_verified, confidence_tier, attendance_method to attendance
    3. Extend attendance.status length to 15 to accommodate 'manual_review'
    """

    # ─── 1. Create student_faces table ───────────────────────
    op.create_table(
        "student_faces",
        sa.Column("id",                sa.Integer(),     nullable=False),
        sa.Column("student_id",        sa.Integer(),     nullable=False),
        sa.Column("face_id",           sa.String(255),   nullable=True),    # Legacy field (unused after ArcFace migration)
        sa.Column("image_url",         sa.String(500),   nullable=True),    # Legacy field (unused)
        sa.Column("s3_key",            sa.String(500),   nullable=True),    # Legacy field (unused)
        sa.Column("pose_index",        sa.Integer(),     nullable=False),   # 1-15
        sa.Column("pose_type",         sa.String(50),    nullable=False),   # front_face, left_15, etc.
        sa.Column("confidence",        sa.Float(),       nullable=True),    # Detection confidence
        sa.Column("is_primary",        sa.Boolean(),     nullable=True,     server_default="0"),  # Best pose flag
        sa.Column("registration_date", sa.DateTime(),    nullable=True,     server_default=sa.text("CURRENT_TIMESTAMP")),

        # Primary key
        sa.PrimaryKeyConstraint("id"),

        # Foreign key to students
        sa.ForeignKeyConstraint(
            ["student_id"], ["students.id"],
            name="fk_student_faces_student_id",
            ondelete="CASCADE",
        ),

        # Unique: one row per (student, pose_index)
        sa.UniqueConstraint("student_id", "pose_index", name="uq_student_pose"),
    )

    # Index for fast lookups by student_id
    op.create_index("ix_student_faces_student_id", "student_faces", ["student_id"])

    # ─── 2. Add liveness columns to attendance ───────────────
    op.add_column(
        "attendance",
        sa.Column("liveness_verified", sa.Boolean(), nullable=True, server_default="0"),
    )
    op.add_column(
        "attendance",
        sa.Column("confidence_tier", sa.String(15), nullable=True, server_default="present"),
    )
    op.add_column(
        "attendance",
        sa.Column("attendance_method", sa.String(20), nullable=True, server_default="ble_face"),
    )

    # ─── 3. Extend attendance.status column ──────────────────
    # MySQL ALTER: change VARCHAR(10) to VARCHAR(15) to fit 'manual_review'
    op.alter_column(
        "attendance",
        "status",
        existing_type=sa.String(10),
        type_=sa.String(15),
        existing_nullable=True,
    )


def downgrade() -> None:
    """
    v4 downgrade:
    - Drop student_faces table
    - Remove liveness columns from attendance
    - Revert attendance.status to VARCHAR(10)
    """
    # Remove liveness columns
    op.drop_column("attendance", "attendance_method")
    op.drop_column("attendance", "confidence_tier")
    op.drop_column("attendance", "liveness_verified")

    # Revert status length
    op.alter_column(
        "attendance",
        "status",
        existing_type=sa.String(15),
        type_=sa.String(10),
        existing_nullable=True,
    )

    # Drop student_faces table
    op.drop_index("ix_student_faces_student_id", table_name="student_faces")
    op.drop_table("student_faces")
