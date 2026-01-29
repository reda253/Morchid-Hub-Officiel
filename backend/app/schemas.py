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
    phone: str
    role: str
    is_active: bool
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