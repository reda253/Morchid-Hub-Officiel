"""Controller Profils Guides — vérification d'identité et listing."""

from typing import List

from fastapi import APIRouter, Depends, File, Form, UploadFile

from ..auth import get_current_user
from ..exceptions import NotFoundError
from ..models import User
from ..schemas import GuideResponse, PublicGuideCard, SuccessResponse
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


@router.get("/guides", response_model=List[PublicGuideCard], tags=["Guides"])
async def get_all_guides(
    skip: int = 0,
    limit: int = 20,
    service: GuideService = Depends(get_guide_service),
):
    """Listing public des guides approuvés — aucune donnée personnelle."""
    guides = service.list_guides(skip=skip, limit=limit)
    return [
        PublicGuideCard(
            user_id=guide.user_id,
            guide_id=guide.id,
            full_name=(guide.user.full_name if guide.user else "") or "",
            profile_photo_url=guide.profile_photo_url,
            languages=guide.languages or [],
            specialties=guide.specialties or [],
            cities_covered=guide.cities_covered or [],
            years_of_experience=guide.years_of_experience,
            bio=guide.bio or "",
            is_verified=guide.is_verified,
            eco_score=guide.eco_score,
            average_rating=guide.average_rating or 0.0,
            total_reviews=guide.total_reviews or 0,
        )
        for guide in guides
    ]


@router.get("/guides/{guide_id}/contact", tags=["Guides"])
async def get_guide_contact(
    guide_id: str,
    current_user: User = Depends(get_current_user),
    service: GuideService = Depends(get_guide_service),
):
    """Numéro de téléphone d'un guide — réservé aux utilisateurs connectés.

    Le numéro ne fait plus partie de la réponse de recherche : un annuaire de
    numéros de guides ne doit pas être moissonnable anonymement.

    Un guide non approuvé renvoie 404 et non 403, pour ne pas confirmer
    l'existence d'un compte à partir de son id.
    """
    guide = service.get_public_guide(guide_id)
    if guide is None:
        raise NotFoundError("GUIDE_NOT_FOUND", "Guide introuvable")
    return {"phone": guide.user.phone if guide.user else None}
