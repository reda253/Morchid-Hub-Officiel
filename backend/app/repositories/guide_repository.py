"""Accès aux données de la table `guides`, incluant la recherche filtrée.

Le bloc de filtres commun (ville, spécialité, langue, expérience, note, éco-score,
texte libre) est factorisé dans `_apply_common_filters` et réutilisé par les deux
requêtes de recherche — supprimant la duplication qui existait entre les deux
endpoints de l'ancien `search.py`.
"""

from typing import List, Optional, Tuple

from sqlalchemy import and_, or_
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import joinedload

from ..models import Guide, GuideRoute, User
from .base import BaseRepository


class GuideRepository(BaseRepository):

    # ── Lectures unitaires ────────────────────────────────────────────────
    def get_by_id(self, guide_id: str) -> Optional[Guide]:
        return self.db.query(Guide).filter(Guide.id == guide_id).first()

    def get_by_user_id(self, user_id: str) -> Optional[Guide]:
        return self.db.query(Guide).filter(Guide.user_id == user_id).first()

    def get_owned(self, guide_id: str, user_id: str) -> Optional[Guide]:
        """Guide dont l'id ET le propriétaire (user_id) correspondent."""
        return (
            self.db.query(Guide)
            .filter(Guide.id == guide_id, Guide.user_id == user_id)
            .first()
        )

    def get_verified(self, guide_id: str) -> Optional[Guide]:
        """Guide vérifié (utilisé pour l'éligibilité aux avis)."""
        return (
            self.db.query(Guide)
            .filter(Guide.id == guide_id, Guide.is_verified == True)
            .first()
        )

    def add(self, guide: Guide) -> None:
        self.db.add(guide)

    # ── Listes ────────────────────────────────────────────────────────────
    def list_paginated(self, skip: int = 0, limit: int = 20) -> List[Guide]:
        """Guides visibles publiquement : approuvés uniquement.

        Le filtre `approval_status` n'est pas cosmétique — sans lui, l'endpoint
        public /api/v1/guides listait aussi les guides en attente et rejetés.
        `joinedload` évite un N+1 : l'appelant lit `guide.user.full_name`.
        """
        return (
            self.db.query(Guide)
            .options(joinedload(Guide.user))
            .filter(Guide.approval_status == "approved")
            .offset(skip)
            .limit(limit)
            .all()
        )

    def list_pending(self) -> List[Guide]:
        return self.list_by_status("pending")

    def list_by_status(self, approval_status: str) -> List[Guide]:
        return (
            self.db.query(Guide)
            .filter(Guide.approval_status == approval_status)
            .order_by(Guide.created_at.desc())
            .all()
        )

    def list_approved(self) -> List[Guide]:
        return self.db.query(Guide).filter(Guide.approval_status == "approved").all()

    # ── Statistiques (admin) ──────────────────────────────────────────────
    def count(self) -> int:
        return self.db.query(Guide).count()

    def count_by_status(self, approval_status: str) -> int:
        return self.db.query(Guide).filter(Guide.approval_status == approval_status).count()

    # ── Recherche ─────────────────────────────────────────────────────────
    @staticmethod
    def _apply_common_filters(
        query,
        *,
        verified_only: bool,
        min_experience: Optional[int],
        min_rating: Optional[float],
        min_eco_score: Optional[int],
        city: Optional[str],
        specialty: Optional[str],
        language: Optional[str],
        q: Optional[str],
    ):
        if verified_only:
            query = query.filter(Guide.is_verified == True)
        if min_experience is not None:
            query = query.filter(Guide.years_of_experience >= min_experience)
        if min_rating is not None:
            query = query.filter(Guide.average_rating >= min_rating)
        if min_eco_score is not None:
            query = query.filter(Guide.eco_score >= min_eco_score)
        if city:
            query = query.filter(Guide.cities_covered.cast(JSONB).contains([city]))
        if specialty:
            query = query.filter(Guide.specialties.cast(JSONB).contains([specialty]))
        if language:
            query = query.filter(Guide.languages.cast(JSONB).contains([language]))
        if q:
            term = f"%{q}%"
            query = query.filter(or_(User.full_name.ilike(term), Guide.bio.ilike(term)))
        return query

    def search_guides(
        self,
        *,
        q: Optional[str] = None,
        city: Optional[str] = None,
        specialty: Optional[str] = None,
        language: Optional[str] = None,
        min_experience: Optional[int] = None,
        min_rating: Optional[float] = None,
        min_eco_score: Optional[int] = None,
        verified_only: bool = False,
        limit: int = 20,
        offset: int = 0,
    ) -> List[Tuple[User, Guide]]:
        query = (
            self.db.query(User, Guide)
            .join(Guide, User.id == Guide.user_id)
            .filter(User.role == "guide")
            .filter(Guide.approval_status == "approved")
            .filter(User.is_active == True)
        )
        query = self._apply_common_filters(
            query,
            verified_only=verified_only,
            min_experience=min_experience,
            min_rating=min_rating,
            min_eco_score=min_eco_score,
            city=city,
            specialty=specialty,
            language=language,
            q=q,
        )
        query = query.order_by(
            Guide.average_rating.desc(),
            Guide.years_of_experience.desc(),
        )
        return query.offset(offset).limit(limit).all()

    def search_guides_with_routes(
        self,
        *,
        q: Optional[str] = None,
        city: Optional[str] = None,
        specialty: Optional[str] = None,
        language: Optional[str] = None,
        min_experience: Optional[int] = None,
        min_rating: Optional[float] = None,
        min_eco_score: Optional[int] = None,
        verified_only: bool = False,
        route_query: Optional[str] = None,
        include_without_route: bool = False,
        limit: int = 20,
        offset: int = 0,
    ) -> List[Tuple[User, Guide, Optional[GuideRoute]]]:
        query = (
            self.db.query(User, Guide, GuideRoute)
            .join(Guide, User.id == Guide.user_id)
            .outerjoin(
                GuideRoute,
                and_(
                    GuideRoute.guide_id == Guide.id,
                    GuideRoute.is_active == True,
                ),
            )
            .filter(User.role == "guide")
            .filter(Guide.approval_status == "approved")
            .filter(User.is_active == True)
        )

        if not include_without_route:
            query = query.filter(GuideRoute.id.isnot(None))

        if route_query:
            term = f"%{route_query}%"
            query = query.filter(
                or_(
                    GuideRoute.start_address.ilike(term),
                    GuideRoute.end_address.ilike(term),
                )
            )

        query = self._apply_common_filters(
            query,
            verified_only=verified_only,
            min_experience=min_experience,
            min_rating=min_rating,
            min_eco_score=min_eco_score,
            city=city,
            specialty=specialty,
            language=language,
            q=q,
        )
        query = query.order_by(
            Guide.average_rating.desc(),
            Guide.years_of_experience.desc(),
        )
        return query.offset(offset).limit(limit).all()
