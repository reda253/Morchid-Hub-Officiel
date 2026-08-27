"""Tests d'intégration GuideRepository — recherche filtrée (JSONB), listes, stats."""

import pytest

from app.repositories.guide_repository import GuideRepository
from tests.factories import make_guide, make_route, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_search_guides_only_returns_approved_active(db_session):
    repo = GuideRepository(db_session)
    approved = make_guide(db_session, approval_status="approved")
    make_guide(db_session, approval_status="pending")  # exclu
    inactive_user = make_user(db_session, role="guide", is_active=False)
    make_guide(db_session, user=inactive_user, approval_status="approved")  # exclu

    rows = repo.search_guides()
    guide_ids = {g.id for _u, g in rows}
    assert approved.id in guide_ids
    assert len(rows) == 1


def test_search_guides_city_jsonb_filter(db_session):
    repo = GuideRepository(db_session)
    fes = make_guide(db_session, cities_covered=["Fès"])
    make_guide(db_session, cities_covered=["Marrakech"])

    rows = repo.search_guides(city="Fès")
    assert [g.id for _u, g in rows] == [fes.id]


def test_search_guides_specialty_and_min_experience(db_session):
    repo = GuideRepository(db_session)
    make_guide(db_session, specialties=["nature"], years_of_experience=2)
    match = make_guide(db_session, specialties=["culture"], years_of_experience=10)

    rows = repo.search_guides(specialty="culture", min_experience=5)
    assert [g.id for _u, g in rows] == [match.id]


def test_search_guides_with_routes_outerjoin(db_session):
    repo = GuideRepository(db_session)
    with_route = make_guide(db_session)
    make_route(db_session, guide=with_route)
    make_guide(db_session)  # sans trajet

    # Par défaut include_without_route=False -> seuls les guides avec trajet actif.
    rows = repo.search_guides_with_routes()
    assert len(rows) == 1
    _u, guide, route = rows[0]
    assert guide.id == with_route.id
    assert route is not None

    # include_without_route=True -> les deux.
    rows_all = repo.search_guides_with_routes(include_without_route=True)
    assert len(rows_all) == 2


def test_count_by_status(db_session):
    repo = GuideRepository(db_session)
    make_guide(db_session, approval_status="approved")
    make_guide(db_session, approval_status="approved")
    make_guide(db_session, approval_status="rejected")
    assert repo.count_by_status("approved") == 2
    assert repo.count_by_status("rejected") == 1
