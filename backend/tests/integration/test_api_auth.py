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
        "password": "secret123",
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
        "/api/v1/login", json={"email": "ok@example.com", "password": "secret123"}
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
