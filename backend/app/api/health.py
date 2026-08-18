"""Endpoints d'infrastructure : racine et health check."""

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from ..config import settings
from ..database import get_db
from ..exceptions import ServiceUnavailableError

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
    except Exception as e:
        raise ServiceUnavailableError(
            "DATABASE_UNAVAILABLE", f"Database connection failed: {str(e)}"
        )
    return {"status": "healthy", "database": "connected", "version": settings.VERSION}
