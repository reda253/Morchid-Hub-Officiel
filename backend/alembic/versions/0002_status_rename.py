"""Phase B #1 — renommage du statut d'approbation (RG14)

`pending_approval` et `pending_review` fusionnent en `pending` (le sous-état
"documents soumis" devient dérivé de `has_official_license`). UML étape 12.

Revision ID: 0002_status_rename
Revises: 0001_baseline
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0002_status_rename"
down_revision: Union[str, None] = "0001_baseline"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "UPDATE guides SET approval_status = 'pending' "
        "WHERE approval_status IN ('pending_approval', 'pending_review')"
    )
    op.alter_column("guides", "approval_status", server_default="pending")


def downgrade() -> None:
    # Réversion (lossy) : on ne distingue plus documents soumis ou non.
    op.execute(
        "UPDATE guides SET approval_status = 'pending_approval' "
        "WHERE approval_status = 'pending'"
    )
    op.alter_column("guides", "approval_status", server_default="pending_approval")
