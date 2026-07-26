"""
SmartAttend — Alembic Migration v10
Extends the `sessions` table with:
  - department, year, section  (class targeting)
  - attendance_radius          (BLE range in metres, default 20)
  - duration_minutes           (session length, default 15)
  - session_name               (auto-generated label)
  - status                     ('active' | 'closed', mirrors is_active)

Revision: g4h5i6j7k8l9
Down revision: f3g4h5i6j7k8
"""

from alembic import op
import sqlalchemy as sa

revision       = 'g4h5i6j7k8l9'
down_revision  = 'f3g4h5i6j7k8'
branch_labels  = None
depends_on     = None


def upgrade():
    # ── sessions table extensions ─────────────────────────────
    with op.batch_alter_table('sessions') as batch_op:
        batch_op.add_column(
            sa.Column('department', sa.String(100), nullable=True)
        )
        batch_op.add_column(
            sa.Column('year', sa.Integer(), nullable=True)
        )
        batch_op.add_column(
            sa.Column('section', sa.String(5), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                'attendance_radius',
                sa.Integer(),
                nullable=False,
                server_default='20',
            )
        )
        batch_op.add_column(
            sa.Column(
                'duration_minutes',
                sa.Integer(),
                nullable=False,
                server_default='15',
            )
        )
        batch_op.add_column(
            sa.Column('session_name', sa.String(200), nullable=True)
        )
        batch_op.add_column(
            sa.Column(
                'status',
                sa.String(20),
                nullable=False,
                server_default='active',
            )
        )

    # Back-fill status from is_active
    op.execute(
        "UPDATE sessions SET status = CASE WHEN is_active = 1 THEN 'active' ELSE 'closed' END"
    )


def downgrade():
    with op.batch_alter_table('sessions') as batch_op:
        batch_op.drop_column('status')
        batch_op.drop_column('session_name')
        batch_op.drop_column('duration_minutes')
        batch_op.drop_column('attendance_radius')
        batch_op.drop_column('section')
        batch_op.drop_column('year')
        batch_op.drop_column('department')
