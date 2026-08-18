"""Tests d'intégration UserRepository (vraie BDD, transaction rollback)."""

import pytest

from app.repositories.user_repository import UserRepository
from tests.factories import make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_get_by_email_found_and_missing(db_session):
    repo = UserRepository(db_session)
    user = make_user(db_session, email="findme@example.com")
    assert repo.get_by_email("findme@example.com").id == user.id
    assert repo.get_by_email("nobody@example.com") is None


def test_get_by_phone(db_session):
    repo = UserRepository(db_session)
    user = make_user(db_session, phone="0655667788")
    assert repo.get_by_phone("0655667788").id == user.id


def test_get_by_verification_token(db_session):
    repo = UserRepository(db_session)
    user = make_user(db_session)
    user.verification_token = "vtok-123"
    db_session.flush()
    assert repo.get_by_verification_token("vtok-123").id == user.id


def test_list_ordered_filters_by_role(db_session):
    repo = UserRepository(db_session)
    make_user(db_session, role="tourist")
    make_user(db_session, role="tourist")
    make_user(db_session, role="guide")
    tourists = repo.list_ordered("tourist")
    assert len(tourists) == 2
    assert all(u.role == "tourist" for u in tourists)


def test_count_and_count_active(db_session):
    repo = UserRepository(db_session)
    make_user(db_session, is_active=True)
    make_user(db_session, is_active=True)
    make_user(db_session, is_active=False)
    assert repo.count() == 3
    assert repo.count_active() == 2
