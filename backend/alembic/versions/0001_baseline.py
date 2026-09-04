"""baseline — schéma de fin de Phase A (avant alignement UML)

Crée les cinq tables antérieures à la Phase B (users, guides, guide_routes,
reviews, support_messages) via du DDL littéral et figé. `checkpoints`,
`time_slots` et `subscriptions` restent hors baseline — elles ont leurs
propres révisions (`0004`, `0005`, `0006`).

Ce fichier contenait auparavant `_baseline_tables()`, qui construisait le
schéma à partir de `Base.metadata` (les modèles SQLAlchemy vivants) au moment
de l'exécution. Sur une base vide, cela créait `users` en incluant déjà les
trois colonnes que `0007_token_columns` tente ensuite d'ajouter
(`verification_token_expires_at`, `reset_token_expires_at`,
`token_version`), et la chaîne mourait avec `SQLSTATE 42701` (colonne déjà
existante) avant même d'écrire `alembic_version`. Une migration qui lit les
modèles vivants n'est pas une migration : le schéma qu'elle produit dépend de
la version du code au moment où elle tourne, pas de la révision déclarée.
Le schéma est donc désormais du DDL littéral, gelé à l'état de fin de
Phase A — colonnes transcrites depuis `app/models.py` tel qu'il existait
alors, sans aucun import de modèle.

`users.token_expires_at` est délibérément présente ici bien qu'absente des
modèles actuels : c'est l'ancienne colonne unique que `0007` scinde en
`verification_token_expires_at`/`reset_token_expires_at` avant de la
supprimer. Elle doit exister en sortie de baseline pour que le backfill et le
`DROP COLUMN` de `0007` aient quelque chose à faire.

Sur une base existante déjà peuplée avant l'introduction d'Alembic, utiliser
`alembic stamp 0001_baseline` puis `alembic upgrade head` pour n'appliquer
que les révisions suivantes.

Revision ID: 0001_baseline
Revises:
Create Date: 2026-08-16
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry

revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")

    op.create_table(
        "users",
        sa.Column("id", sa.String(), primary_key=True, index=True),
        sa.Column("full_name", sa.String(length=100), nullable=True),
        sa.Column("email", sa.String(length=255), nullable=True, unique=True, index=True),
        sa.Column("phone", sa.String(length=20), nullable=True),
        sa.Column("date_of_birth", sa.String(length=255), nullable=True),
        sa.Column("password_hash", sa.String(length=255), nullable=True),
        sa.Column("role", sa.String(length=20), nullable=True),
        sa.Column("is_admin", sa.Boolean(), nullable=False),
        sa.Column("is_email_verified", sa.Boolean(), nullable=False),
        sa.Column("verification_token", sa.String(length=255), nullable=True, index=True),
        sa.Column("reset_password_token", sa.String(length=255), nullable=True, index=True),
        # Ancienne colonne unique, scindée puis supprimée par 0007 — voir le
        # docstring du module.
        sa.Column("token_expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "guides",
        sa.Column("id", sa.String(), primary_key=True, index=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            unique=True,
        ),
        sa.Column("languages", sa.JSON(), nullable=False),
        sa.Column("specialties", sa.JSON(), nullable=False),
        sa.Column("cities_covered", sa.JSON(), nullable=False),
        sa.Column("years_of_experience", sa.Integer(), nullable=False),
        sa.Column("bio", sa.Text(), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=False),
        sa.Column("eco_score", sa.Integer(), nullable=False),
        sa.Column("average_rating", sa.Float(), nullable=False),
        sa.Column("total_reviews", sa.Integer(), nullable=False),
        sa.Column("has_official_license", sa.Boolean(), nullable=True),
        sa.Column("license_number", sa.String(length=50), nullable=True),
        sa.Column("cine_number", sa.String(length=20), nullable=True),
        sa.Column("profile_photo_url", sa.Text(), nullable=True),
        sa.Column("license_card_url", sa.Text(), nullable=True),
        sa.Column("cine_card_url", sa.Text(), nullable=True),
        sa.Column("is_premium", sa.Boolean(), nullable=False, index=True),
        sa.Column("premium_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column("approval_status", sa.String(length=20), nullable=True),
        sa.Column("rejection_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=True, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "guide_routes",
        sa.Column("id", sa.String(), primary_key=True, index=True),
        # app/models.py:218 déclare ForeignKey("guides.id", on_delete="CASCADE") —
        # `on_delete` (et non `ondelete`) n'est pas un argument SQLAlchemy valide ;
        # SQLAlchemy émet un SAWarning et l'ignore. Cette FK n'a donc AUCUN
        # comportement ON DELETE dans le schéma réel. Ne pas "corriger" ici :
        # ce serait créer un schéma que les modèles ne décrivent pas.
        sa.Column(
            "guide_id",
            sa.String(),
            sa.ForeignKey("guides.id"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "route_line",
            Geometry(geometry_type="LINESTRING", srid=4326),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "start_point",
            Geometry(geometry_type="POINT", srid=4326),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "end_point",
            Geometry(geometry_type="POINT", srid=4326),
            nullable=False,
            index=True,
        ),
        sa.Column("coordinates", sa.JSON(), nullable=False),
        sa.Column("distance", sa.Float(), nullable=False),
        sa.Column("duration", sa.Float(), nullable=False),
        sa.Column("start_address", sa.Text(), nullable=True),
        sa.Column("end_address", sa.Text(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("checkpoints", sa.JSON(), nullable=True),
        sa.Column("price", sa.Float(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
    )

    op.create_table(
        "reviews",
        sa.Column("id", sa.String(), primary_key=True, index=True),
        sa.Column(
            "guide_id",
            sa.String(),
            sa.ForeignKey("guides.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "tourist_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "route_id",
            sa.String(),
            sa.ForeignKey("guide_routes.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
        sa.Column("rating", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )

    op.create_table(
        "support_messages",
        sa.Column("id", sa.String(), primary_key=True, index=True),
        sa.Column(
            "user_id",
            sa.String(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("subject", sa.String(length=200), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("is_resolved", sa.Boolean(), nullable=False, index=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("support_messages")
    op.drop_table("reviews")
    op.drop_table("guide_routes")
    op.drop_table("guides")
    op.drop_table("users")
