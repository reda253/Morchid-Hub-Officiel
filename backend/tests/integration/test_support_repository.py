"""Tests d'intégration SupportRepository — JOIN unique (correction N+1), tri, compte."""

import pytest

from app.repositories.support_repository import SupportRepository
from tests.factories import make_support_message, make_user

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_list_with_users_joins_author(db_session):
    repo = SupportRepository(db_session)
    user = make_user(db_session, full_name="Sami")
    make_support_message(db_session, user=user, subject="Bug")

    rows = repo.list_with_users(resolved=None)
    assert len(rows) == 1
    msg, author = rows[0]
    assert msg.subject == "Bug"
    assert author.full_name == "Sami"  # jointure résolue, pas de N+1


def test_list_with_users_filter_resolved(db_session):
    repo = SupportRepository(db_session)
    user = make_user(db_session)
    make_support_message(db_session, user=user, is_resolved=False)
    make_support_message(db_session, user=user, is_resolved=True)

    assert len(repo.list_with_users(resolved=False)) == 1
    assert len(repo.list_with_users(resolved=True)) == 1
    assert len(repo.list_with_users(resolved=None)) == 2


def test_list_with_users_unresolved_first(db_session):
    repo = SupportRepository(db_session)
    user = make_user(db_session)
    make_support_message(db_session, user=user, is_resolved=True, subject="Résolu")
    make_support_message(db_session, user=user, is_resolved=False, subject="Ouvert")

    rows = repo.list_with_users(resolved=None)
    # is_resolved ASC -> non résolus d'abord.
    assert rows[0][0].is_resolved is False


def test_count_unresolved(db_session):
    repo = SupportRepository(db_session)
    user = make_user(db_session)
    make_support_message(db_session, user=user, is_resolved=False)
    make_support_message(db_session, user=user, is_resolved=False)
    make_support_message(db_session, user=user, is_resolved=True)
    assert repo.count_unresolved() == 2
