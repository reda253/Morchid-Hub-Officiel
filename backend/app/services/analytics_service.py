"""Service analytics admin — revenu & abonnements réels (Phase B).

Alimente le tableau de bord admin (design Stitch) à partir de la table
`subscriptions` : KPI de revenu, série mensuelle, répartition par tier.
Aucune donnée factice — tout est agrégé depuis les enregistrements réels.
"""

from datetime import datetime
from typing import List

from sqlalchemy.orm import Session

from ..repositories.subscription_repository import SubscriptionRepository

_MONTH_LABELS = [
    "Jan", "Fév", "Mar", "Avr", "Mai", "Juin",
    "Juil", "Août", "Sep", "Oct", "Nov", "Déc",
]


def _month_start(dt: datetime) -> datetime:
    return dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)


def _add_months(dt: datetime, n: int) -> datetime:
    """Décale `dt` (au 1er du mois) de `n` mois (n peut être négatif)."""
    total = (dt.year * 12 + (dt.month - 1)) + n
    year, month = divmod(total, 12)
    return dt.replace(year=year, month=month + 1)


class AnalyticsService:
    def __init__(self, db: Session):
        self.db = db
        self.subs = SubscriptionRepository(db)

    def overview(self) -> dict:
        now = datetime.now()
        this_month = _month_start(now)
        next_month = _add_months(this_month, 1)
        last_month = _add_months(this_month, -1)

        total_revenue = self.subs.total_revenue()
        active = self.subs.active_count(now)
        mrr = self.subs.active_revenue(now)  # abonnements mensuels -> MRR = somme active
        new_this_month = self.subs.count_started_between(this_month, next_month)
        revenue_this_month = self.subs.revenue_between(this_month, next_month)
        revenue_last_month = self.subs.revenue_between(last_month, this_month)
        total_subs = self.subs.total_count()

        growth = self._growth_pct(revenue_last_month, revenue_this_month)
        arpu = round(total_revenue / total_subs, 2) if total_subs else 0.0

        return {
            "currency": "MAD",
            "total_revenue": round(total_revenue, 2),
            "revenue_this_month": round(revenue_this_month, 2),
            "revenue_last_month": round(revenue_last_month, 2),
            "revenue_growth_pct": growth,
            "active_subscriptions": active,
            "mrr": round(mrr, 2),
            "new_subscriptions_this_month": new_this_month,
            "total_subscriptions": total_subs,
            "arpu": arpu,
        }

    def revenue_timeseries(self, months: int) -> dict:
        """Série mensuelle continue (mois vides remplis à 0) sur `months` mois."""
        now = datetime.now()
        this_month = _month_start(now)
        since = _add_months(this_month, -(months - 1))

        raw = {m.strftime("%Y-%m"): (rev, cnt) for m, rev, cnt in self.subs.revenue_by_month(since)}

        points: List[dict] = []
        cursor = since
        for _ in range(months):
            key = cursor.strftime("%Y-%m")
            revenue, count = raw.get(key, (0.0, 0))
            points.append({
                "month": key,
                "label": _MONTH_LABELS[cursor.month - 1],
                "revenue": round(revenue, 2),
                "subscriptions": count,
            })
            cursor = _add_months(cursor, 1)

        return {
            "currency": "MAD",
            "months": months,
            "points": points,
            "total_revenue": round(sum(p["revenue"] for p in points), 2),
        }

    def subscriptions_breakdown(self) -> dict:
        now = datetime.now()
        by_tier = [
            {"tier": tier, "active": cnt, "revenue": round(rev, 2)}
            for tier, cnt, rev in self.subs.count_by_tier(now)
        ]
        return {
            "currency": "MAD",
            "active_total": sum(t["active"] for t in by_tier),
            "by_tier": by_tier,
        }

    @staticmethod
    def _growth_pct(previous: float, current: float) -> float:
        if previous <= 0:
            return 100.0 if current > 0 else 0.0
        return round(((current - previous) / previous) * 100, 1)
