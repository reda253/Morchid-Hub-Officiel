"""Controller Authentification & Profil — inscription, connexion, email, mot de passe."""

from fastapi import APIRouter, Depends, status

from ..auth import get_current_user
from ..models import User
from ..schemas import (
    ForgotPasswordRequest,
    GuideResponse,
    RegistrationResponse,
    ResendVerificationRequest,
    ResetPasswordRequest,
    SuccessResponse,
    TokenResponse,
    UserLogin,
    UserProfileResponse,
    UserRegistration,
    UserResponse,
    VerifyEmailRequest,
)
from ..services.auth_service import AuthService
from .deps import get_auth_service

router = APIRouter(prefix="/api/v1", tags=["Authentication"])


@router.post("/register", response_model=RegistrationResponse, status_code=status.HTTP_201_CREATED)
async def register_user(
    user_data: UserRegistration, service: AuthService = Depends(get_auth_service)
):
    user, guide_profile, message = service.register(user_data)
    return RegistrationResponse(
        status="success",
        message=message,
        user=UserResponse.from_orm(user),
        guide_profile=GuideResponse.from_orm(guide_profile) if guide_profile else None,
    )


@router.post("/login", response_model=TokenResponse)
async def login_user(credentials: UserLogin, service: AuthService = Depends(get_auth_service)):
    user, access_token = service.login(credentials.email, credentials.password)
    return TokenResponse(
        access_token=access_token, token_type="bearer", user=UserResponse.from_orm(user)
    )


@router.post("/auth/verify-email", response_model=SuccessResponse)
async def verify_email(
    request: VerifyEmailRequest, service: AuthService = Depends(get_auth_service)
):
    user = service.verify_email(request.token)
    return SuccessResponse(
        status="success",
        message="Votre email a été vérifié avec succès ! Vous pouvez maintenant vous connecter.",
        data={"email": user.email},
    )


@router.get("/verify-email")
async def verify_email_get(token: str, service: AuthService = Depends(get_auth_service)):
    user = service.verify_email_by_link(token)
    if not user:
        return {"status": "error", "message": "Lien invalide ou expiré."}
    return {
        "status": "success",
        "message": f"Félicitations {user.full_name}, ton compte Morchid Hub est maintenant actif !",
    }


@router.post("/auth/resend-verification", response_model=SuccessResponse)
async def resend_verification_email(
    request: ResendVerificationRequest, service: AuthService = Depends(get_auth_service)
):
    service.resend_verification(request.email)
    return SuccessResponse(
        status="success",
        message="Si cet email existe et n'est pas encore vérifié, un nouveau lien a été envoyé.",
    )


@router.post("/auth/forgot-password", response_model=SuccessResponse)
async def forgot_password(
    request: ForgotPasswordRequest, service: AuthService = Depends(get_auth_service)
):
    service.forgot_password(request.email)
    return SuccessResponse(
        status="success",
        message="Si cet email existe, un lien de réinitialisation a été envoyé.",
        data=None,
    )


@router.get("/reset-password-page")
async def reset_password_page(token: str, service: AuthService = Depends(get_auth_service)):
    user = service.get_reset_target(token)
    if not user:
        return {"status": "error", "message": "Token de réinitialisation invalide."}
    return {
        "status": "success",
        "message": (
            f"Bonjour {user.full_name}, vous pouvez maintenant envoyer un POST vers "
            "/api/v1/auth/reset-password avec votre nouveau mot de passe."
        ),
    }


@router.post("/auth/reset-password", response_model=SuccessResponse)
async def reset_password(
    request: ResetPasswordRequest, service: AuthService = Depends(get_auth_service)
):
    service.reset_password(request.token, request.new_password)
    return SuccessResponse(
        status="success",
        message="Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter.",
    )


@router.get("/auth/me", response_model=UserProfileResponse, tags=["User Profile"])
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    guide, stats = service.get_profile(current_user)
    return UserProfileResponse(
        user=UserResponse.from_orm(current_user),
        guide_profile=GuideResponse.from_orm(guide) if guide else None,
        stats=stats,
    )
