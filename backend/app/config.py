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
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 43200  # 30 jours
    
    # ============================================
    # SERVER
    # ============================================
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = True
    
    # ============================================
    # CORS
    # ============================================
    CORS_ORIGINS: str = "http://localhost:3000"
    
    @property
    def cors_origins_list(self) -> List[str]:
        """Convertit la string CORS_ORIGINS en liste"""
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]
    
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