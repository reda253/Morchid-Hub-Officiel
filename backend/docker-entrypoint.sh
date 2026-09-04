#!/bin/sh
# Séquence de démarrage du conteneur API.
#
#   1. attendre que la base réponde
#   2. appliquer les migrations (autorité unique du schéma)
#   3. remplacer le shell par uvicorn
#
# L'ordre n'est pas négociable : un conteneur qui sert des requêtes contre un
# schéma non migré est pire qu'un conteneur qui refuse de démarrer.
set -e

echo "[entrypoint] attente de la base de données..."
python <<'PY'
import os
import sys
import time

from sqlalchemy import create_engine, text

url = os.environ["DATABASE_URL"]
attempts = int(os.environ.get("DB_WAIT_ATTEMPTS", "30"))
delay = float(os.environ.get("DB_WAIT_DELAY", "2"))

for attempt in range(1, attempts + 1):
    engine = create_engine(url)
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        print(f"[entrypoint] base joignable (tentative {attempt})")
        sys.exit(0)
    except Exception as exc:
        # Ne jamais logger le texte de l'exception : les erreurs SQLAlchemy/pg8000
        # embarquent l'hôte, le port, la base et l'utilisateur, et une ArgumentError
        # sur une URL malformée peut inclure DATABASE_URL avec le mot de passe en
        # clair. La sortie standard du conteneur atteint `docker logs`, les logs
        # GitHub Actions et tout agrégateur — plus exposée que le logger applicatif.
        # Seul le type de l'exception est loggé ; le détail n'a sa place nulle part ici.
        print(f"[entrypoint] tentative {attempt}/{attempts} échouée : {type(exc).__name__}")
        time.sleep(delay)
    finally:
        # Dispose sur les deux chemins : une connexion échouée ne doit pas laisser
        # un engine ouvert pour le reste de la fenêtre de tentatives.
        engine.dispose()

print("[entrypoint] base injoignable, abandon", file=sys.stderr)
sys.exit(1)
PY

echo "[entrypoint] application des migrations Alembic..."
alembic upgrade head

echo "[entrypoint] démarrage d'uvicorn..."
# `exec` est porteur de sens : il remplace le shell, donc uvicorn devient PID 1
# et reçoit directement le SIGTERM de `docker stop`. Sans lui, le shell garde
# PID 1, ignore le signal, et chaque arrêt attend le timeout de 10 s avant un
# SIGKILL qui coupe les requêtes en cours.
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
