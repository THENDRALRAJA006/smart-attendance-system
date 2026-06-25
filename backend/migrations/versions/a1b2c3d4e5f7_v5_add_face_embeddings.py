"""v5_add_face_embeddings

Revision ID: a1b2c3d4e5f7
Revises: a1b2c3d4e5f6
Create Date: 2026-06-23 12:00:00.000000
"""
from typing import Sequence, Union

# pyrefly: ignore [missing-import]
import sqlalchemy as sa
# pyrefly: ignore [missing-import]
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a1b2c3d4e5f7"
down_revision: Union[str, Sequence[str], None] = "a1b2c3d4e5f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Create face_embeddings table."""
    op.create_table(
        "face_embeddings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("student_id", sa.Integer(), nullable=False),
        sa.Column("embedding_json", sa.JSON(), nullable=False),
        sa.Column("pose_name", sa.String(length=50), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=True, server_default=sa.text("CURRENT_TIMESTAMP")),
        
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(
            ["student_id"], ["students.id"],
            name="fk_face_embeddings_student_id",
            ondelete="CASCADE",
        )
    )
    op.create_index("ix_face_embeddings_student_id", "face_embeddings", ["student_id"])


def downgrade() -> None:
    """Drop face_embeddings table."""
    op.drop_index("ix_face_embeddings_student_id", table_name="face_embeddings")
    op.drop_table("face_embeddings")
