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
    ErrorResponse
)
from .auth import hash_password, verify_password, create_access_token

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
    # 4. CRÉER L'UTILISATEUR
    # ============================================
    new_user = User(
        full_name=user_data.personal_info.full_name,
        email=user_data.personal_info.email,
        phone=user_data.personal_info.phone,
        date_of_birth=user_data.personal_info.date_of_birth,
        password_hash=password_hash,
        role=user_data.role,
        is_active=True
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
    response_message = (
        "Inscription réussie ! Vérifiez votre email pour compléter la vérification NFC."
        if user_data.role == 'guide'
        else "Bienvenue sur Morchid Hub !"
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