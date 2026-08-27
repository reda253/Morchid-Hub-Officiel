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

import logging

from fastapi import HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


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


# Noms lisibles pour les champs les plus souvent rejetés.
_FIELD_LABELS = {
    "password": "Le mot de passe",
    "new_password": "Le nouveau mot de passe",
    "email": "L'adresse email",
    "phone": "Le numéro de téléphone",
    "full_name": "Le nom complet",
    "date_of_birth": "La date de naissance",
    "role": "Le rôle",
    "bio": "La biographie",
    "token": "Le token",
}


def _describe_validation_error(err: dict) -> str:
    """Formule en français une erreur de validation Pydantic."""
    loc = [str(p) for p in err.get("loc", ()) if p not in ("body", "query", "path")]
    field = loc[-1] if loc else ""
    label = _FIELD_LABELS.get(field, f"Le champ « {field} »" if field else "La requête")
    err_type = err.get("type", "")
    ctx = err.get("ctx") or {}

    if err_type == "value_error":
        # Message levé par nos propres @validator : déjà rédigé en français.
        # Pydantic v2 le préfixe par « Value error, ».
        msg = err.get("msg", "")
        return msg.split("Value error, ", 1)[-1] if msg else f"{label} est invalide"
    if err_type == "string_too_short":
        return f"{label} doit contenir au moins {ctx.get('min_length', '?')} caractères"
    if err_type == "string_too_long":
        return f"{label} ne doit pas dépasser {ctx.get('max_length', '?')} caractères"
    if err_type == "missing":
        return f"{label} est obligatoire"
    if err_type in ("string_pattern_mismatch", "value_error.str.regex"):
        return f"{label} n'est pas au bon format"
    return f"{label} est invalide"


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Traduit les erreurs de validation Pydantic dans l'enveloppe du projet.

    Sans ce handler, FastAPI répond nativement `{"detail": [...]}` en anglais —
    une forme que le client Flutter ne sait pas lire, si bien qu'un mot de passe
    trop court s'affichait « une erreur inattendue est survenue (422) » au lieu
    de dire quelle règle n'est pas respectée.
    """
    described = [_describe_validation_error(e) for e in (exc.errors() or [])]
    # Dédoublonnage en gardant l'ordre : deux règles sur un même champ peuvent
    # produire la même phrase.
    seen, messages = set(), []
    for m in described:
        if m not in seen:
            seen.add(m)
            messages.append(m)

    # Toutes les erreurs sont annoncées, pas seulement la première : sur un
    # formulaire d'inscription, ne montrer que l'erreur initiale désigne un
    # champ arbitraire pendant que celui qui bloque reste invisible.
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=_error_payload(
            "VALIDATION_ERROR",
            "\n".join(messages) if messages else "Requête invalide",
            messages or None,
        ),
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    """Filet de sécurité pour toute erreur non gérée.

    `details` reste vide côté client : y placer `str(exc)` renvoyait le texte
    d'exceptions internes — chaînes de connexion, chemins, fragments SQL — à
    n'importe quel appelant capable de provoquer une 500.
    """
    logger.exception("Erreur non gérée sur %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=_error_payload("INTERNAL_SERVER_ERROR", "Une erreur interne est survenue"),
    )


def register_exception_handlers(app) -> None:
    """Enregistre les trois handlers sur l'application FastAPI."""
    app.add_exception_handler(AppError, app_error_handler)
    app.add_exception_handler(HTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
