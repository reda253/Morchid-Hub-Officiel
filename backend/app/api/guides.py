"""Controller Profils Guides — vérification d'identité et listing."""

from typing import List

from fastapi import APIRouter, Depends, File, Form, UploadFile

from ..auth import get_current_user
from ..models import User
from ..schemas import GuideResponse, SuccessResponse
from ..services.guide_service import GuideService
from .deps import get_guide_service

router = APIRouter(prefix="/api/v1")


@router.post("/auth/verify-guide", response_model=SuccessResponse, tags=["Guide Verification"])
async def verify_guide_identity(
    cine_number: str = Form(...),
    license_number: str = Form(...),
    profile_photo: UploadFile = File(...),
    license_photo: UploadFile = File(...),
    cine_photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    service: GuideService = Depends(get_guide_service),
):
    payload = service.submit_verification(
        current_user,
        cine_number=cine_number,
        license_number=license_number,
        profile_photo=profile_photo,
        license_photo=license_photo,
        cine_photo=cine_photo,
    )
    return SuccessResponse(
        status="success",
        message="Documents reçus ! Votre profil sera certifié sous 12h.",
        data=payload,
    )


@router.get("/guides", response_model=List[GuideResponse], tags=["Guides"])
async def get_all_guides(
    skip: int = 0,
    limit: int = 20,
    service: GuideService = Depends(get_guide_service),
):
    return service.list_guides(skip=skip, limit=limit)
