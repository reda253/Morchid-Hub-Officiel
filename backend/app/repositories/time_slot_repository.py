"""Accès aux données de la table `time_slots` (créneaux programmés — Phase B)."""

from typing import List, Optional

from ..models import GuideRoute, TimeSlot
from .base import BaseRepository


class TimeSlotRepository(BaseRepository):

    def get_by_id(self, slot_id: str) -> Optional[TimeSlot]:
        return self.db.query(TimeSlot).filter(TimeSlot.id == slot_id).first()

    def list_for_route(self, route_id: str) -> List[TimeSlot]:
        return (
            self.db.query(TimeSlot)
            .filter(TimeSlot.route_id == route_id)
            .order_by(TimeSlot.scheduled_start.asc())
            .all()
        )

    def list_active_for_guide(self, guide_id: str) -> List[TimeSlot]:
        """Créneaux non annulés de tous les trajets d'un guide (base du contrôle RG21)."""
        return (
            self.db.query(TimeSlot)
            .join(GuideRoute, TimeSlot.route_id == GuideRoute.id)
            .filter(GuideRoute.guide_id == guide_id)
            .filter(TimeSlot.status != "cancelled")
            .all()
        )

    def add(self, slot: TimeSlot) -> None:
        self.db.add(slot)
