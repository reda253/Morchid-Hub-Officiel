"""Tests unitaires du RouteService — règle Premium / limite gratuite (RG20-bis)."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import ForbiddenError, NotFoundError
from app.schemas import GuideRouteCreate
from app.services.route_service import FREE_ROUTE_LIMIT, RouteService

pytestmark = pytest.mark.unit


def _service():
    svc = RouteService(db=MagicMock())
    svc.guides = MagicMock()
    svc.routes = MagicMock()
    return svc


def _payload():
    return GuideRouteCreate(
        coordinates=[{"lat": 31.62, "lng": -7.98}, {"lat": 31.63, "lng": -7.99}],
        start_point={"lat": 31.62, "lng": -7.98},
        end_point={"lat": 31.63, "lng": -7.99},
        distance=2.5,
        duration=30.0,
    )


def _guide(is_premium_active=False):
    g = SimpleNamespace(id="g1")
    g.is_premium_active = lambda: is_premium_active
    return g


def test_create_route_rejects_non_guide():
    svc = _service()
    user = SimpleNamespace(id="u1", role="tourist")
    with pytest.raises(ForbiddenError) as exc:
        svc.create_route(user, _payload())
    assert exc.value.error_code == "NOT_A_GUIDE"


def test_create_route_missing_guide_profile_raises():
    svc = _service()
    svc.guides.get_by_user_id.return_value = None
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(NotFoundError) as exc:
        svc.create_route(user, _payload())
    assert exc.value.error_code == "GUIDE_PROFILE_NOT_FOUND"


def test_create_route_free_limit_reached_blocks_third_route():
    svc = _service()
    svc.guides.get_by_user_id.return_value = _guide(is_premium_active=False)
    svc.routes.count_active_by_guide.return_value = FREE_ROUTE_LIMIT  # déjà 2
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(ForbiddenError) as exc:
        svc.create_route(user, _payload())
    assert exc.value.error_code == "FREE_LIMIT_REACHED"
    assert exc.value.details["max_routes"] == FREE_ROUTE_LIMIT
    assert exc.value.details["upgrade_required"] is True
    # Aucune route n'a été désactivée ni créée.
    svc.routes.deactivate_active_by_guide.assert_not_called()


def test_create_route_premium_bypasses_limit():
    svc = _service()
    svc.guides.get_by_user_id.return_value = _guide(is_premium_active=True)
    svc.routes.count_active_by_guide.return_value = 10  # au-dessus de la limite
    user = SimpleNamespace(id="u1", role="guide")

    route = svc.create_route(user, _payload())

    svc.routes.deactivate_active_by_guide.assert_called_once_with("g1")
    svc.routes.add.assert_called_once()
    assert route.guide_id == "g1"
    assert route.is_active is True


def test_create_route_free_under_limit_deactivates_previous():
    svc = _service()
    svc.guides.get_by_user_id.return_value = _guide(is_premium_active=False)
    svc.routes.count_active_by_guide.return_value = 1  # sous la limite
    user = SimpleNamespace(id="u1", role="guide")

    svc.create_route(user, _payload())

    svc.routes.deactivate_active_by_guide.assert_called_once_with("g1")
    svc.routes.add.assert_called_once()


def test_delete_route_not_owner_raises_unauthorized():
    svc = _service()
    svc.routes.get_by_id.return_value = SimpleNamespace(id="r1", guide_id="g1")
    svc.guides.get_owned.return_value = None  # pas propriétaire
    user = SimpleNamespace(id="u2", role="guide")
    with pytest.raises(ForbiddenError) as exc:
        svc.delete_route("r1", user)
    assert exc.value.error_code == "UNAUTHORIZED"


def test_delete_route_missing_raises_not_found():
    svc = _service()
    svc.routes.get_by_id.return_value = None
    user = SimpleNamespace(id="u1", role="guide")
    with pytest.raises(NotFoundError) as exc:
        svc.delete_route("rX", user)
    assert exc.value.error_code == "ROUTE_NOT_FOUND"
