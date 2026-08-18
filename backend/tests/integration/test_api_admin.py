"""Tests d'intégration API — administration (approbation guide, stats, garde rôle)."""

import pytest

from tests.factories import auth_headers, make_guide, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_approve_guide_returns_200_and_verifies(client, db_session, admin_user):
    guide = make_guide(
        db_session, approval_status="pending", is_verified=False,
        has_official_license=True,  # RG15 : documents soumis
    )

    resp = client.put(
        f"/api/v1/admin/guides/{guide.id}/approve", headers=auth_headers(admin_user)
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "success"
    assert body["data"]["approval_status"] == "approved"


def test_reject_guide_records_reason(client, db_session, admin_user):
    guide = make_guide(db_session, approval_status="pending")

    resp = client.put(
        f"/api/v1/admin/guides/{guide.id}/reject",
        json={"reason": "Documents non conformes, merci de recommencer."},
        headers=auth_headers(admin_user),
    )
    assert resp.status_code == 200
    assert resp.json()["data"]["approval_status"] == "rejected"


def test_admin_stats_structure(client, db_session, admin_user):
    make_guide(db_session, approval_status="approved")

    resp = client.get("/api/v1/admin/stats", headers=auth_headers(admin_user))
    assert resp.status_code == 200
    body = resp.json()
    assert set(body.keys()) == {"users", "guides", "support"}
    assert body["guides"]["approved"] >= 1


def test_non_admin_forbidden(client, db_session):
    tourist = make_user(db_session, role="tourist", is_admin=False)
    resp = client.get("/api/v1/admin/stats", headers=auth_headers(tourist))
    assert resp.status_code == 403
    assert resp.json()["error_code"] == "FORBIDDEN"


def test_list_guides_by_status(client, db_session, admin_user):
    make_guide(db_session, approval_status="pending", has_official_license=True)
    make_guide(db_session, approval_status="approved")
    make_guide(db_session, approval_status="approved")
    make_guide(db_session, approval_status="rejected")

    headers = auth_headers(admin_user)
    approved = client.get("/api/v1/admin/guides", params={"status": "approved"}, headers=headers)
    assert approved.status_code == 200
    assert len(approved.json()) == 2
    assert all(g["approval_status"] == "approved" for g in approved.json())

    rejected = client.get("/api/v1/admin/guides", params={"status": "rejected"}, headers=headers)
    assert len(rejected.json()) == 1

    # défaut = pending
    default = client.get("/api/v1/admin/guides", headers=headers)
    assert all(g["approval_status"] == "pending" for g in default.json())


def test_list_guides_invalid_status_422(client, db_session, admin_user):
    resp = client.get("/api/v1/admin/guides", params={"status": "bogus"}, headers=auth_headers(admin_user))
    assert resp.status_code == 422


def test_administrator_role_alone_no_longer_grants_access(client, db_session):
    """Le rôle `administrator` (même avec `is_admin=True`) ne donne plus accès.

    La liste blanche d'emails `ADMIN_EMAILS` est désormais l'unique source de
    vérité de `require_admin` : ni le rôle ni la colonne `is_admin` ne sont
    consultés, afin que personne ne devienne admin en écrivant en base.
    """
    admin = make_user(db_session, role="administrator", is_admin=True)
    resp = client.get("/api/v1/admin/stats", headers=auth_headers(admin))
    assert resp.status_code == 403
