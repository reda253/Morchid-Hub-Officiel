"""Service d'authentification et de gestion de compte.

Couvre : inscription, connexion, vérification d'email, renvoi de vérification,
mot de passe oublié / réinitialisation, et construction du profil utilisateur.
"""

from typing import Optional, Tuple

from sqlalchemy.orm import Session

from ..auth import create_access_token, hash_password, verify_password
from ..config import settings
from ..email_utils import (
    generate_reset_password_token,
    generate_verification_token,
    get_token_expiry,
    is_token_expired,
)
from ..exceptions import BadRequestError, ServerError, UnauthorizedError
from ..models import Guide, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.user_repository import UserRepository
from ..schemas import UserRegistration
from .notification_service import NotificationService


class AuthService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.guides = GuideRepository(db)
        self.notifier = NotificationService()

    # ── Inscription ───────────────────────────────────────────────────────
    def register(self, data: UserRegistration) -> Tuple[User, Optional[Guide], str]:
        if self.users.get_by_email(data.personal_info.email):
            raise BadRequestError("EMAIL_EXISTS", "Un compte avec cet email existe déjà")
        if self.users.get_by_phone(data.personal_info.phone):
            raise BadRequestError("PHONE_EXISTS", "Un compte avec ce numéro existe déjà")

        verification_token = generate_verification_token()
        new_user = User(
            full_name=data.personal_info.full_name,
            email=data.personal_info.email,
            phone=data.personal_info.phone,
            date_of_birth=data.personal_info.date_of_birth,
            password_hash=hash_password(data.password),
            role=data.role,
            is_active=True,
            is_admin=False,
            is_email_verified=False,
            verification_token=verification_token,
            token_expires_at=get_token_expiry(hours=24),
        )
        self.users.add(new_user)
        self.db.flush()  # obtenir l'id sans committer

        guide_profile: Optional[Guide] = None
        if data.role == "guide" and data.guide_details:
            guide_profile = Guide(
                user_id=new_user.id,
                languages=data.guide_details.languages,
                specialties=data.guide_details.specialties,
                cities_covered=data.guide_details.cities_covered,
                years_of_experience=data.guide_details.years_of_experience,
                bio=data.guide_details.bio,
                is_verified=False,
                eco_score=0,
                approval_status="pending",
            )
            self.guides.add(guide_profile)

        try:
            self.db.commit()
            self.db.refresh(new_user)
            if guide_profile:
                self.db.refresh(guide_profile)
        except Exception as e:
            self.db.rollback()
            raise ServerError("DATABASE_ERROR", "Erreur lors de l'enregistrement", str(e))

        self.notifier.send_verification_email(
            email=new_user.email, full_name=new_user.full_name, token=verification_token
        )

        message = (
            "Inscription réussie ! Vérifiez votre email pour activer votre compte."
            if data.role == "guide"
            else "Bienvenue sur Morchid Hub ! Vérifiez votre email pour activer votre compte."
        )
        return new_user, guide_profile, message

    # ── Connexion ─────────────────────────────────────────────────────────
    def login(self, email: str, password: str) -> Tuple[User, str]:
        user = self.users.get_by_email(email)
        if not user or not verify_password(password, user.password_hash):
            raise UnauthorizedError("INVALID_CREDENTIALS", "Email ou mot de passe incorrect")
        if not user.is_active:
            raise BadRequestError(
                "ACCOUNT_DISABLED",
                "Votre compte a été désactivé. Contactez le support.",
                status_code=403,
            )

        # Synchronisation de la colonne `is_admin` sur la liste blanche
        # `ADMIN_EMAILS`. Cette colonne n'est QU'UN CACHE destiné au client
        # Flutter (affichage ou non de l'UI admin) : elle n'autorise rien.
        # `require_admin` (app/api/deps.py) reste la seule autorité et ne lit
        # jamais cette colonne — ne pas « simplifier » la garde pour la relire.
        user.is_admin = (user.email or "").strip().lower() in settings.admin_emails_list
        self.db.commit()

        access_token = create_access_token(
            {"sub": user.id, "email": user.email, "role": user.role}
        )
        return user, access_token

    # ── Vérification d'email ──────────────────────────────────────────────
    def verify_email(self, token: str) -> User:
        user = self.users.get_by_verification_token(token)
        if not user:
            raise BadRequestError(
                "INVALID_TOKEN", "Token de vérification invalide ou déjà utilisé"
            )
        if is_token_expired(user.token_expires_at):
            raise BadRequestError(
                "TOKEN_EXPIRED",
                "Le token de vérification a expiré. Demandez un nouveau lien.",
            )
        user.is_email_verified = True
        user.verification_token = None
        user.token_expires_at = None
        self.db.commit()
        return user

    def verify_email_by_link(self, token: str) -> Optional[User]:
        """Variante lien navigateur : retourne None si le token est invalide (pas d'exception)."""
        user = self.users.get_by_verification_token(token)
        if not user:
            return None
        user.is_email_verified = True
        user.verification_token = None
        user.token_expires_at = None
        self.db.commit()
        return user

    def resend_verification(self, email: str) -> bool:
        """Retourne True si un nouveau lien a été envoyé, False si le compte est inconnu."""
        user = self.users.get_by_email(email)
        if not user:
            return False  # ne pas révéler l'existence du compte
        if user.is_email_verified:
            raise BadRequestError("ALREADY_VERIFIED", "Votre email est déjà vérifié")
        new_token = generate_verification_token()
        user.verification_token = new_token
        user.token_expires_at = get_token_expiry(hours=24)
        self.db.commit()
        self.notifier.send_verification_email(
            email=user.email, full_name=user.full_name, token=new_token
        )
        return True

    # ── Réinitialisation de mot de passe ──────────────────────────────────
    def forgot_password(self, email: str) -> bool:
        """Retourne True si un lien de reset a été envoyé, False si le compte est inconnu."""
        user = self.users.get_by_email(email)
        if not user:
            return False  # ne pas révéler l'existence du compte
        reset_token = generate_reset_password_token()
        user.reset_password_token = reset_token
        user.token_expires_at = get_token_expiry(hours=24)
        self.db.commit()
        self.notifier.send_password_reset_email(
            email=user.email, full_name=user.full_name, token=reset_token
        )
        return True

    def get_reset_target(self, token: str) -> Optional[User]:
        """Utilisateur associé à un token de reset (pour la page de saisie simulée)."""
        return self.users.get_by_reset_token(token)

    def reset_password(self, token: str, new_password: str) -> User:
        user = self.users.get_by_reset_token(token)
        if not user:
            raise BadRequestError(
                "INVALID_TOKEN", "Token de réinitialisation invalide ou déjà utilisé"
            )
        if is_token_expired(user.token_expires_at):
            raise BadRequestError(
                "TOKEN_EXPIRED",
                "Le token a expiré. Demandez un nouveau lien de réinitialisation.",
            )
        user.password_hash = hash_password(new_password)
        user.reset_password_token = None
        user.token_expires_at = None
        self.db.commit()
        self.notifier.send_password_changed_confirmation(
            email=user.email, full_name=user.full_name
        )
        return user

    # ── Profil ────────────────────────────────────────────────────────────
    def get_profile(self, current_user: User) -> Tuple[Optional[Guide], dict]:
        """Retourne (profil guide ou None, statistiques) pour l'utilisateur connecté."""
        if current_user.role == "guide":
            guide = self.guides.get_by_user_id(current_user.id)
            if guide:
                stats = {
                    "total_views": 0,
                    "upcoming_bookings": 0,
                    "completed_trips": 0,
                    "total_earnings": 0.0,
                    "average_rating": 0.0,
                    "profile_completion": self._profile_completion(current_user, guide),
                    "total_bookings": 0,
                    "total_revenue": 0,
                    "total_reviews": 0,
                }
                return guide, stats
            return None, None  # guide sans profil (cas limite conservé)

        stats = {
            "total_bookings": 0,
            "upcoming_trips": 0,
            "completed_trips": 0,
            "favorite_guides": 0,
            "total_spent": 0.0,
            "favorites": 0,
        }
        return None, stats

    @staticmethod
    def _profile_completion(user: User, guide: Optional[Guide]) -> int:
        user_fields = {
            "full_name": user.full_name,
            "email": user.email,
            "phone": user.phone,
            "date_of_birth": user.date_of_birth,
            "is_email_verified": user.is_email_verified,
        }
        total = len(user_fields)
        completed = sum(1 for v in user_fields.values() if v)

        if guide:
            guide_fields = {
                "languages": guide.languages and len(guide.languages) > 0,
                "specialties": guide.specialties and len(guide.specialties) > 0,
                "cities_covered": guide.cities_covered and len(guide.cities_covered) > 0,
                "bio": guide.bio and len(guide.bio) >= 50,
                "is_verified": guide.is_verified,
                "has_official_license": guide.has_official_license,
                "profile_photo_url": guide.profile_photo_url is not None,
                "license_card_url": guide.license_card_url is not None,
                "cine_card_url": guide.cine_card_url is not None,
            }
            total += len(guide_fields)
            completed += sum(1 for v in guide_fields.values() if v)

        return int((completed / total) * 100) if total > 0 else 0
