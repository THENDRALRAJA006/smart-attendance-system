"""v6_arcface_auto_registration

Revision ID: b2c3d4e5f6a7
Revises: a1b2c3d4e5f7
Create Date: 2026-06-25 12:00:00.000000

Changes:
  - Add embedding_version column to face_embeddings (tracks InsightFace model used)
  - Clean legacy Rekognition comments from student_faces table (data-only, no schema change)
  - No AWS Rekognition tables created or referenced
"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    v6 ArcFace auto-registration migration:
    1. Add embedding_version to face_embeddings — tracks which InsightFace model
       generated the embedding (e.g. 'buffalo_l'). Allows re-processing if model changes.
    2. Make student_faces.image_url and s3_key nullable — these are legacy fields
       no longer written by the auto-capture flow.
    """

    # ─── 1. Add embedding_version to face_embeddings ─────────────
    op.add_column(
        "face_embeddings",
        sa.Column(
            "embedding_version",
            sa.String(length=20),
            nullable=True,
            server_default="buffalo_l",
            comment="InsightFace model name used to generate this embedding",
        ),
    )

    # ─── 2. Make legacy student_faces fields nullable ─────────────
    # These fields (image_url, s3_key) are no longer populated by the
    # new auto-capture registration flow.
    op.alter_column(
        "student_faces",
        "image_url",
        existing_type=sa.String(500),
        nullable=True,
    )
    op.alter_column(
        "student_faces",
        "s3_key",
        existing_type=sa.String(500),
        nullable=True,
    )


def downgrade() -> None:
    """
    v6 downgrade:
    - Remove embedding_version from face_embeddings
    - Restore NOT NULL on student_faces legacy fields
    """
    op.drop_column("face_embeddings", "embedding_version")

    op.alter_column(
        "student_faces",
        "image_url",
        existing_type=sa.String(500),
        nullable=False,
    )
    op.alter_column(
        "student_faces",
        "s3_key",
        existing_type=sa.String(500),
        nullable=False,
    )
