"""Tests d'intégration API — flux d'authentification (TestClient + BDD de test)."""

import pytest

from tests.factories import auth_headers, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def _registration_body(email="newuser@example.com", phone="0612345678"):
    return {
        "personal_info": {
            "full_name": "Nouveau Utilisateur",
            "email": email,
            "phone": phone,
            "date_of_birth": "1990-01-01",
        },
        "role": "tourist",
        "password": "Marrakech2026",
    }


def test_register_returns_201_and_user(client):
    resp = client.post("/api/v1/register", json=_registration_body())
    assert resp.status_code == 201
    body = resp.json()
    assert body["status"] == "success"
    assert body["user"]["email"] == "newuser@example.com"
    assert body["user"]["is_email_verified"] is False


def test_register_duplicate_email_returns_400_standard_error(client):
    client.post("/api/v1/register", json=_registration_body(email="dup@example.com", phone="0612345601"))
    resp = client.post(
        "/api/v1/register",
        json=_registration_body(email="dup@example.com", phone="0612345602"),
    )
    assert resp.status_code == 400
    body = resp.json()
    assert body["status"] == "error"
    assert body["error_code"] == "EMAIL_EXISTS"


def test_login_wrong_password_returns_401(client):
    client.post("/api/v1/register", json=_registration_body(email="log@example.com", phone="0612345603"))
    resp = client.post(
        "/api/v1/login", json={"email": "log@example.com", "password": "wrongpass"}
    )
    assert resp.status_code == 401
    assert resp.json()["error_code"] == "INVALID_CREDENTIALS"


def test_login_success_returns_token(client):
    client.post("/api/v1/register", json=_registration_body(email="ok@example.com", phone="0612345604"))
    resp = client.post(
        "/api/v1/login", json={"email": "ok@example.com", "password": "Marrakech2026"}
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["access_token"]
    assert body["token_type"] == "bearer"
    assert body["user"]["email"] == "ok@example.com"


def test_me_without_token_is_rejected(client):
    resp = client.get("/api/v1/auth/me")
    assert resp.status_code in (401, 403)


def test_me_with_token_returns_profile(client, db_session):
    user = make_user(db_session, role="tourist", email="me@example.com")
    resp = client.get("/api/v1/auth/me", headers=auth_headers(user))
    assert resp.status_code == 200
    body = resp.json()
    assert body["user"]["email"] == "me@example.com"
    assert body["stats"] is not None


def test_verification_link_rejects_expired_token(client, db_session):
    """Le lien navigateur doit expirer comme l'endpoint POST."""
    from datetime import datetime, timedelta, timezone

    user = make_user(db_session, is_email_verified=False)
    user.verification_token = "token-expire-plan-test"
    user.verification_token_expires_at = datetime.now(timezone.utc) - timedelta(hours=1)
    db_session.flush()

    resp = client.get("/api/v1/verify-email", params={"token": "token-expire-plan-test"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "error"

    db_session.refresh(user)
    assert user.is_email_verified is False, "un token expiré ne doit pas vérifier le compte"


def test_bumping_token_version_revokes_existing_token(client, db_session):
    """Un token émis avant l'incrément doit être refusé après."""
    user = make_user(db_session, role="tourist")
    headers = auth_headers(user)

    assert client.get("/api/v1/auth/me", headers=headers).status_code == 200

    user.token_version += 1
    db_session.flush()

    resp = client.get("/api/v1/auth/me", headers=headers)
    assert resp.status_code == 401, "le token d'avant l'incrément doit être révoqué"


def test_validation_errors_use_the_project_envelope(client):
    """Une erreur 422 doit être lisible par le client, pas brute de FastAPI.

    FastAPI répond nativement {"detail": [...]} en anglais : le client Flutter
    ne sait pas lire cette forme et affichait « une erreur inattendue (422) »
    au lieu de la règle non respectée.
    """
    body = _registration_body(email="v422@example.com", phone="0612345699")
    body["password"] = "secret123"  # 9 caractères

    resp = client.post("/api/v1/register", json=body)

    assert resp.status_code == 422
    payload = resp.json()
    assert payload["status"] == "error"
    assert payload["error_code"] == "VALIDATION_ERROR"
    assert "10" in payload["message"], "le message doit nommer la règle"
    assert "detail" not in payload, "la forme brute de FastAPI ne doit pas fuir"


def test_validation_reports_every_invalid_field(client):
    """Ne montrer que la première erreur désignerait un champ arbitraire."""
    body = _registration_body(email="v422b@example.com", phone="12345")
    body["password"] = "abc"
    body["personal_info"]["full_name"] = "T"

    payload = client.post("/api/v1/register", json=body).json()

    assert len(payload["details"]) >= 3
    joined = payload["message"]
    assert "téléphone" in joined and "mot de passe" in joined
