"""Phase B #5 — table `subscriptions` (historique de paiement Premium)

Réalise l'entité UML `Subscription` comme historique facturable (montant + dates)
alimentant les analytics revenu/abonnements du tableau de bord admin. Les colonnes
`guides.is_premium`/`premium_until` restent l'état courant (lecture rapide).

Revision ID: 0006_subscriptions_table
Revises: 0005_time_slots_table
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0006_subscriptions_table"
down_revision: Union[str, None] = "0005_time_slots_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "subscriptions",
        sa.Column("id", sa.String(), primary_key=True),
        sa.Column("guide_id", sa.String(), sa.ForeignKey("guides.id", ondelete="CASCADE"), nullable=False),
        sa.Column("tier", sa.String(length=20), nullable=False, server_default="pro"),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False, server_default="MAD"),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="active"),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("CURRENT_TIMESTAMP"), nullable=False),
    )
    op.create_index("idx_subscriptions_guide_id", "subscriptions", ["guide_id"])
    op.create_index("idx_subscriptions_status", "subscriptions", ["status"])
    op.create_index("idx_subscriptions_started_at", "subscriptions", ["started_at"])

    # Backfill : reconstituer un abonnement pour chaque guide actuellement Premium,
    # afin que les analytics ne partent pas de zéro pour les données existantes.
    op.execute(
        """
        INSERT INTO subscriptions (id, guide_id, tier, amount, currency, status, started_at, expires_at, created_at)
        SELECT gen_random_uuid()::text, g.id, 'pro', 399.0, 'MAD',
               CASE WHEN g.premium_until IS NULL OR g.premium_until > CURRENT_TIMESTAMP THEN 'active' ELSE 'expired' END,
               COALESCE(g.premium_until - INTERVAL '30 days', CURRENT_TIMESTAMP),
               COALESCE(g.premium_until, CURRENT_TIMESTAMP + INTERVAL '30 days'),
               CURRENT_TIMESTAMP
        FROM guides g
        WHERE g.is_premium = TRUE
        """
    )


def downgrade() -> None:
    op.drop_index("idx_subscriptions_started_at", table_name="subscriptions")
    op.drop_index("idx_subscriptions_status", table_name="subscriptions")
    op.drop_index("idx_subscriptions_guide_id", table_name="subscriptions")
    op.drop_table("subscriptions")
