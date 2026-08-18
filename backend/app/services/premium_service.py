"""Service d'abonnement Premium (paiement simulé)."""

from datetime import datetime, timedelta
from typing import Tuple

from sqlalchemy.orm import Session

from ..exceptions import ForbiddenError, NotFoundError
from ..models import Subscription, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.subscription_repository import SubscriptionRepository

PREMIUM_DURATION_DAYS = 30
# Tarification Premium (DH). Alignée sur le tier "Pro" du design Stitch.
PREMIUM_TIER = "pro"
PREMIUM_PRICE_DH = 399.0


class PremiumService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)
        self.subscriptions = SubscriptionRepository(db)

    def upgrade(self, current_user: User) -> Tuple[str, dict]:
        """Active le Premium 30 jours. Retourne (message, data) pour la réponse."""
        if current_user.role != "guide":
            raise ForbiddenError("NOT_A_GUIDE", "Seuls les guides peuvent s'abonner au Premium")

        guide = self.guides.get_by_user_id(current_user.id)
        if not guide:
            raise NotFoundError("GUIDE_PROFILE_NOT_FOUND", "Profil guide non trouvé")

        # Déjà Premium et non expiré : aucune action (no-op informatif)
        if guide.is_premium and guide.premium_until:
            if datetime.now(guide.premium_until.tzinfo) < guide.premium_until:
                return (
                    "Vous êtes déjà abonné Premium",
                    {
                        "is_premium": True,
                        "premium_until": guide.premium_until.isoformat(),
                        "days_remaining": (
                            guide.premium_until - datetime.now(guide.premium_until.tzinfo)
                        ).days,
                    },
                )

        now = datetime.now()
        guide.is_premium = True
        guide.premium_until = now + timedelta(days=PREMIUM_DURATION_DAYS)

        # Enregistrement facturable : alimente les analytics revenu/abonnements.
        self.subscriptions.add(
            Subscription(
                guide_id=guide.id,
                tier=PREMIUM_TIER,
                amount=PREMIUM_PRICE_DH,
                currency="MAD",
                status="active",
                started_at=now,
                expires_at=guide.premium_until,
            )
        )

        self.db.commit()
        self.db.refresh(guide)

        return (
            "✨ Bienvenue dans Morchid Hub Premium !",
            {
                "is_premium": True,
                "premium_until": guide.premium_until.isoformat(),
                "days_remaining": PREMIUM_DURATION_DAYS,
                "benefits": [
                    "Trajets illimités",
                    "Meilleure visibilité",
                    "Support prioritaire",
                    "Badge Premium",
                ],
            },
        )
