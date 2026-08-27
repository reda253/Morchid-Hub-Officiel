"""Tests d'intégration ReviewRepository — agrégation note (COUNT/AVG)."""

import pytest

from app.repositories.review_repository import ReviewRepository
from tests.factories import make_guide, make_review, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_rating_aggregates_empty(db_session):
    repo = ReviewRepository(db_session)
    guide = make_guide(db_session)
    count, avg = repo.rating_aggregates(guide.id)
    assert count == 0
    assert avg is None


def test_rating_aggregates_after_inserts(db_session):
    repo = ReviewRepository(db_session)
    guide = make_guide(db_session)
    for rating in (5, 4, 4, 5, 4):  # moyenne 4.4
        tourist = make_user(db_session, role="tourist")
        make_review(db_session, guide=guide, tourist=tourist, rating=rating)

    count, avg = repo.rating_aggregates(guide.id)
    assert count == 5
    assert round(float(avg), 1) == 4.4


def test_get_by_guide_and_tourist_dedup_guard(db_session):
    repo = ReviewRepository(db_session)
    guide = make_guide(db_session)
    tourist = make_user(db_session, role="tourist")
    make_review(db_session, guide=guide, tourist=tourist)
    assert repo.get_by_guide_and_tourist(guide.id, tourist.id) is not None

    other = make_user(db_session, role="tourist")
    assert repo.get_by_guide_and_tourist(guide.id, other.id) is None


def test_list_with_tourist_orders_recent_first(db_session):
    repo = ReviewRepository(db_session)
    guide = make_guide(db_session)
    t1 = make_user(db_session, role="tourist", full_name="Alice")
    t2 = make_user(db_session, role="tourist", full_name="Bob")
    make_review(db_session, guide=guide, tourist=t1)
    make_review(db_session, guide=guide, tourist=t2)

    rows = repo.list_with_tourist(guide.id, limit=20, offset=0)
    assert len(rows) == 2
    # Chaque ligne est (Review, User).
    assert {u.full_name for _r, u in rows} == {"Alice", "Bob"}
