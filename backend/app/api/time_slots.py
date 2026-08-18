"""Controller Créneaux (TimeSlot) — programmation de trajets (Phase B / UML)."""

from typing import List

from fastapi import APIRouter, Depends, status

from ..auth import get_current_user
from ..models import User
from ..schemas import SuccessResponse, TimeSlotCreate, TimeSlotResponse
from ..services.time_slot_service import TimeSlotService
from .deps import get_time_slot_service

router = APIRouter(prefix="/api/v1", tags=["Créneaux (TimeSlots)"])


@router.post(
    "/guides/routes/{route_id}/slots",
    response_model=TimeSlotResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_slot(
    route_id: str,
    data: TimeSlotCreate,
    current_user: User = Depends(get_current_user),
    service: TimeSlotService = Depends(get_time_slot_service),
):
    slot = service.create_slot(
        current_user, route_id, data.scheduled_start, data.scheduled_end
    )
    return TimeSlotResponse.from_orm(slot)


@router.get(
    "/guides/routes/{route_id}/slots",
    response_model=List[TimeSlotResponse],
)
async def list_slots(
    route_id: str,
    service: TimeSlotService = Depends(get_time_slot_service),
):
    return [TimeSlotResponse.from_orm(s) for s in service.list_slots(route_id)]


@router.delete("/guides/slots/{slot_id}", response_model=SuccessResponse)
async def cancel_slot(
    slot_id: str,
    current_user: User = Depends(get_current_user),
    service: TimeSlotService = Depends(get_time_slot_service),
):
    slot = service.cancel_slot(current_user, slot_id)
    return SuccessResponse(
        status="success",
        message="Créneau annulé",
        data={"slot_id": slot.id, "status": slot.status},
    )
