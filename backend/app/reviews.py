"""
Reviews Router — Morchid Hub
=============================
Gestion complète des avis des touristes sur les guides et leurs trajets.

Endpoints exposés :
  POST   /api/v1/reviews                       Créer un avis (touriste connecté)
  GET    /api/v1/guides/{guide_id}/reviews     Lister les avis d'un guide (public)
  DELETE /api/v1/reviews/{review_id}           Supprimer son avis (auteur ou admin)
"""

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func as sqlfunc
from sqlalchemy.orm import Session
from typing import List

from .database import get_db
from .models import Guide, GuideRoute, Review, User
from .schemas import (
    ReviewCreate,
    ReviewListResponse,
    ReviewResponse,
    SuccessResponse,
)
from .auth import get_current_user

router = APIRouter(prefix="/api/v1", tags=["Avis (Reviews)"])


# ─────────────────────────────────────────────────────────────────────────────
# Fonction utilitaire interne
# ─────────────────────────────────────────────────────────────────────────────

def _recalculate_guide_rating(guide: Guide, db: Session) -> None:
    """
    Recalcule average_rating et total_reviews du guide à partir de la BDD.

    Utilise une agrégation SQL (COUNT + AVG) pour être précis même en cas
    de requêtes concurrentes.  Arrondi à 1 décimale via round() Python.

    Exemples :
      notes [5, 4, 4, 5, 4] → avg = 4.4  → average_rating = 4.4
      notes [5, 3]           → avg = 4.0  → average_rating = 4.0
      notes [5]              → avg = 5.0  → average_rating = 5.0
      aucune note            →             → average_rating = 0.0
    """
    row = (
        db.query(
            sqlfunc.count(Review.id).label("cnt"),
            sqlfunc.avg(Review.rating).label("avg"),
        )
        .filter(Review.guide_id == guide.id)
        .one()
    )
    guide.total_reviews  = row.cnt or 0
    guide.average_rating = round(float(row.avg), 1) if row.avg else 0.0


# ─────────────────────────────────────────────────────────────────────────────
# POST /api/v1/reviews
# ─────────────────────────────────────────────────────────────────────────────

@router.post(
    "/reviews",
    response_model=ReviewResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Poster un avis sur un guide",
    description="""
Permet à un **touriste connecté** de laisser un avis noté de 1 à 5 sur un guide.

**Règles métier appliquées :**
1. Seuls les utilisateurs avec `role = "tourist"` peuvent poster (403 sinon)
2. Le guide doit exister et avoir le statut `approved` (404 sinon)
3. Un touriste ne peut noter qu'un seul guide **une seule fois** (409 si doublon)
4. Le `route_id` est optionnel : l'avis peut porter sur le guide seul ou
   sur un trajet précis appartenant à ce guide (404 si trajet inconnu)
5. Après l'INSERT, `average_rating` et `total_reviews` du guide sont
   **recalculés automatiquement** via une agrégation SQL (précision 1 décimale)
""",
)
async def create_review(
    review_data: ReviewCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ── 1. Seuls les touristes peuvent noter ──────────────────────────────
    if current_user.role != "tourist":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "FORBIDDEN_ROLE",
                "message": "Seuls les touristes peuvent laisser un avis",
            },
        )

    # ── 2. Le guide doit exister et être approuvé ─────────────────────────
    guide = (
        db.query(Guide)
        .filter(
            Guide.id == review_data.guide_id,
            Guide.is_verified == True,
        )
        .first()
    )
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_NOT_FOUND",
                "message": "Guide introuvable ou non approuvé",
            },
        )

    # ── 3. Interdiction de s'auto-noter ───────────────────────────────────
    if guide.user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "SELF_REVIEW",
                "message": "Vous ne pouvez pas vous noter vous-même",
            },
        )

    # ── 4. Un seul avis par touriste par guide ────────────────────────────
    existing = (
        db.query(Review)
        .filter(
            Review.guide_id   == review_data.guide_id,
            Review.tourist_id == current_user.id,
        )
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "error_code": "REVIEW_ALREADY_EXISTS",
                "message": "Vous avez déjà laissé un avis pour ce guide",
            },
        )

    # ── 5. Valider le route_id si fourni ──────────────────────────────────
    if review_data.route_id:
        route = (
            db.query(GuideRoute)
            .filter(
                GuideRoute.id       == review_data.route_id,
                GuideRoute.guide_id == review_data.guide_id,  # appartient bien à ce guide
            )
            .first()
        )
        if not route:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={
                    "error_code": "ROUTE_NOT_FOUND",
                    "message": "Trajet introuvable ou n'appartenant pas à ce guide",
                },
            )

    # ── 6. Créer l'avis ───────────────────────────────────────────────────
    new_review = Review(
        guide_id   = review_data.guide_id,
        tourist_id = current_user.id,
        route_id   = review_data.route_id,
        rating     = review_data.rating,
        comment    = review_data.comment,
    )
    db.add(new_review)
    db.flush()   # obtenir l'id sans encore committer

    # ── 7. Recalculer les stats du guide ──────────────────────────────────
    _recalculate_guide_rating(guide, db)

    # ── 8. Commit + retour ────────────────────────────────────────────────
    db.commit()
    db.refresh(new_review)

    return ReviewResponse(
        id           = new_review.id,
        guide_id     = new_review.guide_id,
        tourist_id   = new_review.tourist_id,
        tourist_name = current_user.full_name or "Touriste anonyme",
        route_id     = new_review.route_id,
        rating       = new_review.rating,
        comment      = new_review.comment,
        created_at   = new_review.created_at,
    )


# ─────────────────────────────────────────────────────────────────────────────
# GET /api/v1/guides/{guide_id}/reviews
# ─────────────────────────────────────────────────────────────────────────────

@router.get(
    "/guides/{guide_id}/reviews",
    response_model=ReviewListResponse,
    summary="Lister les avis d'un guide",
    description="""
**Endpoint public** — aucun token requis.

Retourne la liste paginée des avis pour un guide donné, du plus récent au plus ancien.

La réponse inclut toujours :
- `average_rating` : note moyenne actuelle (arrondie à 1 décimale)
- `total_reviews`  : nombre total d'avis enregistrés
- `reviews`        : tableau paginé des avis avec nom du touriste
""",
)
async def list_guide_reviews(
    guide_id: str,
    limit:  int = Query(20, ge=1, le=100, description="Nombre d'avis par page (défaut 20)"),
    offset: int = Query(0,  ge=0,         description="Décalage pagination (défaut 0)"),
    db: Session = Depends(get_db),
):
    # ── 1. Vérifier que le guide existe ───────────────────────────────────
    guide = db.query(Guide).filter(Guide.id == guide_id).first()
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error_code": "GUIDE_NOT_FOUND", "message": "Guide introuvable"},
        )

    # ── 2. Récupérer les avis + nom du touriste (une seule requête SQL) ────
    #
    # Jointure :  Review  INNER JOIN  User  ON reviews.tourist_id = users.id
    # Tri        : created_at DESC  (plus récent en premier)
    #
    rows = (
        db.query(Review, User)
        .join(User, Review.tourist_id == User.id)
        .filter(Review.guide_id == guide_id)
        .order_by(Review.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )

    # ── 3. Mapper en ReviewResponse ───────────────────────────────────────
    review_list = [
        ReviewResponse(
            id           = review.id,
            guide_id     = review.guide_id,
            tourist_id   = review.tourist_id,
            tourist_name = tourist.full_name or "Touriste anonyme",
            route_id     = review.route_id,
            rating       = review.rating,
            comment      = review.comment,
            created_at   = review.created_at,
        )
        for review, tourist in rows
    ]

    # ── 4. Retourner avec les stats actuelles du guide ────────────────────
    return ReviewListResponse(
        guide_id       = guide_id,
        average_rating = guide.average_rating,
        total_reviews  = guide.total_reviews,
        reviews        = review_list,
    )


# ─────────────────────────────────────────────────────────────────────────────
# DELETE /api/v1/reviews/{review_id}
# ─────────────────────────────────────────────────────────────────────────────

@router.delete(
    "/reviews/{review_id}",
    response_model=SuccessResponse,
    summary="Supprimer son avis",
    description="""
Permet à un touriste de supprimer son propre avis.
Un administrateur peut supprimer n'importe quel avis.

Après suppression, `average_rating` et `total_reviews` du guide sont
**recalculés automatiquement**.
""",
)
async def delete_review(
    review_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    # ── 1. L'avis doit exister ────────────────────────────────────────────
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error_code": "REVIEW_NOT_FOUND", "message": "Avis introuvable"},
        )

    # ── 2. Seul l'auteur ou un admin peut supprimer ───────────────────────
    if review.tourist_id != current_user.id and not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "FORBIDDEN",
                "message": "Vous ne pouvez supprimer que vos propres avis",
            },
        )

    guide_id = review.guide_id

    # ── 3. Supprimer l'avis ───────────────────────────────────────────────
    db.delete(review)
    db.flush()

    # ── 4. Recalculer les stats du guide après suppression ────────────────
    guide = db.query(Guide).filter(Guide.id == guide_id).first()
    if guide:
        _recalculate_guide_rating(guide, db)

    db.commit()

    return SuccessResponse(
        status  = "success",
        message = "Avis supprimé avec succès",
        data    = {"review_id": review_id},
    )