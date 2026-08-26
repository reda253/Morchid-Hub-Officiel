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


def test_licence_and_cine_directories_are_not_served(client):
    """Les documents d'identité ne doivent pas être servis en statique.

    404 attendu — pas 403 : le montage ne doit pas exister du tout, pour ne pas
    confirmer qu'un fichier donné est présent.
    """
    for path in ("/uploads/licenses/whatever.jpg", "/uploads/cines/whatever.jpg"):
        resp = client.get(path)
        assert resp.status_code == 404, f"{path} est encore servi ({resp.status_code})"


def test_document_endpoint_requires_admin(client, db_session):
    guide = make_guide(db_session, approval_status="approved")
    resp = client.get(f"/api/v1/admin/guides/{guide.id}/documents/license")
    assert resp.status_code in (401, 403)


def test_document_endpoint_serves_admin(client, db_session, admin_user, tmp_path):
    from tests.factories import auth_headers
    from app.uploads import LICENSE_DIR, ensure_upload_dirs

    ensure_upload_dirs()
    doc = LICENSE_DIR / "plan-test-licence.jpg"
    doc.write_bytes(b"\xff\xd8\xff\xe0 fake jpeg")

    guide = make_guide(db_session, approval_status="approved")
    guide.license_card_url = f"uploads/licenses/{doc.name}"
    db_session.flush()

    try:
        resp = client.get(
            f"/api/v1/admin/guides/{guide.id}/documents/license",
            headers=auth_headers(admin_user),
        )
        assert resp.status_code == 200
        assert resp.content == b"\xff\xd8\xff\xe0 fake jpeg"
    finally:
        doc.unlink(missing_ok=True)


def test_document_endpoint_rejects_unknown_type(client, db_session, admin_user):
    from tests.factories import auth_headers

    guide = make_guide(db_session, approval_status="approved")
    resp = client.get(
        f"/api/v1/admin/guides/{guide.id}/documents/passport",
        headers=auth_headers(admin_user),
    )
    assert resp.status_code == 422, "doc_type est contraint par l'enum de la route"
