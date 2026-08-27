"""Accès aux données de la table `guide_routes` (trajets géolocalisés PostGIS).

La construction des géométries PostGIS (Point / LineString) est encapsulée ici
via `build_route`, afin que le service métier n'ait pas à connaître shapely /
geoalchemy2.
"""

from typing import List, Optional, Tuple

from geoalchemy2.shape import from_shape
from shapely.geometry import LineString, Point
from sqlalchemy import String, cast

from ..models import Checkpoint, Guide, GuideRoute, User
from ..schemas import GuideRouteCreate
from .base import BaseRepository


class RouteRepository(BaseRepository):

    def get_by_id(self, route_id: str) -> Optional[GuideRoute]:
        return self.db.query(GuideRoute).filter(GuideRoute.id == route_id).first()

    def get_by_id_and_guide(self, route_id: str, guide_id: str) -> Optional[GuideRoute]:
        return (
            self.db.query(GuideRoute)
            .filter(GuideRoute.id == route_id, GuideRoute.guide_id == guide_id)
            .first()
        )

    def get_active_by_guide(self, guide_id: str) -> Optional[GuideRoute]:
        return (
            self.db.query(GuideRoute)
            .filter(GuideRoute.guide_id == guide_id, GuideRoute.is_active == True)
            .first()
        )

    def count_active_by_guide(self, guide_id: str) -> int:
        return (
            self.db.query(GuideRoute)
            .filter(GuideRoute.guide_id == guide_id, GuideRoute.is_active == True)
            .count()
        )

    def deactivate_active_by_guide(self, guide_id: str) -> None:
        (
            self.db.query(GuideRoute)
            .filter(GuideRoute.guide_id == guide_id, GuideRoute.is_active == True)
            .update({"is_active": False})
        )

    def history_by_guide(self, guide_id: str, limit: int) -> List[GuideRoute]:
        return (
            self.db.query(GuideRoute)
            .filter(GuideRoute.guide_id == guide_id)
            .order_by(GuideRoute.created_at.desc())
            .limit(limit)
            .all()
        )

    @staticmethod
    def build_route(guide_id: str, data: GuideRouteCreate) -> GuideRoute:
        """Construit une entité GuideRoute (géométries PostGIS incluses) sans l'insérer."""
        start_point = Point(data.start_point.lng, data.start_point.lat)
        end_point = Point(data.end_point.lng, data.end_point.lat)
        route_line = LineString([(c.lng, c.lat) for c in data.coordinates])

        checkpoints_data = [cp.dict() for cp in data.checkpoints] if data.checkpoints else []

        route = GuideRoute(
            guide_id=guide_id,
            route_line=from_shape(route_line, srid=4326),
            start_point=from_shape(start_point, srid=4326),
            end_point=from_shape(end_point, srid=4326),
            coordinates=[{"lat": c.lat, "lng": c.lng} for c in data.coordinates],
            distance=data.distance,
            duration=data.duration,
            start_address=data.start_address,
            end_address=data.end_address,
            description=data.description,
            checkpoints=checkpoints_data,  # dénormalisation JSON (compat réponse)
            price=data.price,
            is_active=True,
        )
        # Phase B (UML) : écriture canonique en table `checkpoints`. La cascade
        # de la relation insère les lignes lors du commit du trajet.
        route.checkpoint_rows = [
            Checkpoint(
                name=cp.name,
                description=cp.description,
                lat=cp.lat,
                lng=cp.lng,
                type=cp.type,
                estimated_time=cp.estimated_time,
                image_url=cp.image_url,
                position=index,
            )
            for index, cp in enumerate(data.checkpoints or [])
        ]
        return route

    def add(self, route: GuideRoute) -> None:
        self.db.add(route)

    def delete(self, route: GuideRoute) -> None:
        self.db.delete(route)

    def list_active_with_guide_and_user(
        self, city: Optional[str], limit: int, offset: int
    ) -> List[Tuple[GuideRoute, Guide, User]]:
        """Trajets actifs de guides vérifiés, joints au guide et à l'utilisateur (endpoint public)."""
        query = (
            self.db.query(GuideRoute, Guide, User)
            .join(Guide, GuideRoute.guide_id == Guide.id)
            .join(User, Guide.user_id == User.id)
            .filter(GuideRoute.is_active == True)
            .filter(Guide.is_verified == True)
        )
        if city and city.strip():
            query = query.filter(cast(Guide.cities_covered, String).ilike(f"%{city}%"))
        return (
            query.order_by(GuideRoute.created_at.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )
