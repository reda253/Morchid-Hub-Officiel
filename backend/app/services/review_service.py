"""Service des avis : création (règles métier), listing, suppression + recalcul des stats."""

from typing import List, Tuple

from sqlalchemy.orm import Session

from ..exceptions import BadRequestError, ConflictError, ForbiddenError, NotFoundError
from ..models import Guide, Review, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.review_repository import ReviewRepository
from ..repositories.route_repository import RouteRepository
from ..schemas import ReviewCreate


class ReviewService:
    def __init__(self, db: Session):
        self.db = db
        self.guides = GuideRepository(db)
        self.routes = RouteRepository(db)
        self.reviews = ReviewRepository(db)

    def create_review(self, current_user: User, data: ReviewCreate) -> Tuple[Review, str]:
        if current_user.role != "tourist":
            raise ForbiddenError("FORBIDDEN_ROLE", "Seuls les touristes peuvent laisser un avis")

        guide = self.guides.get_verified(data.guide_id)
        if not guide:
            raise NotFoundError("GUIDE_NOT_FOUND", "Guide introuvable ou non approuvé")

        if guide.user_id == current_user.id:
            raise BadRequestError("SELF_REVIEW", "Vous ne pouvez pas vous noter vous-même")

        if self.reviews.get_by_guide_and_tourist(data.guide_id, current_user.id):
            raise ConflictError(
                "REVIEW_ALREADY_EXISTS", "Vous avez déjà laissé un avis pour ce guide"
            )

        if data.route_id:
            route = self.routes.get_by_id_and_guide(data.route_id, data.guide_id)
            if not route:
                raise NotFoundError(
                    "ROUTE_NOT_FOUND", "Trajet introuvable ou n'appartenant pas à ce guide"
                )

        review = Review(
            guide_id=data.guide_id,
            tourist_id=current_user.id,
            route_id=data.route_id,
            rating=data.rating,
            comment=data.comment,
        )
        self.reviews.add(review)
        self.db.flush()

        self._refresh_rating(guide)

        self.db.commit()
        self.db.refresh(review)

        return review, (current_user.full_name or "Touriste anonyme")

    def list_reviews(self, guide_id: str, limit: int, offset: int) -> Tuple[Guide, List[Tuple[Review, User]]]:
        guide = self.guides.get_by_id(guide_id)
        if not guide:
            raise NotFoundError("GUIDE_NOT_FOUND", "Guide introuvable")
        rows = self.reviews.list_with_tourist(guide_id, limit, offset)
        return guide, rows

    def delete_review(self, review_id: str, current_user: User) -> None:
        review = self.reviews.get_by_id(review_id)
        if not review:
            raise NotFoundError("REVIEW_NOT_FOUND", "Avis introuvable")

        if review.tourist_id != current_user.id and not current_user.is_admin:
            raise ForbiddenError("FORBIDDEN", "Vous ne pouvez supprimer que vos propres avis")

        guide_id = review.guide_id
        self.reviews.delete(review)
        self.db.flush()

        guide = self.guides.get_by_id(guide_id)
        if guide:
            self._refresh_rating(guide)

        self.db.commit()

    def _refresh_rating(self, guide: Guide) -> None:
        """Recalcule total_reviews et average_rating (arrondi 1 décimale) du guide."""
        count, avg = self.reviews.rating_aggregates(guide.id)
        guide.total_reviews = count
        guide.average_rating = round(float(avg), 1) if avg else 0.0
