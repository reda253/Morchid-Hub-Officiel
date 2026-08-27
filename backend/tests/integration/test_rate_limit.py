"""Limitation de débit sur les routes d'authentification."""

import pytest

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_login_is_rate_limited(client, db_session):
    """Au-delà du seuil, la route répond 429 dans le format d'erreur du projet."""
    payload = {"email": "brute.plan.test@example.com", "password": "mauvais"}

    statuses = [client.post("/api/v1/login", json=payload).status_code for _ in range(12)]

    assert 429 in statuses, f"aucune limite déclenchée : {statuses}"

    limited = client.post("/api/v1/login", json=payload)
    assert limited.status_code == 429
    body = limited.json()
    assert body["error_code"] == "RATE_LIMITED"
    assert body["status"] == "error"


def test_forgot_password_is_rate_limited(client, db_session):
    payload = {"email": "spam.plan.test@example.com"}
    statuses = [
        client.post("/api/v1/auth/forgot-password", json=payload).status_code
        for _ in range(8)
    ]
    assert 429 in statuses, f"aucune limite déclenchée : {statuses}"
