"""
Search Router - Morchid Hub
Recherche avancée de guides avec filtres, jointures SQL et pagination.
"""

from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_, func
from typing import List, Optional
from sqlalchemy.dialects.postgresql import JSONB # Add this import at the top

from .database import get_db
from .models import User, Guide, GuideRoute
from .schemas import SearchGuideResponse, SearchRouteResponse, ActiveRouteInfo

router = APIRouter(
    prefix="/api/v1/search",
    tags=["Recherche"]
)


# ============================================
# ENDPOINT 1 : RECHERCHE SIMPLE DE GUIDES
# GET /api/v1/search/guides
# ============================================

@router.get(
    "/guides",
    response_model=List[SearchGuideResponse],
    summary="Recherche avancée de guides",
    description="""
Recherche des guides approuvés avec de multiples filtres combinables.

**Filtres disponibles :**
- `q` : Recherche textuelle dans le nom et la bio
- `city` : Ville couverte par le guide
- `specialty` : Spécialité (nature, culture, aventure, gastronomie, histoire)
- `language` : Langue parlée
- `min_experience` : Années d'expérience minimum
- `min_rating` : Note moyenne minimum (0.0 - 5.0)
- `min_eco_score` : Score écologique minimum (0 - 100)
- `verified_only` : Guides vérifiés uniquement
- `limit` / `offset` : Pagination

**Tri :** Par note décroissante, puis par expérience décroissante.
"""
)
async def search_guides(
    # ─── Filtres textuels ──────────────────────────────────────────────────
    q: Optional[str] = Query(
        None,
        description="Recherche textuelle dans le nom et la bio du guide",
        min_length=2,
        max_length=100
    ),

    # ─── Filtres géographiques / professionnels ────────────────────────────
    city: Optional[str] = Query(
        None, description="Filtrer par ville couverte (ex: Marrakech)"
    ),
    specialty: Optional[str] = Query(
        None, description="Filtrer par spécialité (nature|culture|aventure|gastronomie|histoire)"
    ),
    language: Optional[str] = Query(
        None, description="Filtrer par langue parlée (ex: Français)"
    ),
    min_experience: Optional[int] = Query(
        None, ge=0, le=50, description="Années d'expérience minimum"
    ),

    # ─── ✅ NOUVEAUX filtres de qualité ────────────────────────────────────
    min_rating: Optional[float] = Query(
        None, ge=0.0, le=5.0, description="Note moyenne minimum (ex: 4.0)"
    ),
    min_eco_score: Optional[int] = Query(
        None, ge=0, le=100, description="Score écologique minimum (ex: 50)"
    ),

    # ─── Filtre vérification ───────────────────────────────────────────────
    verified_only: bool = Query(
        False, description="Retourner uniquement les guides officiellement vérifiés"
    ),

    # ─── ✅ Pagination ─────────────────────────────────────────────────────
    limit: int = Query(
        20, ge=1, le=100,
        description="Nombre maximum de résultats par page (défaut: 20, max: 100)"
    ),
    offset: int = Query(
        0, ge=0,
        description="Nombre de résultats à ignorer pour la pagination (défaut: 0)"
    ),

    db: Session = Depends(get_db)
):
    """
    Recherche avancée de guides touristiques.

    Utilise une jointure INNER JOIN entre User et Guide.
    Filtre uniquement les guides avec approval_status = 'approved'.
    """
    # ── Base query : JOIN User ↔ Guide ────────────────────────────────────
    query = (
        db.query(User, Guide)
        .join(Guide, User.id == Guide.user_id)
        .filter(User.role == "guide")
        .filter(Guide.is_verified == True)
        .filter(User.is_active == True)
    )

    # ── Filtre : guides vérifiés uniquement ───────────────────────────────
    if verified_only:
        query = query.filter(Guide.is_verified == True)

    # ── Filtre : expérience minimum ───────────────────────────────────────
    if min_experience is not None:
        query = query.filter(Guide.years_of_experience >= min_experience)

    # ── Filtre : note minimum ─────────────────────────────────────────────
    if min_rating is not None:
        query = query.filter(Guide.average_rating >= min_rating)

    # ── Filtre : score écologique minimum ─────────────────────────────────
    if min_eco_score is not None:
        query = query.filter(Guide.eco_score >= min_eco_score)

    # ── Filtre JSON : ville ───────────────────────────────────────────────
    if city:
        # PostgreSQL JSON contains : cherche si le tableau JSON contient la ville
        query = query.filter(Guide.cities_covered.cast(JSONB).contains([city]))
    # ── Filtre JSON : spécialité ──────────────────────────────────────────
    if specialty:
        query = query.filter(Guide.specialties.cast(JSONB).contains([specialty]))
    # ── Filtre JSON : langue ──────────────────────────────────────────────
    if language:
        query = query.filter(Guide.languages.cast(JSONB).contains([language]))
    # ── Filtre texte : nom ou bio ─────────────────────────────────────────
    if q:
        search_term = f"%{q}%"
        query = query.filter(
            or_(
                User.full_name.ilike(search_term),
                Guide.bio.ilike(search_term)
            )
        )

    # ── Tri : meilleure note d'abord, puis expérience ─────────────────────
    query = query.order_by(
        Guide.average_rating.desc(),
        Guide.years_of_experience.desc()
    )

    # ── Pagination ────────────────────────────────────────────────────────
    results = query.offset(offset).limit(limit).all()

    # ── Mapper vers SearchGuideResponse ───────────────────────────────────
    return [
        SearchGuideResponse(user=user, guide=guide)
        for user, guide in results
    ]


# ============================================
# ENDPOINT 2 : RECHERCHE GUIDES AVEC TRAJETS
# GET /api/v1/search/guides-with-routes
# ============================================

@router.get(
    "/guides-with-routes",
    response_model=List[SearchRouteResponse],
    summary="Recherche guides avec leur trajet actif",
    description="""
Recherche des guides approuvés ET inclut les détails de leur trajet actif.

**Différence avec /search/guides :**  
Ici, une jointure supplémentaire avec la table `guide_routes` permet de :
- Filtrer par adresse de départ ou d'arrivée du trajet (`route_query`)
- Voir directement la distance, durée et adresses du parcours dans les résultats
- Retourner uniquement les guides **qui ont un trajet actif** (sauf si `include_without_route=true`)

**Cas d'usage :** Afficher sur la carte les guides disponibles avec leur parcours.
"""
)
async def search_guides_with_routes(
    # ─── Filtres classiques (identiques à /search/guides) ─────────────────
    q: Optional[str] = Query(
        None,
        description="Recherche textuelle dans le nom, la bio du guide",
        min_length=2,
        max_length=100
    ),
    city: Optional[str] = Query(None, description="Ville couverte"),
    specialty: Optional[str] = Query(None, description="Spécialité"),
    language: Optional[str] = Query(None, description="Langue parlée"),
    min_experience: Optional[int] = Query(None, ge=0, le=50),
    min_rating: Optional[float] = Query(None, ge=0.0, le=5.0),
    min_eco_score: Optional[int] = Query(None, ge=0, le=100),
    verified_only: bool = Query(False),

    # ─── ✅ Filtre spécifique aux trajets ──────────────────────────────────
    route_query: Optional[str] = Query(
        None,
        description="Recherche dans les adresses de départ/arrivée du trajet (ex: 'Jemaa el-Fna')",
        min_length=2,
        max_length=200
    ),

    # ─── Option : inclure les guides sans trajet ───────────────────────────
    include_without_route: bool = Query(
        False,
        description="Si True, inclut les guides sans trajet actif (active_route sera null)"
    ),

    # ─── Pagination ────────────────────────────────────────────────────────
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),

    db: Session = Depends(get_db)
):
    """
    Recherche guides avec jointure sur GuideRoute.

    Architecture des jointures :
    
        User INNER JOIN Guide ON users.id = guides.user_id
             LEFT JOIN  GuideRoute ON guides.id = guide_routes.guide_id
                                  AND guide_routes.is_active = True

    LEFT JOIN utilisé pour pouvoir inclure optionnellement les guides sans trajet.
    Si include_without_route=False, on filtre WHERE guide_routes.id IS NOT NULL.
    """
    # ── Base query : JOIN User ↔ Guide ↔ GuideRoute (LEFT JOIN) ───────────
    query = (
        db.query(User, Guide, GuideRoute)
        .join(Guide, User.id == Guide.user_id)
        .outerjoin(
            GuideRoute,
            and_(
                GuideRoute.guide_id == Guide.id,
                GuideRoute.is_active == True    # Seulement le trajet actif
            )
        )
        .filter(User.role == "guide")
        .filter(Guide.approval_status == "approved")
        .filter(User.is_active == True)
    )

    # ── Option : exclure les guides sans trajet ───────────────────────────
    if not include_without_route:
        # Transforme le LEFT JOIN en INNER JOIN de facto
        query = query.filter(GuideRoute.id.isnot(None))

    # ── Filtre : adresse du trajet ────────────────────────────────────────
    # Recherche dans start_address ET end_address de GuideRoute
    if route_query:
        route_term = f"%{route_query}%"
        query = query.filter(
            or_(
                GuideRoute.start_address.ilike(route_term),
                GuideRoute.end_address.ilike(route_term)
            )
        )

    # ── Filtres identiques à /search/guides ───────────────────────────────
    if verified_only:
        query = query.filter(Guide.is_verified == True)

    if min_experience is not None:
        query = query.filter(Guide.years_of_experience >= min_experience)

    if min_rating is not None:
        query = query.filter(Guide.average_rating >= min_rating)

    if min_eco_score is not None:
        query = query.filter(Guide.eco_score >= min_eco_score)

    if city:
        query = query.filter(Guide.cities_covered.contains([city]))

    if specialty:
        query = query.filter(Guide.specialties.contains([specialty]))

    if language:
        query = query.filter(Guide.languages.contains([language]))

    if q:
        search_term = f"%{q}%"
        query = query.filter(
            or_(
                User.full_name.ilike(search_term),
                Guide.bio.ilike(search_term)
            )
        )

    # ── Tri ───────────────────────────────────────────────────────────────
    query = query.order_by(
        Guide.average_rating.desc(),
        Guide.years_of_experience.desc()
    )

    # ── Pagination ────────────────────────────────────────────────────────
    results = query.offset(offset).limit(limit).all()

    # ── Mapper vers SearchRouteResponse ───────────────────────────────────
    response_list = []
    for user, guide, route in results:

        # Construire ActiveRouteInfo seulement si un trajet existe
        active_route_info = None
        if route is not None:
            active_route_info = ActiveRouteInfo(
                route_id=route.id,
                distance=route.distance,
                duration=route.duration,
                start_address=route.start_address,
                end_address=route.end_address,
                # Compte le nombre de points GPS dans le JSON coordinates
                coordinates_count=len(route.coordinates) if route.coordinates else 0
            )

        response_list.append(
            SearchRouteResponse(
                # Identité
                user_id=user.id,
                guide_id=guide.id,
                full_name=user.full_name or "",
                profile_photo_url=guide.profile_photo_url,
                # Informations professionnelles
                languages=guide.languages or [],
                specialties=guide.specialties or [],
                cities_covered=guide.cities_covered or [],
                years_of_experience=guide.years_of_experience,
                bio=guide.bio or "",
                is_verified=guide.is_verified,
                # Scores
                eco_score=guide.eco_score,
                average_rating=guide.average_rating or 0.0,
                total_reviews=guide.total_reviews or 0,
                # Trajet actif
                active_route=active_route_info
            )
        )

    return response_list


# ============================================
# ENDPOINT 3 : VALEURS DISPONIBLES POUR LES FILTRES
# GET /api/v1/search/filters
# ============================================

@router.get(
    "/filters",
    summary="Récupère les valeurs disponibles pour les filtres de recherche",
    description="Retourne les listes dynamiques de villes, spécialités et langues disponibles."
)
async def get_available_filters(db: Session = Depends(get_db)):
    """
    Retourne les valeurs réellement disponibles dans la base de données
    pour peupler les menus déroulants du formulaire de recherche Flutter.
    """
    # Récupérer tous les guides approuvés
    guides = (
        db.query(Guide)
        .filter(Guide.approval_status == "approved")
        .all()
    )

    # Agréger les valeurs uniques
    cities: set = set()
    specialties: set = set()
    languages: set = set()

    for guide in guides:
        if guide.cities_covered:
            cities.update(guide.cities_covered)
        if guide.specialties:
            specialties.update(guide.specialties)
        if guide.languages:
            languages.update(guide.languages)

    return {
        "cities": sorted(list(cities)),
        "specialties": sorted(list(specialties)),
        "languages": sorted(list(languages)),
        "total_guides": len(guides)
    }