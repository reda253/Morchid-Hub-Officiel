"""
Limitation de débit — seuil unique de configuration.

Tout le reste de l'application importe `limiter` d'ici, jamais slowapi
directement : le jour où le compteur doit passer en Redis (plusieurs workers
ou plusieurs instances), seul ce fichier change.

LIMITE CONNUE — compteurs en mémoire du processus. Avec N workers uvicorn la
limite effective est N fois la valeur configurée, et tout est remis à zéro au
redémarrage. C'est acceptable pour le déploiement visé (une instance EC2,
docker compose, API épinglée à un seul worker) et c'est le déclencheur d'un
passage à Redis si l'API est un jour répliquée.
"""

from fastapi import Request
from fastapi.responses import JSONResponse
from slowapi import Limiter
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address


def rate_limit_key(request: Request) -> str:
    """Clé de comptage : IP seule.

    Les routes visant un compte précis (login, mot de passe oublié) ajoutent
    l'email via leur propre décorateur, pour qu'un attaquant ne puisse ni
    répartir ses essais sur beaucoup de comptes depuis une IP, ni concentrer
    beaucoup d'IP sur un seul compte.
    """
    return get_remote_address(request)


limiter = Limiter(key_func=rate_limit_key, enabled=True)


async def rate_limit_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    """Renvoie le format d'erreur standard du projet, pas celui de slowapi."""
    return JSONResponse(
        status_code=429,
        content={
            "status": "error",
            "error_code": "RATE_LIMITED",
            "message": "Trop de tentatives. Réessayez dans quelques minutes.",
            "details": None,
        },
    )


def register_rate_limiting(app) -> None:
    """Attache le limiter et son handler à l'application."""
    app.state.limiter = limiter
    app.add_exception_handler(RateLimitExceeded, rate_limit_handler)
