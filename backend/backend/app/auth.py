"""
Authentication & Security Utilities
Gère le hachage des mots de passe et la génération de tokens JWT
"""

from passlib.context import CryptContext
from jose import JWTError, jwt
from datetime import datetime, timedelta
from typing import Optional
from .config import settings

# ============================================
# PASSWORD HASHING
# ============================================

# Contexte pour le hachage bcrypt
# Contexte pour le hachage bcrypt
pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


def hash_password(password: str) -> str:
    """
    Hash un mot de passe en utilisant bcrypt
    
    Args:
        password: Le mot de passe en clair
        
    Returns:
        Le hash bcrypt du mot de passe
    """
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """
    Vérifie qu'un mot de passe correspond à son hash
    
    Args:
        plain_password: Le mot de passe en clair à vérifier
        hashed_password: Le hash stocké en base de données
        
    Returns:
        True si le mot de passe est correct, False sinon
    """
    return pwd_context.verify(plain_password, hashed_password)


# ============================================
# JWT TOKEN MANAGEMENT
# ============================================

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """
    Crée un token JWT pour l'authentification
    
    Args:
        data: Les données à encoder dans le token (généralement user_id et email)
        expires_delta: Durée de validité du token (optionnel)
        
    Returns:
        Le token JWT encodé
    """
    to_encode = data.copy()
    
    # Définir l'expiration
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    
    # Encoder le token
    encoded_jwt = jwt.encode(
        to_encode,
        settings.SECRET_KEY,
        algorithm=settings.ALGORITHM
    )
    
    return encoded_jwt


def decode_access_token(token: str) -> Optional[dict]:
    """
    Décode et vérifie un token JWT
    
    Args:
        token: Le token JWT à décoder
        
    Returns:
        Les données décodées du token, ou None si invalide
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        return None


# ============================================
# VALIDATION DES CREDENTIALS
# ============================================

def validate_password_strength(password: str) -> tuple[bool, str]:
    """
    Valide la force d'un mot de passe
    
    Args:
        password: Le mot de passe à valider
        
    Returns:
        (is_valid, message)
    """
    if len(password) < 6:
        return False, "Le mot de passe doit contenir au moins 6 caractères"
    
    # Vérifier qu'il contient au moins une lettre et un chiffre
    has_letter = any(c.isalpha() for c in password)
    has_digit = any(c.isdigit() for c in password)
    
    if not (has_letter and has_digit):
        return False, "Le mot de passe doit contenir des lettres et des chiffres"
    
    return True, "Mot de passe valide"