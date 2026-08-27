"""Accès aux données de la table `reviews`."""

from typing import List, Optional, Tuple

from sqlalchemy import func as sqlfunc

from ..models import Review, User
from .base import BaseRepository


class ReviewRepository(BaseRepository):

    def get_by_id(self, review_id: str) -> Optional[Review]:
        return self.db.query(Review).filter(Review.id == review_id).first()

    def get_by_guide_and_tourist(self, guide_id: str, tourist_id: str) -> Optional[Review]:
        return (
            self.db.query(Review)
            .filter(Review.guide_id == guide_id, Review.tourist_id == tourist_id)
            .first()
        )

    def add(self, review: Review) -> None:
        self.db.add(review)

    def delete(self, review: Review) -> None:
        self.db.delete(review)

    def list_with_tourist(self, guide_id: str, limit: int, offset: int) -> List[Tuple[Review, User]]:
        """Avis d'un guide joints à l'auteur, du plus récent au plus ancien."""
        return (
            self.db.query(Review, User)
            .join(User, Review.tourist_id == User.id)
            .filter(Review.guide_id == guide_id)
            .order_by(Review.created_at.desc())
            .offset(offset)
            .limit(limit)
            .all()
        )

    def rating_aggregates(self, guide_id: str) -> Tuple[int, Optional[float]]:
        """Retourne (nombre d'avis, note moyenne brute) pour un guide."""
        row = (
            self.db.query(
                sqlfunc.count(Review.id).label("cnt"),
                sqlfunc.avg(Review.rating).label("avg"),
            )
            .filter(Review.guide_id == guide_id)
            .one()
        )
        return row.cnt or 0, row.avg
