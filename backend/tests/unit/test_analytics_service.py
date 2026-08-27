"""Tests unitaires du AnalyticsService — calculs revenu/abonnements (repo mocké)."""

from datetime import datetime
from unittest.mock import MagicMock

import pytest

from app.services.analytics_service import AnalyticsService, _add_months, _month_start

pytestmark = pytest.mark.unit


def _service():
    svc = AnalyticsService(db=MagicMock())
    svc.subs = MagicMock()
    return svc


def test_growth_pct_edge_cases():
    assert AnalyticsService._growth_pct(0, 0) == 0.0
    assert AnalyticsService._growth_pct(0, 500) == 100.0
    assert AnalyticsService._growth_pct(100, 150) == 50.0
    assert AnalyticsService._growth_pct(200, 100) == -50.0


def test_overview_assembles_kpis():
    svc = _service()
    svc.subs.total_revenue.return_value = 3990.0
    svc.subs.active_count.return_value = 7
    svc.subs.active_revenue.return_value = 2793.0
    svc.subs.count_started_between.return_value = 3
    # revenue_between appelé 2x : this_month puis last_month
    svc.subs.revenue_between.side_effect = [1197.0, 798.0]
    svc.subs.total_count.return_value = 10

    o = svc.overview()

    assert o["total_revenue"] == 3990.0
    assert o["active_subscriptions"] == 7
    assert o["mrr"] == 2793.0
    assert o["new_subscriptions_this_month"] == 3
    assert o["revenue_this_month"] == 1197.0
    assert o["revenue_last_month"] == 798.0
    assert o["revenue_growth_pct"] == 50.0
    assert o["arpu"] == 399.0  # 3990 / 10
    assert o["currency"] == "MAD"


def test_revenue_timeseries_fills_missing_months():
    svc = _service()
    now = datetime.now()
    this_month = _month_start(now)
    # Seul le mois courant a du revenu ; les 2 précédents doivent apparaître à 0.
    svc.subs.revenue_by_month.return_value = [(this_month, 798.0, 2)]

    ts = svc.revenue_timeseries(months=3)

    assert len(ts["points"]) == 3
    assert ts["points"][-1]["revenue"] == 798.0
    assert ts["points"][-1]["subscriptions"] == 2
    assert ts["points"][0]["revenue"] == 0.0  # mois vide rempli
    assert ts["total_revenue"] == 798.0


def test_subscriptions_breakdown_by_tier():
    svc = _service()
    svc.subs.count_by_tier.return_value = [("pro", 5, 1995.0), ("agency", 2, 1998.0)]
    b = svc.subscriptions_breakdown()
    assert b["active_total"] == 7
    tiers = {t["tier"]: t for t in b["by_tier"]}
    assert tiers["pro"]["active"] == 5
    assert tiers["agency"]["revenue"] == 1998.0


def test_add_months_wraps_year():
    jan = datetime(2026, 1, 1)
    assert _add_months(jan, -1) == datetime(2025, 12, 1)
    assert _add_months(jan, 13) == datetime(2027, 2, 1)
