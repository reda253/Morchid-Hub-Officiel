"""
Morchid Hub Backend API
FastAPI application with PostgreSQL integration
"""

from fastapi import FastAPI, Depends, HTTPException, status, Request, File, UploadFile, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from geoalchemy2.shape import to_shape, from_shape
from sqlalchemy.sql import func
from shapely.geometry import Point, LineString
from typing import List, Optional
import os
import uuid
import shutil
from pathlib import Path
from .admin import router as admin_router
from .search import router as search_router  # ligne ~19
from .reviews import router as reviews_router




from .config import settings
from .database import get_db, init_db, engine
from .models import User, Guide, Base, GuideRoute
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
    SuccessResponse,
    GuideRouteCreate, 
    GuideRouteResponse
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

app.include_router(search_router)            # ligne ~69
# ============================================
# ✅ AJOUT POUR ADMIN - LIGNE À AJOUTER
# Inclure le router admin APRÈS la création de l'app
# ============================================
app.include_router(admin_router)

app.include_router(reviews_router)


# ============================================
# UPLOADS DIRECTORY CONFIGURATION
# ============================================

# Créer le dossier uploads s'il n'existe pas
# Utiliser un chemin absolu basé sur l'emplacement de main.py (backend/app/main.py -> backend/uploads)
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

# Sous-dossiers pour organisation
PROFILE_DIR = UPLOAD_DIR / "profiles"
LICENSE_DIR = UPLOAD_DIR / "licenses"
CINE_DIR = UPLOAD_DIR / "cines"

PROFILE_DIR.mkdir(exist_ok=True)
LICENSE_DIR.mkdir(exist_ok=True)
CINE_DIR.mkdir(exist_ok=True)

# Servir les fichiers statiques
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")



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
    print(f"Dossier uploads créé: {UPLOAD_DIR.absolute()}")


# ============================================
# HEALTH CHECK ENDPOINT
# ============================================@

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
        is_admin=False,  # Set default to False for new registrations
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

    print(f"[OK] Connexion reussie pour {user.email}")
    
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

    print(f"[OK] Email verifie pour {user.email}")
    
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
                "profile_completion": _calculate_profile_completion(current_user, guide),
                "total_bookings": 0,
                "total_revenue": 0,
                "total_reviews": 0
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
            "total_spent": 0.0,
            "favorites": 0
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
            'has_official_license': guide.has_official_license,
            'profile_photo_url': guide.profile_photo_url is not None,
            'license_card_url': guide.license_card_url is not None,
            'cine_card_url': guide.cine_card_url is not None
        }
        
        total_fields += len(guide_fields)
        completed_fields += sum(1 for v in guide_fields.values() if v)
    
    return int((completed_fields / total_fields) * 100) if total_fields > 0 else 0


# ============================================
# GUIDE VERIFICATION ENDPOINT (NOUVEAU)
# ============================================

def save_upload_file(upload_file: UploadFile, destination: Path) -> str:
    """
    Sauvegarde un fichier uploadé avec un nom unique
    
    Args:
        upload_file: Fichier uploadé
        destination: Dossier de destination
        
    Returns:
        Chemin relatif du fichier sauvegardé
    """
    # Générer un nom unique
    file_extension = os.path.splitext(upload_file.filename)[1]
    unique_filename = f"{uuid.uuid4()}{file_extension}"
    file_path = destination / unique_filename
    
    # Sauvegarder le fichier
    with file_path.open("wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)
    
    # Retourner le chemin relatif
    return str(file_path.relative_to(Path("."))).replace(os.path.sep, "/")


@app.post(
    "/api/v1/auth/verify-guide",
    response_model=SuccessResponse,
    tags=["Guide Verification"]
)
async def verify_guide_identity(
    cine_number: str = Form(...),
    license_number: str = Form(...),
    profile_photo: UploadFile = File(...),
    license_photo: UploadFile = File(...),
    cine_photo: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Soumettre les documents d'identité pour vérification du guide
    
    - **cine_number**: Numéro de carte d'identité nationale (CINE)
    - **license_number**: Numéro de licence de guide touristique
    - **profile_photo**: Photo de profil du guide
    - **license_photo**: Photo de la licence de guide
    - **cine_photo**: Photo de la carte CINE
    
    Nécessite une authentification (guide seulement)
    """
    
    # ============================================
    # 1. VÉRIFIER QUE L'UTILISATEUR EST UN GUIDE
    # ============================================
    if current_user.role != 'guide':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "NOT_A_GUIDE",
                "message": "Seuls les guides peuvent soumettre des documents de vérification"
            }
        )
    
    # ============================================
    # 2. RÉCUPÉRER LE PROFIL GUIDE
    # ============================================
    guide = db.query(Guide).filter(Guide.user_id == current_user.id).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_PROFILE_NOT_FOUND",
                "message": "Profil guide non trouvé"
            }
        )
    
    # ============================================
    # 3. VÉRIFIER QUE LE GUIDE N'EST PAS DÉJÀ VÉRIFIÉ
    # ============================================
    if guide.is_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "ALREADY_VERIFIED",
                "message": "Votre compte est déjà vérifié"
            }
        )
    
    # ============================================
    # 4. VALIDER LES FORMATS DE FICHIERS
    # ============================================
    allowed_extensions = {'.jpg', '.jpeg', '.png', '.webp'}
    
    for file in [profile_photo, license_photo, cine_photo]:
        file_ext = os.path.splitext(file.filename)[1].lower()
        if file_ext not in allowed_extensions:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={
                    "error_code": "INVALID_FILE_FORMAT",
                    "message": f"Format de fichier non supporté: {file.filename}. Utilisez JPG, PNG ou WEBP."
                }
            )
    
    # ============================================
    # 5. SAUVEGARDER LES FICHIERS
    # ============================================
    try:
        # Photo de profil
        profile_photo_path = save_upload_file(profile_photo, PROFILE_DIR)
        
        # Photo de licence
        license_photo_path = save_upload_file(license_photo, LICENSE_DIR)
        
        # Photo CINE
        cine_photo_path = save_upload_file(cine_photo, CINE_DIR)
        
        print(f"[OK] Fichiers sauvegardes:")
        print(f"   - Profil: {profile_photo_path}")
        print(f"   - Licence: {license_photo_path}")
        print(f"   - CINE: {cine_photo_path}")
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error_code": "FILE_SAVE_ERROR",
                "message": f"Erreur lors de la sauvegarde des fichiers: {str(e)}"
            }
        )
    
    # ============================================
    # 6. METTRE À JOUR LE PROFIL GUIDE
    # ============================================
    try:
        guide.cine_number = cine_number
        guide.license_number = license_number
        guide.profile_photo_url = profile_photo_path
        guide.license_card_url = license_photo_path
        guide.cine_card_url = cine_photo_path
        guide.has_official_license = True
        guide.approval_status = 'pending_review'  # Passer en révision
        
        db.commit()
        db.refresh(guide)
        
        print(f"[OK] Profil guide mis a jour pour {current_user.full_name}")
        print(f"   - CINE: {cine_number}")
        print(f"   - Licence: {license_number}")
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error_code": "DATABASE_ERROR",
                "message": f"Erreur lors de la mise à jour: {str(e)}"
            }
        )
    
    # ============================================
    # 7. RETOURNER LA RÉPONSE
    # ============================================
    return SuccessResponse(
        status="success",
        message="Documents reçus ! Votre profil sera certifié sous 12h.",
        data={
            "guide_id": guide.id,
            "approval_status": guide.approval_status,
            "cine_number": cine_number,
            "license_number": license_number,
            "profile_photo_url": f"/{profile_photo_path}",
            "license_photo_url": f"/{license_photo_path}",
            "cine_photo_url": f"/{cine_photo_path}"
        }
    )




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
# GUIDE ROUTES ENDPOINTS (NOUVEAU)
# ============================================

@app.post(
    "/api/v1/guides/routes",
    response_model=GuideRouteResponse,
    status_code=status.HTTP_201_CREATED,
    tags=["Guide Routes"]
)
async def save_guide_route(
    route_data: GuideRouteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Sauvegarder un nouveau trajet pour un guide
    
    - Seuls les guides authentifiés peuvent créer des trajets
    - Un seul trajet actif par guide (les anciens sont désactivés)
    - Utilise PostGIS pour stocker les données géospatiales
    """
    
    # ============================================
    # 1. VÉRIFIER QUE L'UTILISATEUR EST UN GUIDE
    # ============================================
    if current_user.role != 'guide':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "NOT_A_GUIDE",
                "message": "Seuls les guides peuvent créer des trajets"
            }
        )
    
    # ============================================
    # 2. RÉCUPÉRER LE PROFIL GUIDE
    # ============================================
    guide = db.query(Guide).filter(Guide.user_id == current_user.id).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_PROFILE_NOT_FOUND",
                "message": "Profil guide non trouvé"
            }
        )
    
    # ============================================
    # 3. DÉSACTIVER L'ANCIEN TRAJET (UN SEUL ACTIF)
    # ============================================
    db.query(GuideRoute).filter(
        GuideRoute.guide_id == guide.id,
        GuideRoute.is_active == True
    ).update({"is_active": False})
    
    # ============================================
    # 4. CRÉER LES OBJETS GÉOMÉTRIQUES POSTGIS
    # ============================================
    try:
        # Point de départ
        start_point = Point(route_data.start_point.lng, route_data.start_point.lat)
        
        # Point d'arrivée
        end_point = Point(route_data.end_point.lng, route_data.end_point.lat)
        
        # Ligne du trajet complet
        route_coords = [(coord.lng, coord.lat) for coord in route_data.coordinates]
        route_line = LineString(route_coords)
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={
                "error_code": "INVALID_GEOMETRY",
                "message": f"Données géométriques invalides: {str(e)}"
            }
        )
    
    # ============================================
    # 5. CRÉER LE NOUVEAU TRAJET
    # ============================================
    try:
        new_route = GuideRoute(
            guide_id=guide.id,
            route_line=from_shape(route_line, srid=4326),
            start_point=from_shape(start_point, srid=4326),
            end_point=from_shape(end_point, srid=4326),
            coordinates=[{"lat": c.lat, "lng": c.lng} for c in route_data.coordinates],
            distance=route_data.distance,
            duration=route_data.duration,
            start_address=route_data.start_address,
            end_address=route_data.end_address,
            is_active=True
        )
        
        db.add(new_route)
        db.commit()
        db.refresh(new_route)
        
        print(f"[OK] Trajet sauvegarde pour le guide {guide.id}")
        print(f"   - Distance: {route_data.distance} km")
        print(f"   - Durée: {route_data.duration} min")
        print(f"   - Points: {len(route_data.coordinates)}")
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "error_code": "SAVE_ERROR",
                "message": f"Erreur lors de la sauvegarde: {str(e)}"
            }
        )
    
    # ============================================
    # 6. RETOURNER LA RÉPONSE
    # ============================================
    return GuideRouteResponse(
        id=new_route.id,
        guide_id=new_route.guide_id,
        coordinates=new_route.coordinates,
        distance=new_route.distance,
        duration=new_route.duration,
        start_address=new_route.start_address,
        end_address=new_route.end_address,
        is_active=new_route.is_active,
        created_at=new_route.created_at,
        updated_at=new_route.updated_at
    )


@app.get(
    "/api/v1/guides/{guide_id}/route",
    response_model=GuideRouteResponse,
    tags=["Guide Routes"]
)
async def get_guide_route(
    guide_id: str,
    db: Session = Depends(get_db)
):
    """
    Récupérer le trajet actif d'un guide spécifique
    
    - Retourne le trajet avec is_active = True
    - Accessible publiquement (pour que les touristes voient les trajets)
    """
    
    # ============================================
    # 1. VÉRIFIER QUE LE GUIDE EXISTE
    # ============================================
    guide = db.query(Guide).filter(Guide.id == guide_id).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "GUIDE_NOT_FOUND",
                "message": "Guide non trouvé"
            }
        )
    
    # ============================================
    # 2. RÉCUPÉRER LE TRAJET ACTIF
    # ============================================
    route = db.query(GuideRoute).filter(
        GuideRoute.guide_id == guide_id,
        GuideRoute.is_active == True
    ).first()
    
    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "NO_ACTIVE_ROUTE",
                "message": "Aucun trajet actif pour ce guide"
            }
        )
    
    # ============================================
    # 3. RETOURNER LE TRAJET
    # ============================================
    return GuideRouteResponse(
        id=route.id,
        guide_id=route.guide_id,
        coordinates=route.coordinates,
        distance=route.distance,
        duration=route.duration,
        start_address=route.start_address,
        end_address=route.end_address,
        is_active=route.is_active,
        created_at=route.created_at,
        updated_at=route.updated_at
    )


@app.get(
    "/api/v1/guides/{guide_id}/routes/history",
    response_model=List[GuideRouteResponse],
    tags=["Guide Routes"]
)
async def get_guide_routes_history(
    guide_id: str,
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Récupérer l'historique des trajets d'un guide
    
    - Accessible uniquement par le guide lui-même
    - Retourne les 10 derniers trajets (actifs et inactifs)
    """
    
    # Vérifier que l'utilisateur est le guide concerné
    guide = db.query(Guide).filter(
        Guide.id == guide_id,
        Guide.user_id == current_user.id
    ).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "Vous ne pouvez voir que vos propres trajets"
            }
        )
    
    # Récupérer l'historique
    routes = db.query(GuideRoute).filter(
        GuideRoute.guide_id == guide_id
    ).order_by(GuideRoute.created_at.desc()).limit(limit).all()
    
    return [
        GuideRouteResponse(
            id=route.id,
            guide_id=route.guide_id,
            coordinates=route.coordinates,
            distance=route.distance,
            duration=route.duration,
            start_address=route.start_address,
            end_address=route.end_address,
            is_active=route.is_active,
            created_at=route.created_at,
            updated_at=route.updated_at
        )
        for route in routes
    ]


@app.delete(
    "/api/v1/guides/routes/{route_id}",
    response_model=SuccessResponse,
    tags=["Guide Routes"]
)
async def delete_guide_route(
    route_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Supprimer un trajet spécifique
    
    - Accessible uniquement par le guide propriétaire
    """
    
    # Récupérer le trajet
    route = db.query(GuideRoute).filter(GuideRoute.id == route_id).first()
    
    if not route:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={
                "error_code": "ROUTE_NOT_FOUND",
                "message": "Trajet non trouvé"
            }
        )
    
    # Vérifier que l'utilisateur est le propriétaire
    guide = db.query(Guide).filter(
        Guide.id == route.guide_id,
        Guide.user_id == current_user.id
    ).first()
    
    if not guide:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={
                "error_code": "UNAUTHORIZED",
                "message": "Vous ne pouvez supprimer que vos propres trajets"
            }
        )
    
    # Supprimer le trajet
    db.delete(route)
    db.commit()
    
    return SuccessResponse(
        status="success",
        message="Trajet supprimé avec succès",
        data={"route_id": route_id}
    )

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