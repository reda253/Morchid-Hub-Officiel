"""Fixtures partagées de la suite de tests Morchid Hub.

Deux niveaux :

* **unit** — n'utilisent aucune fixture BDD ; les services sont testés avec des
  repositories mockés. Portables partout.
* **integration** — utilisent `db_session` (vraie base PostGIS de test, isolée par
  transaction) et/ou `client` (FastAPI TestClient câblé sur cette session). Ces
  tests sont automatiquement *skippés* si aucune base de test n'est joignable.

Base de test :
    - URL prise dans la variable d'environnement ``TEST_DATABASE_URL`` si définie,
      sinon dérivée de ``settings.DATABASE_URL`` en suffixant le nom par ``_test``.
    - Créée automatiquement au besoin (+ extension PostGIS).
    - Isolation : chaque test s'exécute dans une transaction rollback (savepoints),
      aucune donnée ne fuit d'un test à l'autre.
"""

import os
import sys
from pathlib import Path

import pytest

# Rendre le package `app` importable quel que soit le répertoire d'invocation.
BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from sqlalchemy import create_engine, text  # noqa: E402
from sqlalchemy.engine import make_url  # noqa: E402
from sqlalchemy.orm import Session  # noqa: E402


# ──────────────────────────────────────────────────────────────────────────
# Résolution de l'URL de la base de test
# ──────────────────────────────────────────────────────────────────────────
def _resolve_test_db_url() -> str:
    override = os.getenv("TEST_DATABASE_URL")
    if override:
        return override
    from app.config import settings

    url = make_url(settings.DATABASE_URL)
    db_name = (url.database or "morchid") + "_test"
    return str(url.set(database=db_name))


def _ensure_database_exists(test_url: str) -> None:
    """Crée la base de test + l'extension PostGIS si nécessaire.

    Lève une exception si le serveur PostgreSQL est injoignable — la fixture
    `test_engine` la traduit alors en skip.
    """
    url = make_url(test_url)
    target_db = url.database

    # Connexion à la base de maintenance pour créer la base cible.
    admin_url = url.set(database="postgres")
    admin_engine = create_engine(admin_url, isolation_level="AUTOCOMMIT")
    with admin_engine.connect() as conn:
        exists = conn.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :name"),
            {"name": target_db},
        ).scalar()
        if not exists:
            # Nom de base injecté via identifiant — pas de bind possible sur DDL.
            conn.execute(text(f'CREATE DATABASE "{target_db}"'))
    admin_engine.dispose()

    # Activer PostGIS sur la base cible (géométries GuideRoute).
    target_engine = create_engine(test_url, isolation_level="AUTOCOMMIT")
    with target_engine.connect() as conn:
        conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
    target_engine.dispose()


@pytest.fixture(scope="session")
def test_engine():
    """Engine sur la base PostGIS de test. Skip si la BDD est injoignable."""
    test_url = _resolve_test_db_url()
    try:
        _ensure_database_exists(test_url)
        engine = create_engine(test_url, pool_pre_ping=True)
        # Sanity check + création du schéma.
        from app.database import Base
        import app.models  # noqa: F401  (enregistre les modèles sur Base)

        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        Base.metadata.create_all(bind=engine)
    except Exception as exc:  # pragma: no cover - dépend de l'environnement
        pytest.skip(f"Base PostGIS de test indisponible ({exc}); tests d'intégration ignorés.")
    yield engine
    engine.dispose()


@pytest.fixture
def db_session(test_engine):
    """Session transactionnelle : rollback complet en fin de test (isolation)."""
    connection = test_engine.connect()
    trans = connection.begin()
    # create_savepoint : les commit() des services deviennent des savepoints
    # relâchés/recréés, l'externe reste ouvert et est annulé au teardown.
    session = Session(bind=connection, join_transaction_mode="create_savepoint")
    try:
        yield session
    finally:
        session.close()
        if trans.is_active:
            trans.rollback()
        connection.close()


@pytest.fixture
def admin_user(db_session, monkeypatch):
    """Compte administrateur au sens de la nouvelle règle : seul son email,
    inscrit dans ADMIN_EMAILS, lui donne accès.

    `role` reste 'tourist' et `is_admin` reste False volontairement : si un jour
    quelqu'un remet la colonne ou le rôle dans `require_admin`, ces tests doivent
    échouer, pas continuer à passer pour la mauvaise raison.
    """
    from app.config import settings
    from tests.factories import make_user

    user = make_user(db_session, role="tourist", email="admin.test@morchid.local")
    monkeypatch.setattr(settings, "ADMIN_EMAILS", user.email)
    return user


@pytest.fixture
def client(db_session):
    """TestClient FastAPI dont `get_db` pointe sur la session de test.

    Volontairement instancié SANS `with` : le lifespan (et donc le
    `create_all` sur l'engine de production) n'est pas déclenché.
    """
    from fastapi.testclient import TestClient

    from app.database import get_db
    from app.main import app

    def _override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = _override_get_db
    test_client = TestClient(app)
    try:
        yield test_client
    finally:
        app.dependency_overrides.clear()
