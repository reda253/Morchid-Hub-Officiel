"""Tests unitaires de RouteRepository.build_route (construction géométrie PostGIS).

Méthode statique pure : ne touche pas la base, mais valide la traduction
payload -> entité GuideRoute (WKB PostGIS + JSON coordonnées).
"""

import pytest
from geoalchemy2.shape import to_shape

from app.repositories.route_repository import RouteRepository
from app.schemas import GuideRouteCreate

pytestmark = pytest.mark.unit


def _payload(**overrides):
    data = dict(
        coordinates=[
            {"lat": 31.62, "lng": -7.98},
            {"lat": 31.63, "lng": -7.99},
            {"lat": 31.64, "lng": -8.00},
        ],
        start_point={"lat": 31.62, "lng": -7.98},
        end_point={"lat": 31.64, "lng": -8.00},
        distance=3.2,
        duration=45.0,
        start_address="A",
        end_address="B",
        price=150.0,
    )
    data.update(overrides)
    return GuideRouteCreate(**data)


def test_build_route_sets_guide_and_flags():
    route = RouteRepository.build_route("g1", _payload())
    assert route.guide_id == "g1"
    assert route.is_active is True
    assert route.distance == 3.2
    assert route.price == 150.0


def test_build_route_coordinates_json_roundtrip():
    route = RouteRepository.build_route("g1", _payload())
    assert route.coordinates == [
        {"lat": 31.62, "lng": -7.98},
        {"lat": 31.63, "lng": -7.99},
        {"lat": 31.64, "lng": -8.00},
    ]


def test_build_route_geometry_lng_lat_order():
    """PostGIS attend (lng, lat) — vérifie l'ordre du start_point."""
    route = RouteRepository.build_route("g1", _payload())
    point = to_shape(route.start_point)
    assert point.x == pytest.approx(-7.98)  # x = longitude
    assert point.y == pytest.approx(31.62)  # y = latitude
    line = to_shape(route.route_line)
    assert len(line.coords) == 3


def test_build_route_empty_checkpoints_default():
    route = RouteRepository.build_route("g1", _payload())
    assert route.checkpoints == []
