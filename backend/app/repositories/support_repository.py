"""Accès aux données de la table `support_messages`."""

from typing import List, Optional, Tuple

from ..models import SupportMessage, User
from .base import BaseRepository


class SupportRepository(BaseRepository):

    def get_by_id(self, message_id: str) -> Optional[SupportMessage]:
        return self.db.query(SupportMessage).filter(SupportMessage.id == message_id).first()

    def list_with_users(self, resolved: Optional[bool] = None) -> List[Tuple[SupportMessage, Optional[User]]]:
        """
        Messages joints à leur auteur (non résolus d'abord, puis plus récents).

        Un LEFT JOIN unique remplace la boucle N+1 de l'ancien code : un seul
        aller-retour SQL au lieu d'une requête User par message.
        """
        query = (
            self.db.query(SupportMessage, User)
            .outerjoin(User, SupportMessage.user_id == User.id)
        )
        if resolved is not None:
            query = query.filter(SupportMessage.is_resolved == resolved)
        return query.order_by(
            SupportMessage.is_resolved.asc(),
            SupportMessage.created_at.desc(),
        ).all()

    def delete(self, message: SupportMessage) -> None:
        self.db.delete(message)

    def count_unresolved(self) -> int:
        return (
            self.db.query(SupportMessage)
            .filter(SupportMessage.is_resolved == False)
            .count()
        )
