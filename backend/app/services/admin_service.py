"""Service d'administration : utilisateurs, approbation des guides, support, stats."""

from datetime import datetime
from typing import List, Optional, Tuple

from sqlalchemy.orm import Session

from ..exceptions import BadRequestError, NotFoundError
from ..models import Guide, SupportMessage, User
from ..repositories.guide_repository import GuideRepository
from ..repositories.support_repository import SupportRepository
from ..repositories.user_repository import UserRepository


class AdminService:
    def __init__(self, db: Session):
        self.db = db
        self.users = UserRepository(db)
        self.guides = GuideRepository(db)
        self.support = SupportRepository(db)

    # ── Utilisateurs ──────────────────────────────────────────────────────
    def list_users(self, role: Optional[str]) -> List[User]:
        return self.users.list_ordered(role)

    def toggle_user_status(self, user_id: str, admin: User) -> User:
        user = self.users.get_by_id(user_id)
        if not user:
            raise NotFoundError("USER_NOT_FOUND", "Utilisateur non trouvé")
        if user.id == admin.id:
            raise BadRequestError(
                "SELF_DEACTIVATION", "Vous ne pouvez pas désactiver votre propre compte"
            )
        user.is_active = not user.is_active
        if not user.is_active:
            # Sans cet incrément, `is_active=False` ne changerait qu'une colonne
            # que les sessions déjà ouvertes ne relisent jamais : le compte
            # resterait utilisable jusqu'à l'expiration naturelle du JWT.
            user.token_version = (user.token_version or 0) + 1
        self.db.commit()
        self.db.refresh(user)
        return user

    # ── Approbation des guides ────────────────────────────────────────────
    def list_pending_guides(self) -> List[Guide]:
        return self.guides.list_pending()

    def list_guides_by_status(self, status: str) -> List[Guide]:
        return self.guides.list_by_status(status)

    def approve_guide(self, guide_id: str) -> Guide:
        guide = self._get_pending_guide(guide_id)
        # RG15 (UML étape 12) : approbation possible uniquement depuis le
        # sous-état "DocumentsSoumis" — le guide doit avoir soumis ses documents.
        if not guide.has_official_license:
            raise BadRequestError(
                "NO_DOCUMENTS",
                "Le guide n'a pas encore soumis ses documents de vérification",
            )
        guide.approval_status = "approved"
        guide.is_verified = True
        guide.rejection_reason = None
        self.db.commit()
        self.db.refresh(guide)
        return guide

    def reject_guide(self, guide_id: str, reason: str) -> Guide:
        guide = self._get_pending_guide(guide_id)
        guide.approval_status = "rejected"
        guide.is_verified = False
        guide.rejection_reason = reason
        self.db.commit()
        self.db.refresh(guide)
        return guide

    def _get_pending_guide(self, guide_id: str) -> Guide:
        guide = self.guides.get_by_id(guide_id)
        if not guide:
            raise NotFoundError("GUIDE_NOT_FOUND", "Guide non trouvé")
        if guide.approval_status != "pending":
            raise BadRequestError("INVALID_STATUS", f"Ce guide est déjà {guide.approval_status}")
        return guide

    # ── Support ───────────────────────────────────────────────────────────
    def list_support_messages(
        self, resolved: Optional[bool]
    ) -> List[Tuple[SupportMessage, Optional[User]]]:
        return self.support.list_with_users(resolved)

    def resolve_support_message(self, message_id: str) -> SupportMessage:
        message = self.support.get_by_id(message_id)
        if not message:
            raise NotFoundError("MESSAGE_NOT_FOUND", "Message de support non trouvé")
        if message.is_resolved:
            raise BadRequestError("ALREADY_RESOLVED", "Ce message est déjà marqué comme résolu")
        message.is_resolved = True
        message.resolved_at = datetime.utcnow()
        self.db.commit()
        self.db.refresh(message)
        return message

    def delete_support_message(self, message_id: str) -> None:
        message = self.support.get_by_id(message_id)
        if not message:
            raise NotFoundError("MESSAGE_NOT_FOUND", "Message de support non trouvé")
        self.support.delete(message)
        self.db.commit()

    # ── Statistiques ──────────────────────────────────────────────────────
    def get_stats(self) -> dict:
        total_users = self.users.count()
        active_users = self.users.count_active()
        return {
            "users": {
                "total": total_users,
                "active": active_users,
                "inactive": total_users - active_users,
            },
            "guides": {
                "total": self.guides.count(),
                "pending": self.guides.count_by_status("pending"),
                "approved": self.guides.count_by_status("approved"),
                "rejected": self.guides.count_by_status("rejected"),
            },
            "support": {
                "unresolved": self.support.count_unresolved(),
            },
        }

    def get_guide(self, guide_id: str):
        """Guide par id, ou None. Utilisé par l'accès aux documents."""
        return self.guides.get_by_id(guide_id)
