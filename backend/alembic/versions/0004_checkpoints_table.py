"""Phase B #3 — table `checkpoints` (promotion du JSON en table)

Promeut `guide_routes.checkpoints` (JSONB) en table propre (relation
Route 1—0..* Checkpoint). La colonne JSON est CONSERVÉE (dénormalisation de
compat réponse) ; la table est la source canonique. UML étape 10/11.

Revision ID: 0004_checkpoints_table
Revises: 0003_role_administrator
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0004_checkpoints_table"
down_revision: Union[str, None] = "0003_role_administrator"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "checkpoints",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("route_id", sa.String(), sa.ForeignKey("guide_routes.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("lat", sa.Float(), nullable=False),
        sa.Column("lng", sa.Float(), nullable=False),
        sa.Column("type", sa.String(length=20), nullable=False),
        sa.Column("estimated_time", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("idx_checkpoints_route_id", "checkpoints", ["route_id"])

    # Backfill : éclate le JSON existant en lignes (jsonb_array_elements + ordinalité).
    op.execute(
        """
        INSERT INTO checkpoints
            (id, route_id, name, description, lat, lng, type, estimated_time, image_url, position, created_at)
        SELECT
            gen_random_uuid()::text,
            gr.id,
            COALESCE(elem->>'name', 'Checkpoint'),
            COALESCE(elem->>'description', ''),
            COALESCE((elem->>'lat')::float, 0),
            COALESCE((elem->>'lng')::float, 0),
            COALESCE(elem->>'type', 'Monument'),
            COALESCE((elem->>'estimated_time')::int, 0),
            elem->>'image_url',
            (ord - 1)::int,
            CURRENT_TIMESTAMP
        FROM guide_routes gr,
             jsonb_array_elements(gr.checkpoints::jsonb) WITH ORDINALITY AS t(elem, ord)
        WHERE gr.checkpoints IS NOT NULL
          AND jsonb_typeof(gr.checkpoints::jsonb) = 'array'
        """
    )


def downgrade() -> None:
    op.drop_index("idx_checkpoints_route_id", table_name="checkpoints")
    op.drop_table("checkpoints")
