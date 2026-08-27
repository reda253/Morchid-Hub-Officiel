"""
Configuration Management for Morchid Hub Backend
Gère toutes les variables d'environnement et les paramètres de l'application
"""

from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """
    Classe de configuration qui charge automatiquement les variables depuis .env
    """
    
    # ============================================
    # DATABASE
    # ============================================
    DATABASE_URL: str
    
    # ============================================
    # SECURITY
    # ============================================
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 jours (révocable via token_version)
    
    # ============================================
    # SERVER
    # ============================================
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = False
    
    # ============================================
    # CORS
    # ============================================
    CORS_ORIGINS: str = "http://localhost:3000"
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Convertit la string CORS_ORIGINS en liste"""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    # ============================================
    # ADMIN
    # ============================================
    # Liste blanche des emails administrateurs (source de vérité unique).
    # Vide par défaut : aucun compte n'est administrateur tant que la variable
    # n'est pas renseignée (fail closed).
    ADMIN_EMAILS: str = ""

    @property
    def admin_emails_list(self) -> List[str]:
        """Convertit la string ADMIN_EMAILS en liste d'emails normalisés (minuscules)"""
        return [
            email.strip().lower()
            for email in self.ADMIN_EMAILS.split(",")
            if email.strip()
        ]

    # ============================================
    # PROJECT INFO
    # ============================================
    PROJECT_NAME: str = "Morchid Hub API"
    VERSION: str = "1.0.0"
    DESCRIPTION: str = "API pour la plateforme de tourisme durable au Maroc"
    
    class Config:
        env_file = ".env"
        case_sensitive = True


# Instance globale des settings
settings = Settings()