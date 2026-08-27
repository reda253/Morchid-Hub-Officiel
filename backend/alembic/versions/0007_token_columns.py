"""Sécurité — sépare les expirations de tokens et ajoute token_version

`token_expires_at` servait à la fois au token de vérification d'email et au
token de réinitialisation de mot de passe : demander l'un re-datait
silencieusement l'autre. Les deux colonnes sont désormais distinctes.

`token_version` rend les JWT révocables : le claim `tv` est comparé à la
colonne, donc l'incrémenter invalide immédiatement toutes les sessions d'un
utilisateur (changement de mot de passe, désactivation par un admin).

Revision ID: 0007_token_columns
Revises: 0006_subscriptions_table
Create Date: 2026-08-25
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "0007_token_columns"
down_revision: Union[str, None] = "0006_subscriptions_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("verification_token_expires_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("reset_token_expires_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("token_version", sa.Integer(), nullable=False, server_default="0"),
    )

    # Backfill : recopier l'ancienne expiration dans la colonne correspondant au
    # token effectivement en attente, pour ne pas invalider les liens en cours.
    op.execute(
        """
        UPDATE users
           SET verification_token_expires_at = token_expires_at
         WHERE verification_token IS NOT NULL
        """
    )
    op.execute(
        """
        UPDATE users
           SET reset_token_expires_at = token_expires_at
         WHERE reset_password_token IS NOT NULL
        """
    )

    op.drop_column("users", "token_expires_at")


def downgrade() -> None:
    op.add_column(
        "users",
        sa.Column("token_expires_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.execute(
        """
        UPDATE users
           SET token_expires_at = COALESCE(verification_token_expires_at, reset_token_expires_at)
        """
    )
    op.drop_column("users", "token_version")
    op.drop_column("users", "reset_token_expires_at")
    op.drop_column("users", "verification_token_expires_at")
