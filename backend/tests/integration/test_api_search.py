"""Tests d'intégration API — recherche & filtres (endpoints publics)."""

import pytest

from tests.factories import make_guide

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_search_guides_city_filter(client, db_session):
    make_guide(db_session, cities_covered=["Fès"], approval_status="approved")
    make_guide(db_session, cities_covered=["Marrakech"], approval_status="approved")

    resp = client.get("/api/v1/search/guides", params={"city": "Fès"})
    assert resp.status_code == 200
    results = resp.json()
    assert len(results) == 1
    assert "Fès" in results[0]["cities_covered"]


def test_search_excludes_pending_guides(client, db_session):
    make_guide(db_session, approval_status="pending")
    resp = client.get("/api/v1/search/guides")
    assert resp.status_code == 200
    assert resp.json() == []


def test_available_filters_reports_values(client, db_session):
    make_guide(
        db_session,
        approval_status="approved",
        cities_covered=["Fès"],
        specialties=["culture"],
        languages=["Arabe"],
    )
    resp = client.get("/api/v1/search/filters")
    assert resp.status_code == 200
    body = resp.json()
    assert "Fès" in body["cities"]
    assert "culture" in body["specialties"]
    assert body["total_guides"] >= 1
