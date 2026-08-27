"""Phase B #4 — table `time_slots` (créneaux programmés, entité nouvelle)

Entité absente de l'ancien schéma. Support de la programmation de trajets et
de la règle RG21 (non-chevauchement, appliquée dans TimeSlotService).
UML étapes 11/12.

Revision ID: 0005_time_slots_table
Revises: 0004_checkpoints_table
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0005_time_slots_table"
down_revision: Union[str, None] = "0004_checkpoints_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "time_slots",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("route_id", sa.String(), sa.ForeignKey("guide_routes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("scheduled_start", sa.DateTime(timezone=True), nullable=False),
        sa.Column("scheduled_end", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="upcoming"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("idx_time_slots_route_id", "time_slots", ["route_id"])
    op.create_index("idx_time_slots_scheduled_start", "time_slots", ["scheduled_start"])


def downgrade() -> None:
    op.drop_index("idx_time_slots_scheduled_start", table_name="time_slots")
    op.drop_index("idx_time_slots_route_id", table_name="time_slots")
    op.drop_table("time_slots")
