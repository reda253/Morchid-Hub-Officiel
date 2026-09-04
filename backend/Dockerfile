# syntax=docker/dockerfile:1

# ============================================================
# Stage 1 — construction des dépendances
# ============================================================
# Toutes les dépendances runtime sont pur-Python ou publient des wheels
# manylinux (pg8000, shapely, geoalchemy2, cryptography, bcrypt) : aucun
# compilateur, aucun libpq-dev. C'est la raison d'être du choix pg8000.
FROM python:3.11-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# ============================================================
# Stage 2 — image d'exécution
# ============================================================
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Utilisateur non-root : l'API n'a aucune raison de tourner en root.
RUN useradd --create-home --uid 1000 appuser

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

COPY app/ ./app/
COPY alembic/ ./alembic/
COPY alembic.ini ./
COPY docker-entrypoint.sh ./

# `sed` neutralise d'éventuelles fins de ligne CRLF (poste de développement
# Windows) : un shebang `/bin/sh\r` fait échouer le conteneur au démarrage.
# `.gitattributes` règle le problème à la source ; ceci est la ceinture.
RUN sed -i 's/\r$//' docker-entrypoint.sh \
    && chmod +x docker-entrypoint.sh \
    && mkdir -p uploads/profiles uploads/licenses uploads/cines \
    && chown -R appuser:appuser /app

# Les dossiers d'upload doivent appartenir à appuser AVANT le montage du
# volume : Docker initialise un volume nommé à partir du contenu et des
# permissions du répertoire de l'image. Sans ce chown, le premier upload
# échoue en écriture dans le conteneur et ressort en 500 côté client.
USER appuser

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
