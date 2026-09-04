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


# Valeurs d'exemple qui ne doivent jamais servir en dehors du poste de dev.
_PLACEHOLDER_SECRETS = {
    "votre_cle_secrete_super_longue_et_aleatoire_ici",
    "changeme",
    "secret",
}
_MIN_SECRET_LENGTH = 32


def _assert_secret_key_is_safe(secret: str) -> None:
    """Refuse de démarrer avec une clé d'exemple ou trop courte.

    Échec à l'ouverture (fail closed) : une clé faible laisse forger des JWT
    valides pour n'importe quel compte, y compris administrateur.
    """
    if secret.strip().lower() in _PLACEHOLDER_SECRETS or len(secret) < _MIN_SECRET_LENGTH:
        raise RuntimeError(
            "SECRET_KEY invalide : utilisez une valeur aléatoire d'au moins "
            f"{_MIN_SECRET_LENGTH} caractères (voir backend/.env)."
        )


def create_app() -> FastAPI:
    _assert_secret_key_is_safe(settings.SECRET_KEY)

    app = FastAPI(
        title=settings.PROJECT_NAME,
        version=settings.VERSION,
        description=settings.DESCRIPTION,
    )

    # CORS restreint aux origines déclarées dans CORS_ORIGINS.
    #
    # allow_origins=["*"] avec allow_credentials=True n'était pas seulement
    # permissif : les navigateurs refusent cette combinaison, donc les appels
    # cross-origin authentifiés échouaient de toute façon.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
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
        # Bootstrap DEV UNIQUEMENT : crée les tables manquantes depuis les
        # modèles. En conteneur et en déploiement, la migration canonique est
        # `alembic upgrade head` (voir backend/docker-entrypoint.sh) et elle est
        # la SEULE autorité de schéma : laisser create_all actif ferait créer
        # en silence les tables d'un modèle ayant dérivé des migrations, sans
        # ligne correspondante dans `alembic_version`.
        if settings.DEBUG:
            Base.metadata.create_all(bind=engine)

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
