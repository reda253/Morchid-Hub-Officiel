"""Tests unitaires du ReviewService — règles métier des avis."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import pytest

from app.exceptions import BadRequestError, ConflictError, ForbiddenError, NotFoundError
from app.schemas import ReviewCreate
from app.services.review_service import ReviewService

pytestmark = pytest.mark.unit


def _service():
    svc = ReviewService(db=MagicMock())
    svc.guides = MagicMock()
    svc.routes = MagicMock()
    svc.reviews = MagicMock()
    return svc


def _tourist(uid="t1"):
    return SimpleNamespace(id=uid, role="tourist", full_name="Touriste", is_admin=False)


def _data(guide_id="g1", route_id=None, rating=5):
    return ReviewCreate(guide_id=guide_id, route_id=route_id, rating=rating, comment="Top")


def test_create_review_rejects_non_tourist():
    svc = _service()
    user = SimpleNamespace(id="u1", role="guide", is_admin=False)
    with pytest.raises(ForbiddenError) as exc:
        svc.create_review(user, _data())
    assert exc.value.error_code == "FORBIDDEN_ROLE"


def test_create_review_unverified_guide_raises_not_found():
    svc = _service()
    svc.guides.get_verified.return_value = None
    with pytest.raises(NotFoundError) as exc:
        svc.create_review(_tourist(), _data())
    assert exc.value.error_code == "GUIDE_NOT_FOUND"


def test_create_review_self_review_blocked():
    svc = _service()
    svc.guides.get_verified.return_value = SimpleNamespace(id="g1", user_id="t1")
    with pytest.raises(BadRequestError) as exc:
        svc.create_review(_tourist("t1"), _data())
    assert exc.value.error_code == "SELF_REVIEW"


def test_create_review_duplicate_blocked():
    svc = _service()
    svc.guides.get_verified.return_value = SimpleNamespace(id="g1", user_id="owner")
    svc.reviews.get_by_guide_and_tourist.return_value = object()  # déjà noté
    with pytest.raises(ConflictError) as exc:
        svc.create_review(_tourist("t1"), _data())
    assert exc.value.error_code == "REVIEW_ALREADY_EXISTS"


def test_create_review_route_not_belonging_to_guide_raises():
    svc = _service()
    svc.guides.get_verified.return_value = SimpleNamespace(id="g1", user_id="owner")
    svc.reviews.get_by_guide_and_tourist.return_value = None
    svc.routes.get_by_id_and_guide.return_value = None  # trajet ≠ guide
    with pytest.raises(NotFoundError) as exc:
        svc.create_review(_tourist("t1"), _data(route_id="r1"))
    assert exc.value.error_code == "ROUTE_NOT_FOUND"


def test_create_review_success_refreshes_rating():
    svc = _service()
    guide = SimpleNamespace(id="g1", user_id="owner", total_reviews=0, average_rating=0.0)
    svc.guides.get_verified.return_value = guide
    svc.reviews.get_by_guide_and_tourist.return_value = None
    svc.reviews.rating_aggregates.return_value = (2, 4.5)

    review, name = svc.create_review(_tourist("t1"), _data(rating=4))

    assert review.rating == 4
    assert name == "Touriste"
    # _refresh_rating applique les agrégats sur le guide.
    assert guide.total_reviews == 2
    assert guide.average_rating == 4.5


def test_delete_review_not_owner_not_admin_forbidden():
    svc = _service()
    svc.reviews.get_by_id.return_value = SimpleNamespace(
        id="rev1", guide_id="g1", tourist_id="someone_else"
    )
    user = SimpleNamespace(id="t1", role="tourist", is_admin=False)
    with pytest.raises(ForbiddenError) as exc:
        svc.delete_review("rev1", user)
    assert exc.value.error_code == "FORBIDDEN"


def test_delete_review_admin_can_delete_others():
    svc = _service()
    svc.reviews.get_by_id.return_value = SimpleNamespace(
        id="rev1", guide_id="g1", tourist_id="someone_else"
    )
    svc.guides.get_by_id.return_value = SimpleNamespace(
        id="g1", total_reviews=1, average_rating=5.0
    )
    svc.reviews.rating_aggregates.return_value = (0, None)
    admin = SimpleNamespace(id="a1", role="admin", is_admin=True)

    svc.delete_review("rev1", admin)  # ne lève pas

    svc.reviews.delete.assert_called_once()
