"""Dépendances FastAPI : fourniture des services et gardes d'autorisation.

Chaque service reçoit une session `get_db` ; les repositories sont construits par
le service lui-même. Les gardes (`require_admin`) factorisent le contrôle de rôle.
"""

from fastapi import Depends
from sqlalchemy.orm import Session

from ..auth import get_current_user
from ..config import settings
from ..database import get_db
from ..exceptions import ForbiddenError
from ..models import User
from ..services.admin_service import AdminService
from ..services.analytics_service import AnalyticsService
from ..services.auth_service import AuthService
from ..services.guide_service import GuideService
from ..services.premium_service import PremiumService
from ..services.review_service import ReviewService
from ..services.route_service import RouteService
from ..services.search_service import SearchService
from ..services.time_slot_service import TimeSlotService


def get_auth_service(db: Session = Depends(get_db)) -> AuthService:
    return AuthService(db)


def get_guide_service(db: Session = Depends(get_db)) -> GuideService:
    return GuideService(db)


def get_route_service(db: Session = Depends(get_db)) -> RouteService:
    return RouteService(db)


def get_premium_service(db: Session = Depends(get_db)) -> PremiumService:
    return PremiumService(db)


def get_review_service(db: Session = Depends(get_db)) -> ReviewService:
    return ReviewService(db)


def get_admin_service(db: Session = Depends(get_db)) -> AdminService:
    return AdminService(db)


def get_analytics_service(db: Session = Depends(get_db)) -> AnalyticsService:
    return AnalyticsService(db)


def get_search_service(db: Session = Depends(get_db)) -> SearchService:
    return SearchService(db)


def get_time_slot_service(db: Session = Depends(get_db)) -> TimeSlotService:
    return TimeSlotService(db)


def require_admin(current_user: User = Depends(get_current_user)) -> User:
    """Garde : réserve l'accès aux comptes administrateurs.

    Source de vérité unique : la liste blanche d'emails `ADMIN_EMAILS` (config).
    Ni la colonne `is_admin` ni le rôle `administrator` ne sont consultés ici —
    personne ne peut donc devenir administrateur en écrivant en base.

    La comparaison est insensible à la casse et aux espaces. Une liste vide ou
    non configurée n'autorise personne (fail closed), tout comme un email nul.
    """
    email = (current_user.email or "").strip().lower()
    if not email or email not in settings.admin_emails_list:
        raise ForbiddenError(
            "FORBIDDEN", "Seuls les administrateurs peuvent accéder à cette section"
        )
    return current_user
