"""Controller Avis — création, listing public, suppression."""

from fastapi import APIRouter, Depends, Query, status

from ..auth import get_current_user
from ..models import Review, User
from ..schemas import ReviewCreate, ReviewListResponse, ReviewResponse, SuccessResponse
from ..services.review_service import ReviewService
from .deps import get_review_service

router = APIRouter(prefix="/api/v1", tags=["Avis (Reviews)"])


def _to_review_response(review: Review, tourist_name: str) -> ReviewResponse:
    return ReviewResponse(
        id=review.id,
        guide_id=review.guide_id,
        tourist_id=review.tourist_id,
        tourist_name=tourist_name,
        route_id=review.route_id,
        rating=review.rating,
        comment=review.comment,
        created_at=review.created_at,
    )


@router.post("/reviews", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
async def create_review(
    review_data: ReviewCreate,
    current_user: User = Depends(get_current_user),
    service: ReviewService = Depends(get_review_service),
):
    review, tourist_name = service.create_review(current_user, review_data)
    return _to_review_response(review, tourist_name)


@router.get("/guides/{guide_id}/reviews", response_model=ReviewListResponse)
async def list_guide_reviews(
    guide_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    service: ReviewService = Depends(get_review_service),
):
    guide, rows = service.list_reviews(guide_id, limit, offset)
    return ReviewListResponse(
        guide_id=guide_id,
        average_rating=guide.average_rating,
        total_reviews=guide.total_reviews,
        reviews=[
            _to_review_response(review, tourist.full_name or "Touriste anonyme")
            for review, tourist in rows
        ],
    )


@router.delete("/reviews/{review_id}", response_model=SuccessResponse)
async def delete_review(
    review_id: str,
    current_user: User = Depends(get_current_user),
    service: ReviewService = Depends(get_review_service),
):
    service.delete_review(review_id, current_user)
    return SuccessResponse(
        status="success", message="Avis supprimé avec succès", data={"review_id": review_id}
    )
