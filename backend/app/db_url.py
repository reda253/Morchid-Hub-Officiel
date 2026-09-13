"""
Préparation de DATABASE_URL pour le pilote pg8000.

Les hébergeurs Postgres managés (Neon, Render, Supabase) fournissent des URL au
format libpq : `?sslmode=require&channel_binding=require`. pg8000 n'est pas
libpq : le dialecte SQLAlchemy transmet chaque paramètre de requête à
`pg8000.connect()`, qui lève TypeError sur `sslmode`. Ce module traduit ces
paramètres en `connect_args` compris par pg8000 (un `ssl.SSLContext`).

Trois points créent un engine et doivent tous passer par ici :
`app/database.py`, `alembic/env.py` et `docker-entrypoint.sh`. Un seul oubli
et ce point-là échoue contre une base qui exige TLS.

Ce module n'importe volontairement pas `app.config` : l'entrypoint l'utilise
avant que les settings de l'application ne soient chargés.
"""

import ssl
from typing import Any

from sqlalchemy.engine import URL, make_url

# Paramètres propres à libpq : pg8000 ne les connaît pas.
_LIBPQ_ONLY_PARAMS = ("sslmode", "channel_binding")

# Modes qui exigent TLS. Le certificat et le nom d'hôte sont vérifiés même pour
# `require` (libpq ne le fait pas) : les hébergeurs managés présentent un
# certificat public valide, et un TLS non vérifié n'arrête pas un intermédiaire.
_TLS_MODES = {"require", "verify-ca", "verify-full"}


def build_engine_config(raw_url: str) -> tuple[URL, dict[str, Any]]:
    """Retourne l'URL nettoyée et les `connect_args` à passer à `create_engine`.

    L'URL est retournée sous forme d'objet `URL`, jamais de chaîne : `str(URL)`
    masque le mot de passe.

    Raises:
        ValueError: `sslmode` non pris en charge. Le message ne contient jamais
        l'URL, qui porte le mot de passe.
    """
    url = make_url(raw_url)
    query = dict(url.query)
    sslmode = query.get("sslmode")
    for param in _LIBPQ_ONLY_PARAMS:
        query.pop(param, None)

    connect_args: dict[str, Any] = {}
    if sslmode in _TLS_MODES:
        connect_args["ssl_context"] = ssl.create_default_context()
    elif sslmode not in (None, "disable"):
        raise ValueError(
            f"sslmode non pris en charge : {sslmode!r} "
            "(valeurs acceptées : disable, require, verify-ca, verify-full)"
        )

    return url.set(query=query), connect_args
