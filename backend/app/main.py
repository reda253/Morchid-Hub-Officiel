"""
Morchid Hub Backend API
FastAPI application with PostgreSQL integration
"""

from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List

from .config import settings
from .database import get_db, init_db, engine
from .models import User, Guide, Base
from .schemas import (
    UserRegistration,
    UserLogin,
    RegistrationResponse,
    TokenResponse,
    UserResponse,
    GuideResponse,
    UserProfileResponse,
    ErrorResponse,
    ForgotPasswordRequest,
    ResetPasswordRequest,
    VerifyEmailRequest,
    ResendVerificationRequest,
    SuccessResponse
)
from .auth import hash_password, verify_password, create_access_token, get_current_user

from .email_utils import (
    generate_verification_token,
    generate_reset_password_token,
    get_token_expiry,
    is_token_expired,
    send_verification_email,
    send_password_reset_email,
    send_password_changed_confirmation
)

# ============================================
# APPLICATION INITIALIZATION
# ============================================

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description=settings.DESCRIPTION,
)

# ============================================
# CORS CONFIGURATION
# ============================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En production, utiliser settings.cors_origins_list
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================
# STARTUP EVENT
# ============================================

@app.on_event("startup")
async def startup_event():
    """Initialiser la base de données au démarrage"""
    print("Demarrage de Morchid Hub API...")
    print(f"Connexion a la base de donnees: {settings.DATABASE_URL.split('@')[1]}")
    
    # Créer les tables si elles n'existent pas
    Base.metadata.create_all(bind=engine)
    print("Base de donnees initialisee")


# ============================================
# HEALTH CHECK ENDPOINT
# ============================================

@app.get("/")
async def root():
    """Endpoint de test pour vérifier que l'API fonctionne"""
    return {
        "status": "ok",
        "message": "Morchid Hub API is running",
        "version": settings.VERSION
    }


@app.get("/health")
async def health_check(db: Session = Depends(get_db)):
    """Vérifier la santé de l'API et de la base de données"""
    try:
        # Tester la connexion DB
        db.execute("SELECT 1")
        return {
            "status": "healthy",
            "database": "connected",
            "version": settings.VERSION
        }
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Database connection failed: {str(e)}"
        )


# ============================================
# AUTHENTICATION ENDPOINTS
# ============================================

@app.post(
    "/api/v1/register",
    response_model=RegistrationResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Authentication"]
)
async def register_user(
    user_data: UserRegistration,
    db: Session = Depends(get_db)
):
    """
    Inscription d'un nouvel utilisateur (touriste ou guide)
    
    - **personal_info**: Nom, email, téléphone, date de naissance
    - **role**: 'tourist' ou 'guide'
    - **password**: Mot de passe (sera hashé)
    - **guide_details**: Obligatoire si role = 'guide'
    """
    
    # ============================================
    # 1. VÉRIFIER SI L'EMAIL EXISTE DÉJÀ
    # ============================================
    existing_user = db.query(User).filter(User.email == user_data.personal_info.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "EMAIL_EXISTS",
                "message": "Un compte avec cet email existe déjà",
                "field": "email"
            }
        )
    
    # ============================================
    # 2. VÉRIFIER SI LE TÉLÉPHONE EXISTE DÉJÀ
    # ============================================
    existing_phone = db.query(User).filter(User.phone == user_data.personal_info.phone).first()
    if existing_phone:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "PHONE_EXISTS",
                "message": "Un compte avec ce numéro existe déjà",
                "field": "phone"
            }
        )
    
    # ============================================
    # 3. HASHER LE MOT DE PASSE
    # ============================================
    password_hash = hash_password(user_data.password)

     # ============================================
    # 3.5 GÉNÉRER UN TOKEN DE VÉRIFICATION EMAIL
    # ============================================
    verification_token = generate_verification_token()
    token_expiry = get_token_expiry(hours=24)  # Valide 24h
    
    # ============================================
    # 4. CRÉER L'UTILISATEUR
    # ============================================
    new_user = User(
        full_name=user_data.personal_info.full_name,
        email=user_data.personal_info.email,
        phone=user_data.personal_info.phone,
        date_of_birth=user_data.personal_info.date_of_birth,
        password_hash=password_hash,
        role=user_data.role,
        is_active=True,
        is_email_verified=False,  # Par défaut non vérifié
        verification_token=verification_token,
        token_expires_at=token_expiry
    )
    
    db.add(new_user)
    db.flush()  # Pour obtenir l'ID sans committer
    
    # ============================================
    # 5. SI C'EST UN GUIDE, CRÉER LE PROFIL GUIDE
    # ============================================
    guide_profile = None
    if user_data.role == 'guide' and user_data.guide_details:
        guide_profile = Guide(
            user_id=new_user.id,
            languages=user_data.guide_details.languages,
            specialties=user_data.guide_details.specialties,
            cities_covered=user_data.guide_details.cities_covered,
            years_of_experience=user_data.guide_details.years_of_experience,
            bio=user_data.guide_details.bio,
            is_verified=False,  # Par défaut, non vérifié
            eco_score=0,  # Score initial
            approval_status='pending_approval'  # En attente d'approbation
        )
        db.add(guide_profile)
    
    # ============================================
    # 6. SAUVEGARDER EN BASE DE DONNÉES
    # ============================================
    try:
        db.commit()
        db.refresh(new_user)
        if guide_profile:
            db.refresh(guide_profile)
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error_code": "DATABASE_ERROR",
                "message": "Erreur lors de l'enregistrement",
                "details": str(e)
            }
        )
    
    # ============================================
    # 7. PRÉPARER LA RÉPONSE
    # ============================================
    # Envoyer l'email de vérification
    send_verification_email(
        email=new_user.email,
        full_name=new_user.full_name,
        token=verification_token
    )

    response_message = (
        "Inscription réussie ! Vérifiez votre email pour activer votre compte."
        if user_data.role == 'guide'
        else "Bienvenue sur Morchid Hub ! Vérifiez votre email pour activer votre compte."
    )


    
    
    return RegistrationResponse(
        status="success",
        message=response_message,
        user=UserResponse.from_orm(new_user),
        guide_profile=GuideResponse.from_orm(guide_profile) if guide_profile else None
    )


@app.post(
    "/api/v1/login",
    response_model=TokenResponse,
    tags=["Authentication"]
)
async def login_user(
    credentials: UserLogin,
    db: Session = Depends(get_db)
):
    """
    Connexion d'un utilisateur
    
    - **email**: Email de l'utilisateur
    - **password**: Mot de passe
    
    Retourne un token JWT pour les futures requêtes authentifiées
    """
    
    # ============================================
    # 1. TROUVER L'UTILISATEUR PAR EMAIL
    # ============================================
    user = db.query(User).filter(User.email == credentials.email).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error_code": "INVALID_CREDENTIALS",
                "message": "Email ou mot de passe incorrect"
            }
        )
    
    # ============================================
    # 2. VÉRIFIER LE MOT DE PASSE
    # ============================================
    if not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={
                "error_code": "INVALID_CREDENTIALS",
                "message": "Email ou mot de passe incorrect"
            }
        )
    
    # ============================================
    # 3. VÉRIFIER QUE LE COMPTE EST ACTIF
    # ============================================
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "ACCOUNT_DISABLED",
                "message": "Votre compte a été désactivé. Contactez le support."
            }
        )
    
    # ============================================
    # 3.5 AVERTIR SI L'EMAIL N'EST PAS VÉRIFIÉ (mais autoriser quand même)
    # ============================================
    # Note: En production, vous pourriez bloquer la connexion si non vérifié
    if not user.is_email_verified:
        print(f" Utilisateur {user.email} connecté mais email non vérifié")
    
    # ============================================
    # 4. CRÉER LE TOKEN JWT
    # ============================================
    token_data = {
        "sub": user.id,
        "email": user.email,
        "role": user.role
    }
    access_token = create_access_token(token_data)
    
    # ============================================
    # 5. RETOURNER LE TOKEN ET LES INFOS USER
    # ============================================
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=UserResponse.from_orm(user)
    )

# ============================================
# EMAIL VERIFICATION ENDPOINTS
# ============================================

@app.post(
    "/api/v1/auth/verify-email",
    response_model=SuccessResponse,
    tags=["Authentication"]
)
async def verify_email(
    request: VerifyEmailRequest,
    db: Session = Depends(get_db)
):
    """
    Vérifier l'email d'un utilisateur avec le token reçu par email
    
    - **token**: Token de vérification reçu par email
    """
    
    # ============================================
    # 1. TROUVER L'UTILISATEUR PAR TOKEN
    # ============================================
    user = db.query(User).filter(
        User.verification_token == request.token
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "INVALID_TOKEN",
                "message": "Token de vérification invalide ou déjà utilisé"
            }
        )
    
    # ============================================
    # 2. VÉRIFIER QUE LE TOKEN N'A PAS EXPIRÉ
    # ============================================
    if is_token_expired(user.token_expires_at):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "TOKEN_EXPIRED",
                "message": "Le token de vérification a expiré. Demandez un nouveau lien."
            }
        )
    
    # ============================================
    # 3. MARQUER L'EMAIL COMME VÉRIFIÉ
    # ============================================
    user.is_email_verified = True
    user.verification_token = None  # Invalider le token
    user.token_expires_at = None
    
    db.commit()

    print(f" Email vérifié pour {user.email}")
    
    return SuccessResponse(
        status="success",
        message="Votre email a été vérifié avec succès ! Vous pouvez maintenant vous connecter.",
        data={"email": user.email}
    )

@app.get("/api/v1/verify-email", tags=["Authentication"])
async def verify_email_get(token: str, db: Session = Depends(get_db)):
    """
    Route appelée quand on clique sur le lien du terminal (Simulation)
    """
    # 1. Chercher l'utilisateur par token
    user = db.query(User).filter(User.verification_token == token).first()
    
    if not user:
        return {"status": "error", "message": "Lien invalide ou expiré."}

    # 2. Vérifier l'email
    user.is_email_verified = True
    user.verification_token = None
    user.token_expires_at = None
    
    db.commit()
    
    print(f"Compte activé via lien pour : {user.email}")
    
    return {
        "status": "success", 
        "message": f"Félicitations {user.full_name}, ton compte Morchid Hub est maintenant actif !"
    }

@app.post(
    "/api/v1/auth/resend-verification",
    response_model=SuccessResponse,
    tags=["Authentication"]
)
async def resend_verification_email(
    request: ResendVerificationRequest,
    db: Session = Depends(get_db)
):
    """
    Renvoyer l'email de vérification
    
    - **email**: Email de l'utilisateur
    """
    
    # ============================================
    # 1. TROUVER L'UTILISATEUR
    # ============================================
    user = db.query(User).filter(User.email == request.email).first()
    
    if not user:
        # Ne pas révéler si l'email existe ou non (sécurité)
        return SuccessResponse(
            status="success",
            message="Si cet email existe, un nouveau lien de vérification a été envoyé."
        )  

    # ============================================
    # 2. VÉRIFIER SI L'EMAIL EST DÉJÀ VÉRIFIÉ
    # ============================================
    if user.is_email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "ALREADY_VERIFIED",
                "message": "Votre email est déjà vérifié"
            }
        )
    
    # ============================================
    # 3. GÉNÉRER UN NOUVEAU TOKEN
    # ============================================
    new_token = generate_verification_token()
    user.verification_token = new_token
    user.token_expires_at = get_token_expiry(hours=24)
    
    db.commit()
# ============================================
    # 4. ENVOYER L'EMAIL
    # ============================================
    send_verification_email(
        email=user.email,
        full_name=user.full_name,
        token=new_token
    )
    
    return SuccessResponse(
        status="success",
        message="Un nouveau lien de vérification a été envoyé à votre adresse email."
    )

# ============================================
# PASSWORD RESET ENDPOINTS
# ============================================

@app.post(
    "/api/v1/auth/forgot-password",
    response_model=SuccessResponse,
    tags=["Authentication"]
)
async def forgot_password(
    request: ForgotPasswordRequest,
    db: Session = Depends(get_db)
):
    """
    Demander un lien de réinitialisation de mot de passe
    
    - **email**: Email de l'utilisateur
    """
    
    # ============================================
    # 1. TROUVER L'UTILISATEUR
    # ============================================
    user = db.query(User).filter(User.email == request.email).first()
    
    if not user:
        # Ne pas révéler si l'email existe ou non (sécurité)
        return SuccessResponse(
            status="success",
            message="Si cet email existe, un lien de réinitialisation a été envoyé."
        )
    # ============================================
    # 2. GÉNÉRER UN TOKEN DE RÉINITIALISATION
    # ============================================
    reset_token = generate_reset_password_token()
    user.reset_password_token = reset_token
    user.token_expires_at = get_token_expiry(hours=24)  # Valide 24h
    
    db.commit()

    # ============================================
    # 3. ENVOYER L'EMAIL
    # ============================================
    send_password_reset_email(
        email=user.email,
        full_name=user.full_name,
        token=reset_token
    )
    
    return SuccessResponse(
        status="success",
        message="Si cet email existe, un lien de réinitialisation a été envoyé.",
        data={"email_sent_to": request.email}
    )
@app.get("/api/v1/reset-password-page", tags=["Authentication"])
async def reset_password_page(token: str, db: Session = Depends(get_db)):
    """
    Simule la page où l'on saisit le nouveau mot de passe
    """
    user = db.query(User).filter(User.reset_password_token == token).first()
    
    if not user:
        return {"status": "error", "message": "Token de réinitialisation invalide."}
        
    return {
        "status": "success",
        "message": f"Bonjour {user.full_name}, vous pouvez maintenant envoyer un POST vers /api/v1/auth/reset-password avec votre nouveau mot de passe."
    }

@app.post(
    "/api/v1/auth/reset-password",
    response_model=SuccessResponse,
    tags=["Authentication"]
)
async def reset_password(
    request: ResetPasswordRequest,
    db: Session = Depends(get_db)
):
    """
    Réinitialiser le mot de passe avec le token reçu par email
    
    - **token**: Token de réinitialisation
    - **new_password**: Nouveau mot de passe
    """
    
    # ============================================
    # 1. TROUVER L'UTILISATEUR PAR TOKEN
    # ============================================
    user = db.query(User).filter(
        User.reset_password_token == request.token
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "INVALID_TOKEN",
                "message": "Token de réinitialisation invalide ou déjà utilisé"
            }
        )
    
    # ============================================
    # 2. VÉRIFIER QUE LE TOKEN N'A PAS EXPIRÉ
    # ============================================
    if is_token_expired(user.token_expires_at):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "TOKEN_EXPIRED",
                "message": "Le token a expiré. Demandez un nouveau lien de réinitialisation."
            }
        )
    
    # ============================================
    # 3. METTRE À JOUR LE MOT DE PASSE
    # ============================================
    user.password_hash = hash_password(request.new_password)
    user.reset_password_token = None  # Invalider le token
    user.token_expires_at = None
    
    db.commit()
    
    # ============================================
    # 4. ENVOYER EMAIL DE CONFIRMATION
    # ============================================
    send_password_changed_confirmation(
        email=user.email,
        full_name=user.full_name
    )
    
    print(f"Mot de passe réinitialisé pour {user.email}")
    
    return SuccessResponse(
        status="success",
        message="Votre mot de passe a été réinitialisé avec succès. Vous pouvez maintenant vous connecter."
    )

# ============================================
# USER PROFILE ENDPOINTS
# ============================================

@app.get(
    "/api/v1/auth/me",
    response_model=UserProfileResponse,
    tags=["User Profile"]
)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Récupérer le profil complet de l'utilisateur connecté
    
    Nécessite un token JWT valide dans l'header Authorization
    
    Returns:
        - Informations utilisateur
        - Profil guide (si role = 'guide')
        - Statistiques (nombre de vues, réservations, etc.)
    """
    
    # ============================================
    # 1. PRÉPARER LES DONNÉES UTILISATEUR
    # ============================================
    user_data = UserResponse.from_orm(current_user)
    
    # ============================================
    # 2. SI GUIDE, RÉCUPÉRER LE PROFIL GUIDE
    # ============================================
    guide_profile = None
    stats = None
    
    if current_user.role == 'guide':
        guide = db.query(Guide).filter(Guide.user_id == current_user.id).first()
        if guide:
            guide_profile = GuideResponse.from_orm(guide)
            
            # ============================================
            # 3. CALCULER LES STATISTIQUES DU GUIDE
            # ============================================
            # TODO: Implémenter les vraies statistiques quand les tables existent
            stats = {
                "total_views": 0,  # TODO: Compter depuis table 'views'
                "upcoming_bookings": 0,  # TODO: Compter depuis table 'bookings'
                "completed_trips": 0,  # TODO: Compter depuis table 'trips'
                "total_earnings": 0.0,  # TODO: Calculer depuis table 'payments'
                "average_rating": 0.0,  # TODO: Calculer depuis table 'reviews'
                "profile_completion": _calculate_profile_completion(current_user, guide)
            }
    else:
        # ============================================
        # 4. STATISTIQUES POUR TOURISTE
        # ============================================
        stats = {
            "total_bookings": 0,  # TODO: Compter depuis table 'bookings'
            "upcoming_trips": 0,
            "completed_trips": 0,
            "favorite_guides": 0,  # TODO: Compter depuis table 'favorites'
            "total_spent": 0.0
        }
    
    return UserProfileResponse(
        user=user_data,
        guide_profile=guide_profile,
        stats=stats
    )


def _calculate_profile_completion(user: User, guide: Optional[Guide]) -> int:
    """
    Calcule le pourcentage de complétion du profil
    
    Args:
        user: Objet User
        guide: Objet Guide (si applicable)
        
    Returns:
        Pourcentage de complétion (0-100)
    """
    total_fields = 0
    completed_fields = 0
    
    # Champs utilisateur de base
    user_fields = {
        'full_name': user.full_name,
        'email': user.email,
        'phone': user.phone,
        'date_of_birth': user.date_of_birth,
        'is_email_verified': user.is_email_verified
    }
    
    total_fields += len(user_fields)
    completed_fields += sum(1 for v in user_fields.values() if v)
    
    # Si guide, ajouter les champs guide
    if guide:
        guide_fields = {
            'languages': guide.languages and len(guide.languages) > 0,
            'specialties': guide.specialties and len(guide.specialties) > 0,
            'cities_covered': guide.cities_covered and len(guide.cities_covered) > 0,
            'bio': guide.bio and len(guide.bio) >= 50,
            'is_verified': guide.is_verified,
            'has_official_license': guide.has_official_license
        }
        
        total_fields += len(guide_fields)
        completed_fields += sum(1 for v in guide_fields.values() if v)
    
    return int((completed_fields / total_fields) * 100) if total_fields > 0 else 0



# ============================================
# GUIDES ENDPOINTS (Pour tests)
# ============================================

@app.get(
    "/api/v1/guides",
    response_model=List[GuideResponse],
    tags=["Guides"]
)
async def get_all_guides(
    skip: int = 0,
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """
    Récupérer la liste de tous les guides (pour tester que les données sont bien insérées)
    """
    guides = db.query(Guide).offset(skip).limit(limit).all()
    return guides


# ============================================
# ERROR HANDLERS
# ============================================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Handler personnalisé pour les HTTPException"""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "status": "error",
            "error_code": exc.detail.get("error_code", "UNKNOWN_ERROR") if isinstance(exc.detail, dict) else "HTTP_ERROR",
            "message": exc.detail.get("message", str(exc.detail)) if isinstance(exc.detail, dict) else str(exc.detail),
            "details": exc.detail.get("details") if isinstance(exc.detail, dict) else None
        }
    )


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Handler global pour toutes les erreurs non gérées"""
    return JSONResponse(
        status_code=500,
        content={
            "status": "error",
            "error_code": "INTERNAL_SERVER_ERROR",
            "message": "Une erreur interne est survenue",
            "details": str(exc)
        }
    )


# ============================================
# MAIN (Pour exécution directe)
# ============================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )