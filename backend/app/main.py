"""
Morchid Hub Backend API — point d'entrée.

`main.py` ne contient plus de logique métier : il assemble l'application
(factory `create_app`), monte les fichiers statiques, enregistre les routers de
la couche API et les handlers d'exception. La logique vit dans
`services/` (métier) et `repositories/` (accès données).
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .api import admin, auth, guides, health, premium, reviews, routes, search, time_slots
from .config import settings
from .database import Base, engine
from .exceptions import register_exception_handlers
from .rate_limit import register_rate_limiting
from .uploads import PROFILE_DIR, ensure_upload_dirs


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description=settings.DESCRIPTION,
    )

    # CORS — ouvert en développement.
    # TODO (déploiement) : restreindre via settings.cors_origins_list (voir Plan 05).
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    # Fichiers uploadés servis en statique : UNIQUEMENT les photos de profil.
    #
    # Ne jamais élargir ce montage à UPLOAD_DIR : `uploads/licenses/` et
    # `uploads/cines/` contiennent les licences professionnelles et les cartes
    # d'identité nationales (CINE) des guides. Ces documents passent par
    # l'endpoint authentifié /api/v1/admin/guides/{id}/documents/{type}.
    ensure_upload_dirs()
    app.mount("/uploads/profiles", StaticFiles(directory=str(PROFILE_DIR)), name="profile-uploads")

    # Routers (couche API) — un module par domaine.
    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(guides.router)
    app.include_router(routes.router)
    app.include_router(premium.router)
    app.include_router(reviews.router)
    app.include_router(admin.router)
    app.include_router(search.router)
    app.include_router(time_slots.router)

    # L'ordre compte : le handler RateLimitExceeded doit être enregistré avant
    # le handler attrape-tout Exception, sinon les 429 ressortiraient en 500.
    register_rate_limiting(app)
    register_exception_handlers(app)

    @app.on_event("startup")
    async def startup_event():
        # Bootstrap dev : crée les tables manquantes depuis les modèles.
        # En déploiement (Plan 04/05), la migration canonique est
        # `alembic upgrade head` — voir backend/alembic/. create_all reste ici
        # comme filet pour le développement local (idempotent).
        Base.metadata.create_all(bind=engine)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
