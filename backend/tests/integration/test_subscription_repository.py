"""Tests d'intégration SubscriptionRepository — agrégations analytics (SQL réel)."""

from datetime import datetime, timedelta

import pytest

from app.repositories.subscription_repository import SubscriptionRepository
from tests.factories import make_guide, make_subscription

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_total_and_active_revenue(db_session):
    repo = SubscriptionRepository(db_session)
    g = make_guide(db_session)
    make_subscription(db_session, guide=g, amount=399.0, status="active", duration_days=30)
    # Abonnement expiré : compte dans le total mais pas dans l'actif.
    make_subscription(
        db_session, guide=g, amount=399.0, status="expired",
        started_at=datetime.now() - timedelta(days=90), duration_days=30,
    )
    now = datetime.now()
    assert repo.total_revenue() == pytest.approx(798.0)
    assert repo.active_count(now) == 1
    assert repo.active_revenue(now) == pytest.approx(399.0)


def test_revenue_by_month_groups_and_sums(db_session):
    repo = SubscriptionRepository(db_session)
    g = make_guide(db_session)
    this_month = datetime.now().replace(day=1, hour=12)
    last_month = this_month - timedelta(days=20)
    make_subscription(db_session, guide=g, amount=399.0, started_at=this_month)
    make_subscription(db_session, guide=g, amount=399.0, started_at=this_month)
    make_subscription(db_session, guide=g, amount=399.0, started_at=last_month)

    rows = repo.revenue_by_month(last_month - timedelta(days=10))
    # Au moins 2 mois distincts, le mois courant totalise 798.
    totals = {m.strftime("%Y-%m"): rev for m, rev, _ in rows}
    assert totals[this_month.strftime("%Y-%m")] == pytest.approx(798.0)


def test_count_by_tier(db_session):
    repo = SubscriptionRepository(db_session)
    g = make_guide(db_session)
    make_subscription(db_session, guide=g, tier="pro", amount=399.0)
    make_subscription(db_session, guide=g, tier="agency", amount=999.0)
    now = datetime.now()
    breakdown = {t: (c, r) for t, c, r in repo.count_by_tier(now)}
    assert breakdown["pro"][0] == 1
    assert breakdown["agency"][1] == pytest.approx(999.0)
