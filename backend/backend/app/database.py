"""
Database Configuration and Session Management
Gère la connexion à PostgreSQL avec SQLAlchemy
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import settings

# ============================================
# CONFIGURATION DU MOTEUR DE BASE DE DONNÉES
# ============================================

# Créer l'engine PostgreSQL
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,  # Vérifie la connexion avant chaque requête
    echo=settings.DEBUG,  # Log les requêtes SQL en mode debug
)

# Créer une SessionLocal class
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base pour les modèles SQLAlchemy
Base = declarative_base()


# ============================================
# DEPENDENCY INJECTION
# ============================================

def get_db():
    """
    Générateur de session de base de données pour FastAPI
    Usage:
        @app.get("/items")
        def read_items(db: Session = Depends(get_db)):
            ...
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ============================================
# INITIALISATION DES TABLES
# ============================================

def init_db():
    """
    Crée toutes les tables dans la base de données
    À appeler au démarrage de l'application
    """
    Base.metadata.create_all(bind=engine)