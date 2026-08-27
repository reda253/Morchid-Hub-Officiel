"""Phase B #2 — rôle `administrator` (RG1/RG2)

Introduit le rôle `administrator` comme source de vérité, en rétro-remplissant
depuis l'ancien drapeau `is_admin`. La colonne `is_admin` est CONSERVÉE en
transition (droppée dans une révision ultérieure une fois le front migré).
UML étape 11.

Revision ID: 0003_role_administrator
Revises: 0002_status_rename
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op

revision: str = "0003_role_administrator"
down_revision: Union[str, None] = "0002_status_rename"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("UPDATE users SET role = 'administrator' WHERE is_admin = TRUE")


def downgrade() -> None:
    # `is_admin` reste la garde héritée : réversion sûre = rendre le rôle non-admin.
    op.execute("UPDATE users SET role = 'tourist' WHERE role = 'administrator'")
