"""Controller Premium — activation de l'abonnement."""

from fastapi import APIRouter, Depends

from ..auth import get_current_user
from ..models import User
from ..schemas import SuccessResponse
from ..services.premium_service import PremiumService
from .deps import get_premium_service

router = APIRouter(prefix="/api/v1", tags=["Premium"])


@router.post("/guides/upgrade-premium", response_model=SuccessResponse)
async def upgrade_to_premium(
    current_user: User = Depends(get_current_user),
    service: PremiumService = Depends(get_premium_service),
):
    message, data = service.upgrade(current_user)
    return SuccessResponse(status="success", message=message, data=data)
