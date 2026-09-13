"""Garde-fous de câblage : chaque création d'engine passe par build_engine_config.

Test statique volontaire : les trois sites (application, Alembic, entrypoint)
ne s'exécutent ensemble que dans le conteneur. Un site oublié ne casse rien en
local (base sans TLS) et n'échoue qu'en production, contre Neon.
"""

from pathlib import Path

import pytest

pytestmark = [pytest.mark.unit]

BACKEND_DIR = Path(__file__).resolve().parents[2]

ENGINE_SITES = (
    "app/database.py",
    "alembic/env.py",
    "docker-entrypoint.sh",
)


@pytest.mark.parametrize("relative_path", ENGINE_SITES)
def test_engine_site_uses_build_engine_config(relative_path):
    source = (BACKEND_DIR / relative_path).read_text(encoding="utf-8")

    assert "build_engine_config" in source, (
        f"{relative_path} crée un engine sans build_engine_config : "
        "la connexion échouera contre une base qui exige TLS."
    )


def test_entrypoint_listens_on_platform_port():
    source = (BACKEND_DIR / "docker-entrypoint.sh").read_text(encoding="utf-8")

    assert '--port "${PORT:-8000}"' in source
