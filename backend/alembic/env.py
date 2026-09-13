"""Environnement Alembic pour Morchid Hub.

- Résout l'URL depuis `settings.DATABASE_URL` (ou `ALEMBIC_DATABASE_URL`).
- Charge `app.models` pour peupler `Base.metadata` (cible de l'autogenerate).
"""

import os
import sys
from logging.config import fileConfig
from pathlib import Path

from alembic import context
from sqlalchemy import create_engine, pool

# Rendre le package `app` importable (backend/ sur le path).
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app.config import settings  # noqa: E402
from app.database import Base  # noqa: E402
from app.db_url import build_engine_config  # noqa: E402
import app.models  # noqa: E402,F401  (enregistre tous les modèles sur Base)

config = context.config

# URL : priorité à la surcharge d'environnement (base de test), sinon .env.
_db_url = os.getenv("ALEMBIC_DATABASE_URL") or settings.DATABASE_URL
config.set_main_option("sqlalchemy.url", _db_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    context.configure(
        url=_db_url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    # create_engine direct plutôt qu'engine_from_config : les connect_args
    # (contexte TLS) ne peuvent pas transiter par la section .ini d'Alembic.
    engine_url, connect_args = build_engine_config(_db_url)
    connectable = create_engine(
        engine_url,
        poolclass=pool.NullPool,
        connect_args=connect_args,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
            compare_type=True,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
