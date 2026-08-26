"""Controller Trajets — création, consultation, suppression, listing public."""

from typing import List, Optional

from fastapi import APIRouter, Depends, status

from ..auth import get_current_user
from ..models import GuideRoute, User
from ..schemas import (
    GuideRouteCreate,
    GuideRouteResponse,
    PublicRouteResponse,
    SuccessResponse,
)
from ..services.route_service import RouteService
from .deps import get_route_service

router = APIRouter(prefix="/api/v1")


def _to_route_response(
    route: GuideRoute,
    *,
    with_description: bool = True,
    with_checkpoints: bool = True,
    with_price: bool = True,
) -> GuideRouteResponse:
    """Mappe un GuideRoute vers sa réponse. Les drapeaux reproduisent les
    variantes de champs exposées par chaque endpoint historique."""
    kwargs = dict(
        id=route.id,
        guide_id=route.guide_id,
        coordinates=route.coordinates,
        distance=route.distance,
        duration=route.duration,
        start_address=route.start_address,
        end_address=route.end_address,
        is_active=route.is_active,
        created_at=route.created_at,
        updated_at=route.updated_at,
    )
    if with_description:
        kwargs["description"] = route.description
    if with_checkpoints:
        kwargs["checkpoints"] = route.checkpoints or []
    if with_price:
        kwargs["price"] = route.price
    return GuideRouteResponse(**kwargs)


@router.post(
    "/guides/routes",
    response_model=GuideRouteResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Guide Routes"],
)
async def save_guide_route(
    route_data: GuideRouteCreate,
    current_user: User = Depends(get_current_user),
    service: RouteService = Depends(get_route_service),
):
    route = service.create_route(current_user, route_data)
    return _to_route_response(route)


@router.get("/guides/{guide_id}/route", response_model=GuideRouteResponse, tags=["Guide Routes"])
async def get_guide_route(guide_id: str, service: RouteService = Depends(get_route_service)):
    route = service.get_active_route(guide_id)
    return _to_route_response(route, with_price=False)


@router.get(
    "/guides/{guide_id}/routes/history",
    response_model=List[GuideRouteResponse],
    tags=["Guide Routes"],
)
async def get_guide_routes_history(
    guide_id: str,
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    service: RouteService = Depends(get_route_service),
):
    routes = service.get_history(guide_id, current_user, limit)
    return [
        _to_route_response(r, with_description=False, with_checkpoints=False, with_price=False)
        for r in routes
    ]


@router.delete("/guides/routes/{route_id}", response_model=SuccessResponse, tags=["Guide Routes"])
async def delete_guide_route(
    route_id: str,
    current_user: User = Depends(get_current_user),
    service: RouteService = Depends(get_route_service),
):
    service.delete_route(route_id, current_user)
    return SuccessResponse(
        status="success", message="Trajet supprimé avec succès", data={"route_id": route_id}
    )


@router.get("/routes/all", response_model=List[PublicRouteResponse], tags=["Public Routes"])
async def get_all_active_routes(
    city: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    service: RouteService = Depends(get_route_service),
):
    rows = service.list_all_active(city, limit, offset)
    return [
        PublicRouteResponse(
            route={
                "id": route.id,
                "guide_id": route.guide_id,
                "coordinates": route.coordinates,
                "distance": route.distance,
                "duration": route.duration,
                "start_address": route.start_address,
                "end_address": route.end_address,
                "description": route.description,
                "checkpoints": route.checkpoints or [],
                "is_active": route.is_active,
                "created_at": route.created_at.isoformat() if route.created_at else None,
                "updated_at": route.updated_at.isoformat() if route.updated_at else None,
            },
            guide_name=user.full_name or "",
            guide_photo_url=guide.profile_photo_url,
            guide_rating=guide.average_rating or 0.0,
            guide_total_reviews=guide.total_reviews or 0,
        )
        for route, guide, user in rows
    ]
