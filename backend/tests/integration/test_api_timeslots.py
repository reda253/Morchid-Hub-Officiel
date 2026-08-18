"""Tests d'intégration API — créneaux (TimeSlot), RG21 non-chevauchement."""

import pytest

from tests.factories import auth_headers, make_guide, make_route, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def _slot_body(start_iso, end_iso):
    return {"scheduled_start": start_iso, "scheduled_end": end_iso}


def test_create_slot_returns_201(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)

    resp = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-01T09:00:00", "2026-09-01T11:00:00"),
        headers=auth_headers(guide_user),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["status"] == "upcoming"
    assert body["route_id"] == route.id


def test_create_overlapping_slot_returns_409(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)
    headers = auth_headers(guide_user)

    first = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-01T10:00:00", "2026-09-01T12:00:00"),
        headers=headers,
    )
    assert first.status_code == 201

    overlap = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-01T11:00:00", "2026-09-01T13:00:00"),
        headers=headers,
    )
    assert overlap.status_code == 409
    assert overlap.json()["error_code"] == "SLOT_CONFLICT"


def test_invalid_time_range_returns_422(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)

    resp = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-01T12:00:00", "2026-09-01T10:00:00"),  # fin < début
        headers=auth_headers(guide_user),
    )
    assert resp.status_code == 422


def test_list_and_cancel_slot(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)
    headers = auth_headers(guide_user)

    created = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-02T09:00:00", "2026-09-02T10:00:00"),
        headers=headers,
    ).json()

    listing = client.get(f"/api/v1/guides/routes/{route.id}/slots")
    assert listing.status_code == 200
    assert len(listing.json()) == 1

    cancel = client.delete(f"/api/v1/guides/slots/{created['id']}", headers=headers)
    assert cancel.status_code == 200
    assert cancel.json()["data"]["status"] == "cancelled"


def test_cancelled_slot_frees_the_window(client, db_session):
    """Après annulation, un nouveau créneau sur la même plage est accepté (RG21)."""
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)
    route = make_route(db_session, guide=guide)
    headers = auth_headers(guide_user)

    created = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-03T09:00:00", "2026-09-03T11:00:00"),
        headers=headers,
    ).json()
    client.delete(f"/api/v1/guides/slots/{created['id']}", headers=headers)

    again = client.post(
        f"/api/v1/guides/routes/{route.id}/slots",
        json=_slot_body("2026-09-03T09:00:00", "2026-09-03T11:00:00"),
        headers=headers,
    )
    assert again.status_code == 201
