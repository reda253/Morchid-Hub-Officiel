"""Controller Administration — utilisateurs, guides, support, statistiques."""

from pathlib import Path
from typing import List, Literal, Optional

from fastapi import APIRouter, Depends, Query
from fastapi.responses import FileResponse

from ..exceptions import NotFoundError
from ..models import User
from ..schemas import (
    GuideRejection,
    GuideResponse,
    SupportMessageResponse,
    SuccessResponse,
    UserResponse,
)
from ..services.admin_service import AdminService
from ..services.analytics_service import AnalyticsService
from ..uploads import CINE_DIR, LICENSE_DIR
from .deps import get_admin_service, get_analytics_service, require_admin

router = APIRouter(prefix="/api/v1/admin", tags=["Admin"])


# ── Utilisateurs ──────────────────────────────────────────────────────────
@router.get("/users", response_model=List[UserResponse])
async def get_all_users(
    role: Optional[str] = Query(None, pattern="^(tourist|guide|admin)$"),
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    return service.list_users(role)


@router.put("/users/{user_id}/toggle-status", response_model=SuccessResponse)
async def toggle_user_status(
    user_id: str,
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    user = service.toggle_user_status(user_id, admin)
    status_text = "activé" if user.is_active else "désactivé"
    return SuccessResponse(
        status="success",
        message=f"Compte utilisateur {status_text}",
        data={"user_id": user.id, "is_active": user.is_active},
    )


# ── Guides ──────────────────────────────────────────────────────────────────
@router.get("/guides", response_model=List[GuideResponse])
async def get_guides_by_status(
    status: str = Query("pending", pattern="^(pending|approved|rejected)$"),
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    """Liste les guides filtrés par statut d'approbation (pending/approved/rejected)."""
    return service.list_guides_by_status(status)


@router.get("/guides/pending", response_model=List[GuideResponse])
async def get_pending_guides(
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    return service.list_pending_guides()


@router.put("/guides/{guide_id}/approve", response_model=SuccessResponse)
async def approve_guide(
    guide_id: str,
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    guide = service.approve_guide(guide_id)
    return SuccessResponse(
        status="success",
        message="Guide approuvé avec succès",
        data={
            "guide_id": guide.id,
            "user_id": guide.user_id,
            "approval_status": guide.approval_status,
        },
    )


@router.put("/guides/{guide_id}/reject", response_model=SuccessResponse)
async def reject_guide(
    guide_id: str,
    rejection: GuideRejection,
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    guide = service.reject_guide(guide_id, rejection.reason)
    return SuccessResponse(
        status="success",
        message="Guide rejeté",
        data={
            "guide_id": guide.id,
            "user_id": guide.user_id,
            "approval_status": guide.approval_status,
            "rejection_reason": guide.rejection_reason,
        },
    )


# ── Support ─────────────────────────────────────────────────────────────────
@router.get("/support/messages", response_model=List[SupportMessageResponse])
async def get_support_messages(
    resolved: Optional[bool] = Query(None, description="Filtrer par statut résolu"),
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    rows = service.list_support_messages(resolved)
    return [
        SupportMessageResponse(
            id=msg.id,
            user_id=msg.user_id,
            user_name=user.full_name if user else "Utilisateur inconnu",
            user_email=user.email if user else "Email inconnu",
            subject=msg.subject,
            message=msg.message,
            is_resolved=msg.is_resolved,
            created_at=msg.created_at,
            resolved_at=msg.resolved_at,
        )
        for msg, user in rows
    ]


@router.put("/support/messages/{message_id}/resolve", response_model=SuccessResponse)
async def resolve_support_message(
    message_id: str,
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    message = service.resolve_support_message(message_id)
    return SuccessResponse(
        status="success",
        message="Message marqué comme résolu",
        data={"message_id": message.id, "resolved_at": message.resolved_at.isoformat()},
    )


@router.delete("/support/messages/{message_id}", response_model=SuccessResponse)
async def delete_support_message(
    message_id: str,
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    service.delete_support_message(message_id)
    return SuccessResponse(
        status="success",
        message="Message de support supprimé",
        data={"message_id": message_id},
    )


# ── Statistiques ────────────────────────────────────────────────────────────
@router.get("/stats")
async def get_admin_stats(
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    return service.get_stats()


# ── Analytics revenu & abonnements (données réelles) ─────────────────────────
@router.get("/analytics/overview", summary="KPI revenu/abonnements du tableau de bord")
async def analytics_overview(
    service: AnalyticsService = Depends(get_analytics_service),
    admin: User = Depends(require_admin),
):
    return service.overview()


@router.get("/analytics/revenue", summary="Série mensuelle du revenu (graphe)")
async def analytics_revenue(
    months: int = Query(6, ge=1, le=24),
    service: AnalyticsService = Depends(get_analytics_service),
    admin: User = Depends(require_admin),
):
    return service.revenue_timeseries(months)


@router.get("/analytics/subscriptions", summary="Répartition des abonnements actifs par tier")
async def analytics_subscriptions(
    service: AnalyticsService = Depends(get_analytics_service),
    admin: User = Depends(require_admin),
):
    return service.subscriptions_breakdown()


# ── Documents d'identité ──────────────────────────────────────────────────
@router.get("/guides/{guide_id}/documents/{doc_type}", tags=["Administration"])
async def get_guide_document(
    guide_id: str,
    doc_type: Literal["license", "cine"],
    service: AdminService = Depends(get_admin_service),
    admin: User = Depends(require_admin),
):
    """Sert un document d'identité de guide à un administrateur authentifié.

    Ces fichiers ne sont plus servis en statique (voir main.py) : la licence
    professionnelle et la CINE sont des pièces d'identité.

    Garde contre la traversée de répertoire : la route n'accepte jamais un nom
    de fichier fourni par le client, seulement un id de guide et un type parmi
    deux valeurs. Le chemin lu en base est ensuite re-vérifié comme étant à
    l'intérieur du dossier attendu — une valeur corrompue en base ne peut donc
    pas faire sortir la lecture de l'arborescence.
    """
    guide = service.get_guide(guide_id)
    if guide is None:
        raise NotFoundError("GUIDE_NOT_FOUND", "Guide introuvable")

    if doc_type == "license":
        stored, root = guide.license_card_url, LICENSE_DIR
    else:
        stored, root = guide.cine_card_url, CINE_DIR

    if not stored:
        raise NotFoundError("DOCUMENT_NOT_FOUND", "Document non fourni par ce guide")

    candidate = (root / Path(stored).name).resolve()
    if not candidate.is_file() or root.resolve() not in candidate.parents:
        raise NotFoundError("DOCUMENT_NOT_FOUND", "Document introuvable")

    return FileResponse(candidate)
