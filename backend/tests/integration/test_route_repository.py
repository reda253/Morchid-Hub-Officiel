"""Tests d'intégration RouteRepository — round-trip PostGIS, triple JOIN, activité."""

import pytest
from geoalchemy2.shape import to_shape

from app.repositories.route_repository import RouteRepository
from tests.factories import make_guide, make_route

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_postgis_geometry_roundtrip(db_session):
    repo = RouteRepository(db_session)
    guide = make_guide(db_session)
    route = make_route(
        db_session,
        guide=guide,
        start_point={"lat": 31.62, "lng": -7.98},
        end_point={"lat": 31.64, "lng": -8.00},
        coordinates=[{"lat": 31.62, "lng": -7.98}, {"lat": 31.64, "lng": -8.00}],
    )
    db_session.expire(route)  # forcer une relecture depuis la BDD

    reloaded = repo.get_by_id(route.id)
    start = to_shape(reloaded.start_point)
    assert start.x == pytest.approx(-7.98)
    assert start.y == pytest.approx(31.62)
    assert len(to_shape(reloaded.route_line).coords) == 2


def test_count_and_deactivate_active(db_session):
    repo = RouteRepository(db_session)
    guide = make_guide(db_session)
    make_route(db_session, guide=guide, is_active=True)
    make_route(db_session, guide=guide, is_active=True)
    assert repo.count_active_by_guide(guide.id) == 2

    repo.deactivate_active_by_guide(guide.id)
    db_session.flush()
    assert repo.count_active_by_guide(guide.id) == 0


def test_get_active_by_guide(db_session):
    repo = RouteRepository(db_session)
    guide = make_guide(db_session)
    make_route(db_session, guide=guide, is_active=False)
    active = make_route(db_session, guide=guide, is_active=True)
    assert repo.get_active_by_guide(guide.id).id == active.id


def test_list_active_with_guide_and_user_triple_join(db_session):
    repo = RouteRepository(db_session)
    guide = make_guide(db_session, is_verified=True)
    route = make_route(db_session, guide=guide, is_active=True)
    # Guide non vérifié -> exclu du listing public.
    unverified = make_guide(db_session, is_verified=False)
    make_route(db_session, guide=unverified, is_active=True)

    rows = repo.list_active_with_guide_and_user(city=None, limit=20, offset=0)
    assert len(rows) == 1
    r, g, u = rows[0]
    assert r.id == route.id
    assert g.id == guide.id
    assert u.id == guide.user_id


def test_get_by_id_and_guide_scopes_to_owner(db_session):
    repo = RouteRepository(db_session)
    guide_a = make_guide(db_session)
    guide_b = make_guide(db_session)
    route = make_route(db_session, guide=guide_a)
    assert repo.get_by_id_and_guide(route.id, guide_a.id) is not None
    assert repo.get_by_id_and_guide(route.id, guide_b.id) is None
