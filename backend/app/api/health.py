"""Endpoints d'infrastructure : racine et health check."""

import logging

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..exceptions import ServiceUnavailableError

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Health"])


@router.get("/")
async def root():
    return {
        "status": "ok",
        "message": "Morchid Hub API is running",
        "version": settings.VERSION,
    }


@router.get("/health")
async def health_check(db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        # Le détail part dans les logs serveur, jamais dans la réponse : les
        # exceptions SQLAlchemy/pg8000 contiennent l'hôte, le port, le nom de
        # la base et l'utilisateur.
        logger.exception("Health check: connexion à la base indisponible")
        raise ServiceUnavailableError(
            "DATABASE_UNAVAILABLE", "Base de données indisponible"
        )
    return {"status": "healthy", "database": "connected", "version": settings.VERSION}
