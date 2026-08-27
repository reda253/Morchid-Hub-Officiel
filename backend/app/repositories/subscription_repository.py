"""Accès aux données de la table `subscriptions` + agrégations analytics (Phase B).

Toutes les requêtes SQL des analytics revenu/abonnements vivent ici ; le service
n'assemble que des dictionnaires de réponse.
"""

from datetime import datetime
from typing import List, Optional, Tuple

from sqlalchemy import func as sqlfunc
from sqlalchemy import text

from ..models import Subscription
from .base import BaseRepository


class SubscriptionRepository(BaseRepository):

    def add(self, subscription: Subscription) -> None:
        self.db.add(subscription)

    def list_by_guide(self, guide_id: str) -> List[Subscription]:
        return (
            self.db.query(Subscription)
            .filter(Subscription.guide_id == guide_id)
            .order_by(Subscription.started_at.desc())
            .all()
        )

    # ── Agrégats globaux ──────────────────────────────────────────────────
    def total_revenue(self) -> float:
        return float(self.db.query(sqlfunc.coalesce(sqlfunc.sum(Subscription.amount), 0)).scalar() or 0)

    def revenue_between(self, start: datetime, end: datetime) -> float:
        return float(
            self.db.query(sqlfunc.coalesce(sqlfunc.sum(Subscription.amount), 0))
            .filter(Subscription.started_at >= start, Subscription.started_at < end)
            .scalar()
            or 0
        )

    def count_started_between(self, start: datetime, end: datetime) -> int:
        return (
            self.db.query(Subscription)
            .filter(Subscription.started_at >= start, Subscription.started_at < end)
            .count()
        )

    def active_count(self, now: datetime) -> int:
        """Abonnements encore valides (non expirés, non annulés)."""
        return (
            self.db.query(Subscription)
            .filter(Subscription.status != "cancelled", Subscription.expires_at > now)
            .count()
        )

    def active_revenue(self, now: datetime) -> float:
        """Somme des montants des abonnements actifs (base du MRR)."""
        return float(
            self.db.query(sqlfunc.coalesce(sqlfunc.sum(Subscription.amount), 0))
            .filter(Subscription.status != "cancelled", Subscription.expires_at > now)
            .scalar()
            or 0
        )

    def total_count(self) -> int:
        return self.db.query(Subscription).count()

    # ── Séries / répartitions ─────────────────────────────────────────────
    def revenue_by_month(self, since: datetime) -> List[Tuple[datetime, float, int]]:
        """(mois tronqué, revenu du mois, nb d'abonnements) depuis `since`, ordre chronologique."""
        month = sqlfunc.date_trunc("month", Subscription.started_at).label("month")
        # Grouper/trier par l'alias de sortie : le 1er argument de date_trunc est un
        # paramètre lié, donc Postgres ne reconnaît pas l'expression répétée en GROUP BY.
        rows = (
            self.db.query(
                month,
                sqlfunc.coalesce(sqlfunc.sum(Subscription.amount), 0).label("revenue"),
                sqlfunc.count(Subscription.id).label("count"),
            )
            .filter(Subscription.started_at >= since)
            .group_by(text("month"))
            .order_by(text("month"))
            .all()
        )
        return [(r.month, float(r.revenue or 0), int(r.count or 0)) for r in rows]

    def count_by_tier(self, now: Optional[datetime] = None) -> List[Tuple[str, int, float]]:
        """(tier, nb d'abonnements actifs, revenu total du tier)."""
        query = self.db.query(
            Subscription.tier,
            sqlfunc.count(Subscription.id),
            sqlfunc.coalesce(sqlfunc.sum(Subscription.amount), 0),
        )
        if now is not None:
            query = query.filter(Subscription.status != "cancelled", Subscription.expires_at > now)
        rows = query.group_by(Subscription.tier).all()
        return [(tier, int(cnt), float(rev or 0)) for tier, cnt, rev in rows]
