"""Service des créneaux programmés (TimeSlot) — Phase B / UML.

Porte la règle RG21 : aucun chevauchement entre les créneaux d'un même guide
(`Guide.hasConflictingSlot`). Un créneau ne peut être créé que sur un trajet
appartenant au guide connecté.
"""

from datetime import datetime, timezone
from typing import List

from sqlalchemy.orm import Session

from ..exceptions import ConflictError, ForbiddenError, NotFoundError
from ..models import TimeSlot, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.route_repository import RouteRepository
from ..repositories.time_slot_repository import TimeSlotRepository


class TimeSlotService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)
        self.routes = RouteRepository(db)
        self.slots = TimeSlotRepository(db)

    def _owned_route(self, route_id: str, current_user: User):
        if current_user.role != "guide":
            raise ForbiddenError("NOT_A_GUIDE", "Seuls les guides peuvent programmer des créneaux")
        guide = self.guides.get_by_user_id(current_user.id)
        if not guide:
            raise NotFoundError("GUIDE_PROFILE_NOT_FOUND", "Profil guide non trouvé")
        route = self.routes.get_by_id_and_guide(route_id, guide.id)
        if not route:
            raise NotFoundError("ROUTE_NOT_FOUND", "Trajet introuvable ou n'appartenant pas à ce guide")
        return guide, route

    def has_conflicting_slot(self, guide_id: str, start: datetime, end: datetime) -> bool:
        """RG21 : vrai si [start, end] chevauche un créneau non annulé du guide."""
        return any(
            slot.overlaps(start, end)
            for slot in self.slots.list_active_for_guide(guide_id)
        )

    @staticmethod
    def _to_utc(dt: datetime) -> datetime:
        """Normalise en UTC tz-aware pour un stockage/comparaison cohérents
        (les entrées HTTP naïves sont interprétées en UTC)."""
        return dt.replace(tzinfo=timezone.utc) if dt.tzinfo is None else dt.astimezone(timezone.utc)

    def create_slot(
        self, current_user: User, route_id: str, start: datetime, end: datetime
    ) -> TimeSlot:
        guide, route = self._owned_route(route_id, current_user)
        start, end = self._to_utc(start), self._to_utc(end)

        if self.has_conflicting_slot(guide.id, start, end):
            raise ConflictError(
                "SLOT_CONFLICT",
                "Ce créneau chevauche un créneau existant (RG21).",
                details={"scheduled_start": start.isoformat(), "scheduled_end": end.isoformat()},
            )

        slot = TimeSlot(route_id=route.id, scheduled_start=start, scheduled_end=end, status="upcoming")
        self.slots.add(slot)
        self.db.commit()
        self.db.refresh(slot)
        return slot

    def list_slots(self, route_id: str) -> List[TimeSlot]:
        route = self.routes.get_by_id(route_id)
        if not route:
            raise NotFoundError("ROUTE_NOT_FOUND", "Trajet non trouvé")
        return self.slots.list_for_route(route_id)

    def cancel_slot(self, current_user: User, slot_id: str) -> TimeSlot:
        slot = self.slots.get_by_id(slot_id)
        if not slot:
            raise NotFoundError("SLOT_NOT_FOUND", "Créneau introuvable")
        # Vérifie la propriété via le trajet du créneau.
        self._owned_route(slot.route_id, current_user)
        if slot.status == "cancelled":
            raise ConflictError("ALREADY_CANCELLED", "Ce créneau est déjà annulé")
        slot.status = "cancelled"
        self.db.commit()
        self.db.refresh(slot)
        return slot
