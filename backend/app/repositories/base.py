"""Repository de base : porte la session SQLAlchemy."""

from sqlalchemy.orm import Session


class BaseRepository:
    """Toutes les repositories partagent une même session de requête."""

    def __init__(self, db: Session):
        self.db = db
