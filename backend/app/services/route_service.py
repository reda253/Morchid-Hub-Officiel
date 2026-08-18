"""Service des trajets guides : création (règle Premium/limite), consultation, suppression."""

from typing import List, Optional, Tuple

from sqlalchemy.orm import Session

from ..exceptions import BadRequestError, ForbiddenError, NotFoundError, ServerError
from ..models import Guide, GuideRoute, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.route_repository import RouteRepository
from ..schemas import GuideRouteCreate

FREE_ROUTE_LIMIT = 2


class RouteService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)
        self.routes = RouteRepository(db)

    def create_route(self, current_user: User, data: GuideRouteCreate) -> GuideRoute:
        if current_user.role != "guide":
            raise ForbiddenError("NOT_A_GUIDE", "Seuls les guides peuvent créer des trajets")

        guide = self.guides.get_by_user_id(current_user.id)
        if not guide:
            raise NotFoundError("GUIDE_PROFILE_NOT_FOUND", "Profil guide non trouvé")

        # Règle Premium / limite gratuite
        active_count = self.routes.count_active_by_guide(guide.id)
        if not guide.is_premium_active() and active_count >= FREE_ROUTE_LIMIT:
            raise ForbiddenError(
                "FREE_LIMIT_REACHED",
                "Limite de trajets gratuits atteinte (2/2). Passez au Premium pour créer des trajets illimités.",
                details={
                    "current_routes": active_count,
                    "max_routes": FREE_ROUTE_LIMIT,
                    "upgrade_required": True,
                },
            )

        # Un seul trajet actif : désactiver les précédents
        self.routes.deactivate_active_by_guide(guide.id)

        try:
            new_route = RouteRepository.build_route(guide.id, data)
        except Exception as e:
            raise BadRequestError("INVALID_GEOMETRY", f"Données géométriques invalides: {str(e)}")

        try:
            self.routes.add(new_route)
            self.db.commit()
            self.db.refresh(new_route)
        except Exception as e:
            self.db.rollback()
            raise ServerError("SAVE_ERROR", f"Erreur lors de la sauvegarde: {str(e)}")

        return new_route

    def get_active_route(self, guide_id: str) -> GuideRoute:
        guide = self.guides.get_by_id(guide_id)
        if not guide:
            raise NotFoundError("GUIDE_NOT_FOUND", "Guide non trouvé")
        route = self.routes.get_active_by_guide(guide_id)
        if not route:
            raise NotFoundError("NO_ACTIVE_ROUTE", "Aucun trajet actif pour ce guide")
        return route

    def get_history(self, guide_id: str, current_user: User, limit: int) -> List[GuideRoute]:
        guide = self.guides.get_owned(guide_id, current_user.id)
        if not guide:
            raise ForbiddenError("UNAUTHORIZED", "Vous ne pouvez voir que vos propres trajets")
        return self.routes.history_by_guide(guide_id, limit)

    def delete_route(self, route_id: str, current_user: User) -> None:
        route = self.routes.get_by_id(route_id)
        if not route:
            raise NotFoundError("ROUTE_NOT_FOUND", "Trajet non trouvé")
        guide = self.guides.get_owned(route.guide_id, current_user.id)
        if not guide:
            raise ForbiddenError("UNAUTHORIZED", "Vous ne pouvez supprimer que vos propres trajets")
        self.routes.delete(route)
        self.db.commit()

    def list_all_active(
        self, city: Optional[str], limit: int, offset: int
    ) -> List[Tuple[GuideRoute, Guide, User]]:
        return self.routes.list_active_with_guide_and_user(city, limit, offset)
