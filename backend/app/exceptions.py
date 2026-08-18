"""
Domain exceptions + FastAPI exception handlers.

Les services lèvent des exceptions métier typées (AppError et ses sous-classes)
au lieu de manipuler directement des HTTPException. La couche API (via les
handlers enregistrés ici) traduit ces exceptions en réponses JSON au format
standard du projet :

    {
        "status": "error",
        "error_code": "...",
        "message": "...",
        "details": ... | null
    }

Ce format est identique à celui produit par l'ancien `main.py`, afin de
préserver le contrat d'API vis-à-vis du frontend Flutter.
"""

from fastapi import HTTPException, Request, status
from fastapi.responses import JSONResponse


# ============================================
# EXCEPTIONS MÉTIER
# ============================================

class AppError(Exception):
    """
    Exception métier de base.

    Args:
        error_code: code machine stable (ex: "EMAIL_EXISTS")
        message: message lisible destiné au client
        details: informations complémentaires optionnelles (dict/str/None)
        status_code: statut HTTP à renvoyer (défini par les sous-classes)
    """
    status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR

    def __init__(self, error_code: str, message: str, details=None, status_code: int | None = None):
        self.error_code = error_code
        self.message = message
        self.details = details
        if status_code is not None:
            self.status_code = status_code
        super().__init__(message)


class BadRequestError(AppError):
    status_code = status.HTTP_400_BAD_REQUEST


class UnauthorizedError(AppError):
    status_code = status.HTTP_401_UNAUTHORIZED


class ForbiddenError(AppError):
    status_code = status.HTTP_403_FORBIDDEN


class NotFoundError(AppError):
    status_code = status.HTTP_404_NOT_FOUND


class ConflictError(AppError):
    status_code = status.HTTP_409_CONFLICT


class ServerError(AppError):
    status_code = status.HTTP_500_INTERNAL_SERVER_ERROR


class ServiceUnavailableError(AppError):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE


# ============================================
# HANDLERS FASTAPI
# ============================================

def _error_payload(error_code: str, message: str, details=None) -> dict:
    return {
        "status": "error",
        "error_code": error_code,
        "message": message,
        "details": details,
    }


async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    """Traduit une AppError métier en réponse JSON standard."""
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload(exc.error_code, exc.message, exc.details),
    )


async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    """
    Handler pour les HTTPException restantes (ex: get_current_user dans auth.py).
    Le `detail` peut être un dict {error_code, message, details} ou une string.
    Reproduit le comportement historique de main.py.
    """
    if isinstance(exc.detail, dict):
        return JSONResponse(
            status_code=exc.status_code,
            content=_error_payload(
                exc.detail.get("error_code", "UNKNOWN_ERROR"),
                exc.detail.get("message", ""),
                exc.detail.get("details"),
            ),
        )
    return JSONResponse(
        status_code=exc.status_code,
        content=_error_payload("HTTP_ERROR", str(exc.detail)),
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Filet de sécurité pour toute erreur non gérée."""
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=_error_payload("INTERNAL_SERVER_ERROR", "Une erreur interne est survenue", str(exc)),
    )


def register_exception_handlers(app) -> None:
    """Enregistre les trois handlers sur l'application FastAPI."""
    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
