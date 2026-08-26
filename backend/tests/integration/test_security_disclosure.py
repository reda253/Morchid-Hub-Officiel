"""Filet de régression — aucune donnée personnelle ni document d'identité ne doit
sortir par un endpoint anonyme. Voir le spec 2026-08-25-backend-security-hardening."""

import pytest

from tests.factories import make_guide

pytestmark = [pytest.mark.integration, pytest.mark.db]

# Champs qui ne doivent JAMAIS apparaître dans une réponse anonyme.
FORBIDDEN_KEYS = {
    "email",
    "phone",
    "is_admin",
    "is_active",
    "is_email_verified",
    "license_card_url",
    "cine_card_url",
}


def _assert_no_forbidden_keys(payload) -> None:
    """Parcourt récursivement la réponse et échoue sur le premier champ interdit."""
    if isinstance(payload, dict):
        leaked = FORBIDDEN_KEYS & payload.keys()
        assert not leaked, f"Champs interdits exposés anonymement : {sorted(leaked)}"
        for value in payload.values():
            _assert_no_forbidden_keys(value)
    elif isinstance(payload, list):
        for item in payload:
            _assert_no_forbidden_keys(item)


def test_search_guides_exposes_no_personal_data(client, db_session):
    guide = make_guide(db_session, approval_status="approved")
    guide.license_card_url = "uploads/licenses/secret.jpg"
    guide.cine_card_url = "uploads/cines/secret.jpg"
    db_session.flush()

    resp = client.get("/api/v1/search/guides")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) == 1
    _assert_no_forbidden_keys(body)


def test_search_guides_still_returns_useful_fields(client, db_session):
    make_guide(db_session, approval_status="approved", cities_covered=["Fès"])

    resp = client.get("/api/v1/search/guides")
    card = resp.json()[0]
    assert card["full_name"]
    assert card["guide_id"]
    assert card["cities_covered"] == ["Fès"]


def test_public_guide_list_exposes_no_personal_data(client, db_session):
    guide = make_guide(db_session, approval_status="approved")
    guide.license_card_url = "uploads/licenses/secret.jpg"
    guide.cine_card_url = "uploads/cines/secret.jpg"
    db_session.flush()

    resp = client.get("/api/v1/guides")
    assert resp.status_code == 200
    _assert_no_forbidden_keys(resp.json())


def test_public_guide_list_hides_unapproved_guides(client, db_session):
    make_guide(db_session, approval_status="pending")
    make_guide(db_session, approval_status="rejected")
    make_guide(db_session, approval_status="approved")

    resp = client.get("/api/v1/guides")
    assert resp.status_code == 200
    assert len(resp.json()) == 1, "seuls les guides approuvés sont publics"
