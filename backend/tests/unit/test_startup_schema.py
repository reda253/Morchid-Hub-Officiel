"""Le bootstrap de schéma au démarrage ne doit exister qu'en développement.

En conteneur, `alembic upgrade head` tourne avant uvicorn (voir
backend/docker-entrypoint.sh). Si `create_all` reste actif, deux autorités de
schéma coexistent : un modèle qui a dérivé des migrations voit sa table créée
quand même, sans trace dans `alembic_version`, et la dérive reste invisible
jusqu'à la collision.
"""

import asyncio

import pytest

from app.config import settings
from app.database import Base
from app.main import create_app


def _run_startup_handlers(app) -> None:
    """Exécute les handlers `on_startup` enregistrés par create_app()."""
    for handler in app.router.on_startup:
        asyncio.run(handler())


@pytest.mark.unit
def test_startup_skips_create_all_when_debug_disabled(monkeypatch):
    calls = []
    monkeypatch.setattr(settings, "DEBUG", False)
    monkeypatch.setattr(Base.metadata, "create_all", lambda **kw: calls.append(kw))

    _run_startup_handlers(create_app())

    assert calls == [], "create_all ne doit pas s'exécuter hors DEBUG : Alembic est la seule autorité"


@pytest.mark.unit
def test_startup_creates_tables_when_debug_enabled(monkeypatch):
    calls = []
    monkeypatch.setattr(settings, "DEBUG", True)
    monkeypatch.setattr(Base.metadata, "create_all", lambda **kw: calls.append(kw))

    _run_startup_handlers(create_app())

    assert len(calls) == 1, "en développement, le filet create_all reste en place"
