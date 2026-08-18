"""baseline — schéma de fin de Phase A (avant alignement UML)

Crée toutes les tables antérieures à la Phase B (users, guides, guide_routes,
reviews, support_messages, …) à partir des modèles SQLAlchemy, en excluant les
tables nouvelles de la Phase B (`checkpoints`, `time_slots`) qui ont leurs
propres révisions.

Sur une base existante déjà peuplée, utiliser `alembic stamp 0001_baseline`
puis `alembic upgrade head` pour n'appliquer que les deltas Phase B.

Revision ID: 0001_baseline
Revises:
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op

from app.database import Base
import app.models  # noqa: F401  (enregistre les modèles sur Base)

revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Tables introduites en Phase B (créées par leurs propres révisions).
_PHASE_B_TABLES = {"checkpoints", "time_slots", "subscriptions"}


def _baseline_tables():
    return [t for t in Base.metadata.sorted_tables if t.name not in _PHASE_B_TABLES]


def upgrade() -> None:
    bind = op.get_bind()
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    for table in _baseline_tables():
        table.create(bind=bind, checkfirst=True)


def downgrade() -> None:
    bind = op.get_bind()
    for table in reversed(_baseline_tables()):
        table.drop(bind=bind, checkfirst=True)
