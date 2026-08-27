"""Tests d'intégration API — trajets guides (création, actif, historique, suppression, public)."""

import pytest

from tests.factories import auth_headers, make_guide, make_route, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


_ROUTE_BODY = {
    "coordinates": [{"lat": 31.62, "lng": -7.98}, {"lat": 31.63, "lng": -7.99}],
    "start_point": {"lat": 31.62, "lng": -7.98},
    "end_point": {"lat": 31.63, "lng": -7.99},
    "distance": 2.5,
    "duration": 30.0,
    "start_address": "Place Jemaa el-Fna",
    "end_address": "Jardin Majorelle",
    "price": 200.0,
}


def test_create_route_returns_201(client, db_session):
    guide_user = make_user(db_session, role="guide")
    make_guide(db_session, user=guide_user)
    resp = client.post(
        "/api/v1/guides/routes", json=_ROUTE_BODY, headers=auth_headers(guide_user)
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["distance"] == 2.5
    assert body["price"] == 200.0
    assert body["is_active"] is True


def test_create_route_free_limit_returns_403(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user, is_premium=False)
    make_route(db_session, guide=guide, is_active=True)
    make_route(db_session, guide=guide, is_active=True)  # 2 actives -> limite

    resp = client.post(
        "/api/v1/guides/routes", json=_ROUTE_BODY, headers=auth_headers(guide_user)
    )
    assert resp.status_code == 403
    assert resp.json()["error_code"] == "FREE_LIMIT_REACHED"


def test_get_active_route_and_history(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    make_route(db_session, guide=guide, is_active=True)

    active = client.get(f"/api/v1/guides/{guide.id}/route")
    assert active.status_code == 200
    assert active.json()["is_active"] is True

    history = client.get(
        f"/api/v1/guides/{guide.id}/routes/history", headers=auth_headers(guide_user)
    )
    assert history.status_code == 200
    assert len(history.json()) >= 1


def test_get_active_route_none_returns_404(client, db_session):
    guide = make_guide(db_session)  # aucun trajet
    resp = client.get(f"/api/v1/guides/{guide.id}/route")
    assert resp.status_code == 404
    assert resp.json()["error_code"] == "NO_ACTIVE_ROUTE"


def test_delete_route_by_owner(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)

    resp = client.delete(
        f"/api/v1/guides/routes/{route.id}", headers=auth_headers(guide_user)
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "success"


def test_public_routes_all_lists_verified_guides(client, db_session):
    guide = make_guide(db_session, is_verified=True)
    make_route(db_session, guide=guide, is_active=True)

    resp = client.get("/api/v1/routes/all")
    assert resp.status_code == 200
    rows = resp.json()
    assert len(rows) >= 1
    assert "route" in rows[0] and "guide_name" in rows[0]
