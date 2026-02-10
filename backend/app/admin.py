"""
Admin Routes for Morchid Hub
Gestion des utilisateurs, guides et support technique
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime

from .database import get_db
from .models import User, Guide, SupportMessage
from .schemas import (
    UserResponse, 
    GuideResponse, 
    SuccessResponse,
    GuideRejection,
    SupportMessageResponse
)
from .auth import get_current_user

router = APIRouter(
    prefix="/api/v1/admin",
    tags=["Admin"]
)


# ============================================
# MIDDLEWARE D'AUTORISATION ADMIN
# ============================================

def verify_admin(current_user: User = Depends(get_current_user)):
    """Vérifie que l'utilisateur actuel est un administrateur"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "FORBIDDEN",
                "message": "Seuls les administrateurs peuvent accéder à cette section"
            }
        )
    return current_user


# ============================================
# GESTION DES UTILISATEURS
# ============================================

@router.get("/users", response_model=List[UserResponse])
async def get_all_users(
    role: Optional[str] = Query(None, pattern="^(tourist|guide|admin)$"),
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Liste tous les utilisateurs avec filtrage optionnel par rôle
    
    - **role**: Filtrer par rôle (tourist, guide, admin)
    """
    query = db.query(User)
    if role:
        query = query.filter(User.role == role)
    
    users = query.order_by(User.created_at.desc()).all()
    return users


@router.put("/users/{user_id}/toggle-status", response_model=SuccessResponse)
async def toggle_user_status(
    user_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Active ou désactive un utilisateur
    
    - Inverse le statut is_active de l'utilisateur
    - L'admin ne peut pas se désactiver lui-même
    """
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "USER_NOT_FOUND",
                "message": "Utilisateur non trouvé"
            }
        )
    
    # Empêcher l'admin de se désactiver lui-même
    if user.id == admin.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "SELF_DEACTIVATION",
                "message": "Vous ne pouvez pas désactiver votre propre compte"
            }
        )

    # Inverser le statut
    user.is_active = not user.is_active
    db.commit()
    db.refresh(user)
    
    status_text = "activé" if user.is_active else "désactivé"
    return SuccessResponse(
        status="success",
        message=f"Compte utilisateur {status_text}",
        data={
            "user_id": user.id,
            "is_active": user.is_active
        }
    )


# ============================================
# GESTION DES GUIDES
# ============================================

@router.get("/guides/pending", response_model=List[GuideResponse])
async def get_pending_guides(
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Liste les guides en attente d'approbation
    
    - Retourne uniquement les guides avec approval_status = 'pending_approval'
    - Inclut les URLs des documents (photo, licence, CINE)
    """
    guides = db.query(Guide).filter(
        Guide.approval_status == "pending_approval"
    ).order_by(Guide.created_at.desc()).all()
    
    return guides


@router.put("/guides/{guide_id}/approve", response_model=SuccessResponse)
async def approve_guide(
    guide_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Approuve un guide
    
    - Change approval_status à 'approved'
    - Active is_verified
    """
    guide = db.query(Guide).filter(Guide.id == guide_id).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_NOT_FOUND",
                "message": "Guide non trouvé"
            }
        )
    
    # Vérifier que le guide est en attente
    if guide.approval_status != "pending_approval":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "INVALID_STATUS",
                "message": f"Ce guide est déjà {guide.approval_status}"
            }
        )
    
    # Approuver le guide
    guide.approval_status = "approved"
    guide.is_verified = True
    guide.rejection_reason = None  # Effacer tout ancien motif de rejet
    
    db.commit()
    db.refresh(guide)
    
    return SuccessResponse(
        status="success",
        message=f"Guide approuvé avec succès",
        data={
            "guide_id": guide.id,
            "user_id": guide.user_id,
            "approval_status": guide.approval_status
        }
    )


@router.put("/guides/{guide_id}/reject", response_model=SuccessResponse)
async def reject_guide(
    guide_id: str,
    rejection: GuideRejection,
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Rejette un guide avec un motif
    
    - Change approval_status à 'rejected'
    - Enregistre le motif du rejet dans rejection_reason
    """
    guide = db.query(Guide).filter(Guide.id == guide_id).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_NOT_FOUND",
                "message": "Guide non trouvé"
            }
        )
    
    # Vérifier que le guide est en attente
    if guide.approval_status != "pending_approval":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "INVALID_STATUS",
                "message": f"Ce guide est déjà {guide.approval_status}"
            }
        )
    
    # Rejeter le guide avec le motif
    guide.approval_status = "rejected"
    guide.is_verified = False
    guide.rejection_reason = rejection.reason
    
    db.commit()
    db.refresh(guide)
    
    return SuccessResponse(
        status="success",
        message=f"Guide rejeté",
        data={
            "guide_id": guide.id,
            "user_id": guide.user_id,
            "approval_status": guide.approval_status,
            "rejection_reason": guide.rejection_reason
        }
    )


# ============================================
# GESTION DU SUPPORT TECHNIQUE
# ============================================

@router.get("/support/messages", response_model=List[SupportMessageResponse])
async def get_support_messages(
    resolved: Optional[bool] = Query(None, description="Filtrer par statut résolu"),
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Liste tous les messages de support
    
    - **resolved**: Si True, ne retourne que les messages résolus
    - **resolved**: Si False, ne retourne que les messages non résolus
    - **resolved**: Si None, retourne tous les messages
    """
    query = db.query(SupportMessage)
    
    if resolved is not None:
        query = query.filter(SupportMessage.is_resolved == resolved)
    
    messages = query.order_by(
        SupportMessage.is_resolved.asc(),  # Non résolus en premier
        SupportMessage.created_at.desc()
    ).all()
    
    # Enrichir avec les infos utilisateur
    result = []
    for msg in messages:
        user = db.query(User).filter(User.id == msg.user_id).first()
        result.append(
            SupportMessageResponse(
                id=msg.id,
                user_id=msg.user_id,
                user_name=user.full_name if user else "Utilisateur inconnu",
                user_email=user.email if user else "Email inconnu",
                subject=msg.subject,
                message=msg.message,
                is_resolved=msg.is_resolved,
                created_at=msg.created_at,
                resolved_at=msg.resolved_at
            )
        )
    
    return result


@router.put("/support/messages/{message_id}/resolve", response_model=SuccessResponse)
async def resolve_support_message(
    message_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Marque un message de support comme résolu
    
    - Change is_resolved à True
    - Enregistre la date de résolution
    """
    message = db.query(SupportMessage).filter(SupportMessage.id == message_id).first()
    
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "MESSAGE_NOT_FOUND",
                "message": "Message de support non trouvé"
            }
        )
    
    # Vérifier que le message n'est pas déjà résolu
    if message.is_resolved:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "ALREADY_RESOLVED",
                "message": "Ce message est déjà marqué comme résolu"
            }
        )
    
    # Marquer comme résolu
    message.is_resolved = True
    message.resolved_at = datetime.utcnow()
    
    db.commit()
    db.refresh(message)
    
    return SuccessResponse(
        status="success",
        message="Message marqué comme résolu",
        data={
            "message_id": message.id,
            "resolved_at": message.resolved_at.isoformat()
        }
    )


@router.delete("/support/messages/{message_id}", response_model=SuccessResponse)
async def delete_support_message(
    message_id: str,
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Supprime un message de support
    
    - Suppression définitive du message
    """
    message = db.query(SupportMessage).filter(SupportMessage.id == message_id).first()
    
    if not message:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "MESSAGE_NOT_FOUND",
                "message": "Message de support non trouvé"
            }
        )
    
    db.delete(message)
    db.commit()
    
    return SuccessResponse(
        status="success",
        message="Message de support supprimé",
        data={"message_id": message_id}
    )


# ============================================
# STATISTIQUES ADMIN (BONUS)
# ============================================

@router.get("/stats")
async def get_admin_stats(
    db: Session = Depends(get_db),
    admin: User = Depends(verify_admin)
):
    """
    Retourne les statistiques globales de la plateforme
    """
    total_users = db.query(User).count()
    active_users = db.query(User).filter(User.is_active == True).count()
    total_guides = db.query(Guide).count()
    pending_guides = db.query(Guide).filter(Guide.approval_status == "pending_approval").count()
    approved_guides = db.query(Guide).filter(Guide.approval_status == "approved").count()
    rejected_guides = db.query(Guide).filter(Guide.approval_status == "rejected").count()
    unresolved_support = db.query(SupportMessage).filter(SupportMessage.is_resolved == False).count()
    
    return {
        "users": {
            "total": total_users,
            "active": active_users,
            "inactive": total_users - active_users
        },
        "guides": {
            "total": total_guides,
            "pending": pending_guides,
            "approved": approved_guides,
            "rejected": rejected_guides
        },
        "support": {
            "unresolved": unresolved_support
        }
    }