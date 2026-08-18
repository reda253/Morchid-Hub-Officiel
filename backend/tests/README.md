# Tests backend — Morchid Hub (Plan 03)

Pyramide de tests alignée sur l'architecture en couches (Plan 01) :

```
tests/
  conftest.py          # fixtures : engine + session transactionnelle, TestClient, override get_db
  factories.py         # fabriques ORM (User / Guide / Route / Review / SupportMessage) + auth_headers
  unit/                # services testés avec repositories mockés — AUCUNE base requise
  integration/         # repositories (vraie BDD PostGIS) + API (TestClient)
```

## Lancer les tests

Depuis `backend/`, venv activé :

```bash
# Tout
pytest

# Uniquement la couche unitaire (rapide, portable, sans base)
pytest tests/unit           # ou : pytest -m unit

# Uniquement l'intégration (nécessite PostgreSQL/PostGIS)
pytest tests/integration    # ou : pytest -m integration

# Couverture
pytest --cov=app --cov-report=term-missing
pytest --cov=app.services --cov=app.repositories --cov-report=term   # cœur métier
```

## Base de données de test

Les tests d'intégration ont besoin d'une base **PostgreSQL + PostGIS**.

- Par défaut, l'URL est dérivée de `DATABASE_URL` (`.env`) en suffixant le nom de base
  par `_test` (ex. `MorchidHub` → `MorchidHub_test`).
- Surchargeable via la variable d'environnement `TEST_DATABASE_URL`.
- La base et l'extension PostGIS sont créées automatiquement au premier lancement.
- **Isolation** : chaque test s'exécute dans une transaction annulée en fin de test
  (savepoints) — aucune donnée ne persiste ni ne fuit entre tests.

Si aucun serveur PostgreSQL n'est joignable, la couche `integration/` est **ignorée
automatiquement** (skip) ; la couche `unit/` reste exécutable partout (dev, CI sans service DB).

## Couverture actuelle

`services/` + `repositories/` (cœur métier) : **~88 %** — au-dessus de la cible ≥ 70 %.
Chaque règle de gestion majeure (limite de trajets gratuits, anti-doublon d'avis,
transitions d'approbation, no-op Premium, unicité email/téléphone) a un test de non-régression.
