"""Controller Recherche & Découverte — recherche de guides et de trajets."""

from typing import List, Optional

from fastapi import APIRouter, Depends, Query

from ..schemas import ActiveRouteInfo, SearchGuideResponse, SearchRouteResponse
from ..services.search_service import SearchService
from .deps import get_search_service

router = APIRouter(prefix="/api/v1/search", tags=["Recherche"])


@router.get("/guides", response_model=List[SearchGuideResponse], summary="Recherche avancée de guides")
async def search_guides(
    q: Optional[str] = Query(None, min_length=2, max_length=100),
    city: Optional[str] = Query(None),
    specialty: Optional[str] = Query(None),
    language: Optional[str] = Query(None),
    min_experience: Optional[int] = Query(None, ge=0, le=50),
    min_rating: Optional[float] = Query(None, ge=0.0, le=5.0),
    min_eco_score: Optional[int] = Query(None, ge=0, le=100),
    verified_only: bool = Query(False),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    service: SearchService = Depends(get_search_service),
):
    results = service.search_guides(
        q=q,
        city=city,
        specialty=specialty,
        language=language,
        min_experience=min_experience,
        min_rating=min_rating,
        min_eco_score=min_eco_score,
        verified_only=verified_only,
        limit=limit,
        offset=offset,
    )
    return [
        SearchGuideResponse(user=user, guide=guide, phone=user.phone)
        for user, guide in results
    ]


@router.get(
    "/guides-with-routes",
    response_model=List[SearchRouteResponse],
    summary="Recherche guides avec leur trajet actif",
)
async def search_guides_with_routes(
    q: Optional[str] = Query(None, min_length=2, max_length=100),
    city: Optional[str] = Query(None),
    specialty: Optional[str] = Query(None),
    language: Optional[str] = Query(None),
    min_experience: Optional[int] = Query(None, ge=0, le=50),
    min_rating: Optional[float] = Query(None, ge=0.0, le=5.0),
    min_eco_score: Optional[int] = Query(None, ge=0, le=100),
    verified_only: bool = Query(False),
    route_query: Optional[str] = Query(None, min_length=2, max_length=200),
    include_without_route: bool = Query(False),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    service: SearchService = Depends(get_search_service),
):
    results = service.search_guides_with_routes(
        q=q,
        city=city,
        specialty=specialty,
        language=language,
        min_experience=min_experience,
        min_rating=min_rating,
        min_eco_score=min_eco_score,
        verified_only=verified_only,
        route_query=route_query,
        include_without_route=include_without_route,
        limit=limit,
        offset=offset,
    )

    response_list: List[SearchRouteResponse] = []
    for user, guide, route in results:
        active_route = None
        if route is not None:
            active_route = ActiveRouteInfo(
                route_id=route.id,
                distance=route.distance,
                duration=route.duration,
                start_address=route.start_address,
                end_address=route.end_address,
                coordinates_count=len(route.coordinates) if route.coordinates else 0,
            )
        response_list.append(
            SearchRouteResponse(
                user_id=user.id,
                guide_id=guide.id,
                full_name=user.full_name or "",
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
                active_route=active_route,
            )
        )
    return response_list


@router.get("/filters", summary="Valeurs disponibles pour les filtres de recherche")
async def get_available_filters(service: SearchService = Depends(get_search_service)):
    return service.available_filters()
