"""Tests d'intégration API — analytics admin (revenu/abonnements réels)."""

from datetime import datetime, timedelta

import pytest

from app.models import Subscription
from tests.factories import (
    auth_headers,
    make_guide,
    make_subscription,
    make_user,
)

pytestmark = [pytest.mark.integration, pytest.mark.db]


def test_overview_reflects_real_subscriptions(client, db_session, admin_user):
    g1 = make_guide(db_session)
    g2 = make_guide(db_session)
    # 2 abonnements actifs ce mois-ci (399 chacun) + 1 le mois dernier.
    make_subscription(db_session, guide=g1, amount=399.0)
    make_subscription(db_session, guide=g2, amount=399.0)
    make_subscription(
        db_session, guide=g1, amount=399.0,
        started_at=datetime.now().replace(day=1) - timedelta(days=5),
    )

    resp = client.get("/api/v1/admin/analytics/overview", headers=auth_headers(admin_user))
    assert resp.status_code == 200
    o = resp.json()
    assert o["total_revenue"] == pytest.approx(1197.0)
    assert o["active_subscriptions"] >= 2
    assert o["new_subscriptions_this_month"] == 2
    assert o["currency"] == "MAD"


def test_revenue_timeseries_has_continuous_months(client, db_session, admin_user):
    g = make_guide(db_session)
    make_subscription(db_session, guide=g, amount=399.0)

    resp = client.get(
        "/api/v1/admin/analytics/revenue", params={"months": 6},
        headers=auth_headers(admin_user),
    )
    assert resp.status_code == 200
    body = resp.json()
    assert len(body["points"]) == 6
    assert body["points"][-1]["revenue"] == pytest.approx(399.0)  # mois courant
    assert all("label" in p for p in body["points"])


def test_subscriptions_breakdown_by_tier(client, db_session, admin_user):
    g1, g2 = make_guide(db_session), make_guide(db_session)
    make_subscription(db_session, guide=g1, tier="pro", amount=399.0)
    make_subscription(db_session, guide=g2, tier="agency", amount=999.0)

    resp = client.get(
        "/api/v1/admin/analytics/subscriptions", headers=auth_headers(admin_user)
    )
    assert resp.status_code == 200
    body = resp.json()
    tiers = {t["tier"]: t for t in body["by_tier"]}
    assert tiers["pro"]["active"] == 1
    assert tiers["agency"]["revenue"] == pytest.approx(999.0)


def test_analytics_requires_admin(client, db_session):
    tourist = make_user(db_session, role="tourist", is_admin=False)
    resp = client.get("/api/v1/admin/analytics/overview", headers=auth_headers(tourist))
    assert resp.status_code == 403


def test_premium_upgrade_creates_subscription_record(client, db_session):
    guide_user = make_user(db_session, role="guide")
    guide = make_guide(db_session, user=guide_user)

    resp = client.post(
        "/api/v1/guides/upgrade-premium", headers=auth_headers(guide_user)
    )
    assert resp.status_code == 200

    subs = (
        db_session.query(Subscription)
        .filter(Subscription.guide_id == guide.id)
        .all()
    )
    assert len(subs) == 1
    assert subs[0].amount == 399.0
    assert subs[0].tier == "pro"
    assert subs[0].status == "active"
