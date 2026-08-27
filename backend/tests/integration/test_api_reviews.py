"""Tests d'intégration API — avis (création, listing, doublon, suppression)."""

import pytest

from tests.factories import auth_headers, make_guide, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_create_review_returns_201_and_updates_rating(client, db_session):
    guide = make_guide(db_session, is_verified=True, approval_status="approved")
    tourist = make_user(db_session, role="tourist", full_name="Karim")

    resp = client.post(
        "/api/v1/reviews",
        json={"guide_id": guide.id, "rating": 5, "comment": "Superbe visite"},
        headers=auth_headers(tourist),
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["rating"] == 5
    assert body["tourist_name"] == "Karim"

    # Le listing reflète la nouvelle moyenne.
    listing = client.get(f"/api/v1/guides/{guide.id}/reviews")
    assert listing.status_code == 200
    lb = listing.json()
    assert lb["total_reviews"] == 1
    assert lb["average_rating"] == 5.0


def test_create_review_duplicate_returns_409(client, db_session):
    guide = make_guide(db_session, is_verified=True)
    tourist = make_user(db_session, role="tourist")
    headers = auth_headers(tourist)
    payload = {"guide_id": guide.id, "rating": 4}

    first = client.post("/api/v1/reviews", json=payload, headers=headers)
    assert first.status_code == 201
    second = client.post("/api/v1/reviews", json=payload, headers=headers)
    assert second.status_code == 409
    assert second.json()["error_code"] == "REVIEW_ALREADY_EXISTS"


def test_create_review_as_guide_forbidden(client, db_session):
    guide = make_guide(db_session, is_verified=True)
    other_guide_user = make_user(db_session, role="guide")

    resp = client.post(
        "/api/v1/reviews",
        json={"guide_id": guide.id, "rating": 3},
        headers=auth_headers(other_guide_user),
    )
    assert resp.status_code == 403
    assert resp.json()["error_code"] == "FORBIDDEN_ROLE"


def test_delete_own_review_returns_200(client, db_session):
    guide = make_guide(db_session, is_verified=True)
    tourist = make_user(db_session, role="tourist")
    headers = auth_headers(tourist)

    created = client.post(
        "/api/v1/reviews", json={"guide_id": guide.id, "rating": 5}, headers=headers
    ).json()

    resp = client.delete(f"/api/v1/reviews/{created['id']}", headers=headers)
    assert resp.status_code == 200
    assert resp.json()["status"] == "success"
