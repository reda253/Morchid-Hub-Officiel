"""Fabriques d'entités pour les tests d'intégration.

Insèrent directement des objets ORM (en contournant Pydantic) dans la session de
test, avec des valeurs par défaut sensées mais surchargeables via kwargs.
"""

import uuid

from sqlalchemy.orm import Session

from datetime import datetime, timedelta

from app.auth import create_access_token, hash_password
from app.models import Guide, GuideRoute, Review, Subscription, SupportMessage, User
from app.repositories.route_repository import RouteRepository
from app.schemas import GuideRouteCreate


def _uid() -> str:
    return str(uuid.uuid4())


def make_user(
    db: Session,
    *,
    role: str = "tourist",
    password: str = "test1234",
    is_admin: bool = False,
    is_active: bool = True,
    is_email_verified: bool = True,
    full_name: str | None = None,
    email: str | None = None,
    phone: str | None = None,
) -> User:
    suffix = _uid()[:8]
    # Téléphone marocain valide et unique (dérivé de l'uuid, chiffres uniquement).
    digits = f"{int(suffix, 16) % 100000000:08d}"
    user = User(
        full_name=full_name or f"User {suffix}",
        email=email or f"user_{suffix}@example.com",
        phone=phone or f"06{digits}",
        date_of_birth="1990-01-01",
        password_hash=hash_password(password),
        role=role,
        is_admin=is_admin,
        is_active=is_active,
        is_email_verified=is_email_verified,
    )
    db.add(user)
    db.flush()
    return user


def make_guide(
    db: Session,
    *,
    user: User | None = None,
    approval_status: str = "approved",
    is_verified: bool = True,
    has_official_license: bool = False,
    languages=None,
    specialties=None,
    cities_covered=None,
    years_of_experience: int = 5,
    bio: str = "Guide expérimenté passionné par le patrimoine marocain et la nature.",
    is_premium: bool = False,
    premium_until=None,
    average_rating: float = 0.0,
    total_reviews: int = 0,
    eco_score: int = 0,
) -> Guide:
    if user is None:
        user = make_user(db, role="guide")
    guide = Guide(
        user_id=user.id,
        languages=languages or ["Français", "Arabe"],
        specialties=specialties or ["culture", "nature"],
        cities_covered=cities_covered or ["Marrakech"],
        years_of_experience=years_of_experience,
        bio=bio,
        is_verified=is_verified,
        has_official_license=has_official_license,
        eco_score=eco_score,
        average_rating=average_rating,
        total_reviews=total_reviews,
        is_premium=is_premium,
        premium_until=premium_until,
        approval_status=approval_status,
    )
    db.add(guide)
    db.flush()
    return guide


def _route_payload(**overrides) -> GuideRouteCreate:
    data = dict(
        coordinates=[{"lat": 31.62, "lng": -7.98}, {"lat": 31.63, "lng": -7.99}],
        start_point={"lat": 31.62, "lng": -7.98},
        end_point={"lat": 31.63, "lng": -7.99},
        distance=2.5,
        duration=30.0,
        start_address="Place Jemaa el-Fna",
        end_address="Jardin Majorelle",
        description=None,
        checkpoints=[],
        price=None,
    )
    data.update(overrides)
    return GuideRouteCreate(**data)


def make_route(
    db: Session,
    *,
    guide: Guide,
    is_active: bool = True,
    **overrides,
) -> GuideRoute:
    route = RouteRepository.build_route(guide.id, _route_payload(**overrides))
    route.is_active = is_active
    db.add(route)
    db.flush()
    return route


def make_review(
    db: Session,
    *,
    guide: Guide,
    tourist: User,
    rating: int = 5,
    comment: str = "Excellent guide.",
    route_id: str | None = None,
) -> Review:
    review = Review(
        guide_id=guide.id,
        tourist_id=tourist.id,
        route_id=route_id,
        rating=rating,
        comment=comment,
    )
    db.add(review)
    db.flush()
    return review


def make_support_message(
    db: Session,
    *,
    user: User,
    subject: str = "Problème de connexion",
    message: str = "Je n'arrive pas à me connecter à mon compte.",
    is_resolved: bool = False,
) -> SupportMessage:
    msg = SupportMessage(
        user_id=user.id,
        subject=subject,
        message=message,
        is_resolved=is_resolved,
    )
    db.add(msg)
    db.flush()
    return msg


def make_subscription(
    db: Session,
    *,
    guide: Guide,
    tier: str = "pro",
    amount: float = 399.0,
    status: str = "active",
    started_at: datetime | None = None,
    duration_days: int = 30,
) -> Subscription:
    started = started_at or datetime.now()
    sub = Subscription(
        guide_id=guide.id,
        tier=tier,
        amount=amount,
        currency="MAD",
        status=status,
        started_at=started,
        expires_at=started + timedelta(days=duration_days),
    )
    db.add(sub)
    db.flush()
    return sub


def auth_headers(user: User) -> dict:
    """En-tête Authorization Bearer pour un utilisateur donné."""
    token = create_access_token(
        {
            "sub": user.id,
            "email": user.email,
            "role": user.role,
            "tv": user.token_version or 0,
        }
    )
    return {"Authorization": f"Bearer {token}"}
