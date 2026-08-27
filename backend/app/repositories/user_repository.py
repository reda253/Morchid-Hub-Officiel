"""Accès aux données de la table `users`."""

from typing import List, Optional

from ..models import User
from .base import BaseRepository


class UserRepository(BaseRepository):

    def get_by_id(self, user_id: str) -> Optional[User]:
        return self.db.query(User).filter(User.id == user_id).first()

    def get_by_email(self, email: str) -> Optional[User]:
        return self.db.query(User).filter(User.email == email).first()

    def get_by_phone(self, phone: str) -> Optional[User]:
        return self.db.query(User).filter(User.phone == phone).first()

    def get_by_verification_token(self, token: str) -> Optional[User]:
        return self.db.query(User).filter(User.verification_token == token).first()

    def get_by_reset_token(self, token: str) -> Optional[User]:
        return self.db.query(User).filter(User.reset_password_token == token).first()

    def add(self, user: User) -> None:
        self.db.add(user)

    def list_ordered(self, role: Optional[str] = None) -> List[User]:
        query = self.db.query(User)
        if role:
            query = query.filter(User.role == role)
        return query.order_by(User.created_at.desc()).all()

    # ── Statistiques (admin) ──────────────────────────────────────────────
    def count(self) -> int:
        return self.db.query(User).count()

    def count_active(self) -> int:
        return self.db.query(User).filter(User.is_active == True).count()
