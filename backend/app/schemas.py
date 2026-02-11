"""
Pydantic Schemas for Request/Response Validation
Définit la structure des données échangées avec le Frontend
"""

from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
import re


# ============================================
# SCHEMAS DE BASE
# ============================================

class PersonalInfo(BaseModel):
    """Informations personnelles communes à tous les utilisateurs"""
    full_name: str = Field(..., min_length=3, max_length=100)
    email: EmailStr
    phone: str
    date_of_birth: str  # Format: YYYY-MM-DD ou YYYY
    
    @validator('phone')
    def validate_phone(cls, v):
        """Valide le format du numéro de téléphone marocain"""
        # Nettoyer les espaces
        phone_clean = v.replace(' ', '').replace('-', '')
        
        # Accepter +212XXXXXXXXX ou 06XXXXXXXX
        if not re.match(r'^\+212[5-7]\d{8}$|^0[5-7]\d{8}$', phone_clean):
            raise ValueError('Format de téléphone invalide. Utilisez +212 6XX XX XX XX')
        return phone_clean
    
    @validator('date_of_birth')
    def validate_birth_year(cls, v):
        """Valide l'année de naissance"""
        # Si c'est juste une année (YYYY), la convertir en date complète
        if len(v) == 4 and v.isdigit():
            year = int(v)
            current_year = datetime.now().year
            if year < 1924 or year > current_year - 18:
                raise ValueError('Vous devez avoir au moins 18 ans')
            return f"{v}-01-01"
        
        # Sinon, valider le format YYYY-MM-DD
        if not re.match(r'^\d{4}-\d{2}-\d{2}$', v):
            raise ValueError('Format de date invalide. Utilisez YYYY-MM-DD ou YYYY')
        return v


class GuideDetails(BaseModel):
    """Informations spécifiques aux guides touristiques"""
    languages: List[str] = Field(..., min_items=1)
    specialties: List[str] = Field(..., min_items=1)
    cities_covered: List[str] = Field(..., min_items=1)
    years_of_experience: int = Field(..., ge=0)
    bio: str = Field(..., min_length=50, max_length=1000)
    
    @validator('specialties')
    def validate_specialties(cls, v):
        """Valide que les spécialités sont dans la liste autorisée"""
        allowed = ['nature', 'culture', 'aventure', 'gastronomie', 'histoire']
        for specialty in v:
            if specialty not in allowed:
                raise ValueError(f'Spécialité invalide: {specialty}. Choix autorisés: {allowed}')
        return v


# ============================================
# SCHEMAS D'INSCRIPTION
# ============================================

class UserRegistration(BaseModel):
    """Schema pour l'inscription d'un utilisateur"""
    personal_info: PersonalInfo
    role: str = Field(..., pattern='^(tourist|guide)$')
    password: str = Field(..., min_length=6)
    guide_details: Optional[GuideDetails] = None
    
    @validator('guide_details')
    def validate_guide_details(cls, v, values):
        """Vérifie que guide_details est fourni si role = 'guide'"""
        if 'role' in values and values['role'] == 'guide':
            if v is None:
                raise ValueError('Les détails du guide sont requis pour le rôle "guide"')
        return v


class UserLogin(BaseModel):
    """Schema pour la connexion d'un utilisateur"""
    email: EmailStr
    password: str


# ============================================
# SCHEMAS DE RÉPONSE
# ============================================

class UserResponse(BaseModel):
    """Informations utilisateur retournées après inscription/connexion"""
    id: str
    full_name: str
    email: str
    phone: Optional[str] = None
    role: str
    is_admin: bool  # Add this field
    is_active: bool
    is_email_verified: bool
    created_at: datetime
    
    class Config:
        from_attributes = True  # Permet de créer depuis un modèle SQLAlchemy


class GuideResponse(BaseModel):
    """Informations guide retournées"""
    id: str
    user_id: str
    languages: List[str]
    specialties: List[str]
    cities_covered: List[str]
    years_of_experience: int
    bio: str
    is_verified: bool
    eco_score: int
    approval_status: str
    rejection_reason: Optional[str] = None  # ✅ NOUVEAU
    profile_photo_url: Optional[str] = None
    license_card_url: Optional[str] = None
    cine_card_url: Optional[str] = None
    # ✅ NOUVEAU : champs ratings exposés dans GuideResponse
    average_rating: float = 0.0
    total_reviews: int = 0
    
    class Config:
        from_attributes = True

    @validator('profile_photo_url', 'license_card_url', 'cine_card_url', pre=True)
    def normalize_paths(cls, v):
        """Remplace les backslashes Windows par des slashes URL"""
        if v and isinstance(v, str):
            return v.replace('\\', '/')
        return v

class UserProfileResponse(BaseModel):
    """Profil complet de l'utilisateur avec données guide si applicable"""
    user: UserResponse
    guide_profile: Optional[GuideResponse] = None
    stats: Optional[dict] = None  # Statistiques dynamiques
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Réponse après connexion réussie"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class RegistrationResponse(BaseModel):
    """Réponse après inscription réussie"""
    status: str
    message: str
    user: UserResponse
    guide_profile: Optional[GuideResponse] = None


# ============================================
# SCHEMAS D'ERREUR
# ============================================

class ErrorResponse(BaseModel):
    """Format standardisé pour les erreurs"""
    status: str = "error"
    error_code: str
    message: str
    details: Optional[dict] = None



class ForgotPasswordRequest(BaseModel):
    """Demande de réinitialisation de mot de passe"""
    email: EmailStr

class ResetPasswordRequest(BaseModel):
    """Réinitialisation du mot de passe avec token"""
    token: str
    new_password: str = Field(..., min_length=6)
    
    @validator('new_password')
    def validate_password_strength(cls, v):
        """Vérifie la force du mot de passe"""
        if not any(c.isalpha() for c in v):
            raise ValueError('Le mot de passe doit contenir au moins une lettre')
        if not any(c.isdigit() for c in v):
            raise ValueError('Le mot de passe doit contenir au moins un chiffre')
        return v
    
class VerifyEmailRequest(BaseModel):
    """Vérification d'email avec token"""
    token: str


class ResendVerificationRequest(BaseModel):
    """Demande de renvoi d'email de vérification"""
    email: EmailStr


# ============================================
# SCHEMAS POUR LES ROUTES (TRAJETS)
# ============================================

class RouteCoordinate(BaseModel):
    """
    Coordonnée GPS d'un point du trajet
    Compatible avec le format Flutter/OSM
    """
    lat: float = Field(..., ge=-90, le=90, description="Latitude WGS84")
    lng: float = Field(..., ge=-180, le=180, description="Longitude WGS84")
    
    class Config:
        json_schema_extra = {
            "example": {
                "lat": 33.5731,
                "lng": -7.5898
            }
        }


class GuideRouteCreate(BaseModel):
    """
    Schema pour créer un nouveau trajet de guide
    Reçu depuis le frontend Flutter
    """
    coordinates: List[RouteCoordinate] = Field(
        ..., 
        min_items=2,
        description="Liste des points du trajet (minimum 2 points)"
    )
    start_point: RouteCoordinate = Field(..., description="Point de départ")
    end_point: RouteCoordinate = Field(..., description="Point d'arrivée")
    distance: float = Field(..., gt=0, description="Distance totale en kilomètres")
    duration: float = Field(..., gt=0, description="Durée estimée en minutes")
    start_address: Optional[str] = Field(None, max_length=500, description="Adresse de départ")
    end_address: Optional[str] = Field(None, max_length=500, description="Adresse d'arrivée")
    
    @validator('coordinates')
    def validate_coordinates(cls, v):
        """Valide que le trajet a suffisamment de points"""
        if len(v) < 2:
            raise ValueError('Un trajet doit avoir au moins 2 points (départ et arrivée)')
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "coordinates": [
                    {"lat": 33.5731, "lng": -7.5898},
                    {"lat": 33.5800, "lng": -7.5950},
                    {"lat": 33.5850, "lng": -7.6000}
                ],
                "start_point": {"lat": 33.5731, "lng": -7.5898},
                "end_point": {"lat": 33.5850, "lng": -7.6000},
                "distance": 2.5,
                "duration": 15.0,
                "start_address": "Casa Voyageurs, Casablanca",
                "end_address": "Mosquée Hassan II, Casablanca"
            }
        }


class GuideRouteResponse(BaseModel):
    """
    Schema de réponse pour un trajet de guide
    Envoyé vers le frontend Flutter
    """
    id: str
    guide_id: str
    coordinates: List[dict]  # Liste de {lat, lng}
    distance: float
    duration: float
    start_address: Optional[str] = None
    end_address: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True
        json_schema_extra = {
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "guide_id": "guide_123",
                "coordinates": [
                    {"lat": 33.5731, "lng": -7.5898},
                    {"lat": 33.5800, "lng": -7.5950}
                ],
                "distance": 2.5,
                "duration": 15.0,
                "start_address": "Casa Voyageurs, Casablanca",
                "end_address": "Mosquée Hassan II, Casablanca",
                "is_active": True,
                "created_at": "2024-01-15T10:30:00Z",
                "updated_at": "2024-01-15T10:30:00Z"
            }
        }
# ============================================
# SCHEMAS ADMIN - REJET DE GUIDE
# ============================================

class GuideRejection(BaseModel):
    """Schema pour rejeter un guide avec un motif"""
    reason: str = Field(
        ..., 
        min_length=10, 
        max_length=500,
        description="Motif du rejet (minimum 10 caractères)"
    )
    
    class Config:
        json_schema_extra = {
            "example": {
                "reason": "Les documents fournis ne sont pas suffisamment lisibles. Veuillez soumettre des photos de meilleure qualité."
            }
        }


# ============================================
# SCHEMAS SUPPORT TECHNIQUE
# ============================================

class SupportMessageCreate(BaseModel):
    """Schema pour créer un message de support"""
    subject: str = Field(..., min_length=5, max_length=200)
    message: str = Field(..., min_length=10, max_length=2000)
    
    class Config:
        json_schema_extra = {
            "example": {
                "subject": "Problème de connexion",
                "message": "Je n'arrive pas à me connecter à mon compte malgré un mot de passe correct."
            }
        }


class SupportMessageResponse(BaseModel):
    """Schema de réponse pour un message de support"""
    id: str
    user_id: str
    user_name: str  # Nom de l'utilisateur
    user_email: str  # Email de l'utilisateur
    subject: str
    message: str
    is_resolved: bool
    created_at: datetime
    resolved_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# ============================================
# ✅ SCHEMAS DE RECHERCHE
# ============================================

class SearchGuideResponse(BaseModel):
    """
    Réponse de recherche de guide (endpoint /search/guides).
    Retourne un objet 'user' et un objet 'guide' imbriqués.
    """
    user: UserResponse
    guide: GuideResponse

    class Config:
        from_attributes = True


class ActiveRouteInfo(BaseModel):
    """
    Informations condensées du trajet actif d'un guide.
    Incluses dans SearchRouteResponse pour un affichage rapide sur la carte.
    """
    route_id: str
    distance: float               # Distance totale en kilomètres
    duration: float               # Durée estimée en minutes
    start_address: Optional[str] = None
    end_address: Optional[str] = None
    coordinates_count: int = 0    # Nombre de points GPS (indicateur de complexité)


class SearchRouteResponse(BaseModel):
    """
    ✅ NOUVEAU - Réponse de recherche guide + trajet actif (endpoint /search/guides-with-routes).

    Structure plate (pas d'imbrication user/guide) pour un parsing Flutter simplifié.
    Le champ 'active_route' est None si le guide n'a pas encore créé de trajet.

    Exemple JSON retourné :
    {
        "user_id": "abc",
        "guide_id": "xyz",
        "full_name": "Hassan Amrani",
        "profile_photo_url": "/uploads/profiles/hassan.jpg",
        "languages": ["Arabe", "Français"],
        "specialties": ["nature", "culture"],
        "cities_covered": ["Marrakech"],
        "years_of_experience": 8,
        "bio": "Guide expérimenté...",
        "is_verified": true,
        "eco_score": 82,
        "average_rating": 4.7,
        "total_reviews": 34,
        "active_route": {
            "route_id": "r1",
            "distance": 5.2,
            "duration": 90.0,
            "start_address": "Place Jemaa el-Fna",
            "end_address": "Jardin Majorelle",
            "coordinates_count": 47
        }
    }
    """
    # ─── Identité ───────────────────────────────
    user_id: str
    guide_id: str
    full_name: str
    profile_photo_url: Optional[str] = None

    # ─── Informations professionnelles ──────────
    languages: List[str]
    specialties: List[str]
    cities_covered: List[str]
    years_of_experience: int
    bio: str
    is_verified: bool

    # ─── Scores ─────────────────────────────────
    eco_score: int
    average_rating: float = 0.0
    total_reviews: int = 0

    # ─── Trajet actif ────────────────────────────
    active_route: Optional[ActiveRouteInfo] = None  # None = pas de trajet encore

    class Config:
        from_attributes = True

    @validator('profile_photo_url', pre=True)
    def normalize_photo(cls, v):
        if v and isinstance(v, str):
            return v.replace('\\', '/')
        return v


class SuccessResponse(BaseModel):
    """Réponse de succès générique"""
    status: str = "success"
    message: str
    data: Optional[dict] = None


