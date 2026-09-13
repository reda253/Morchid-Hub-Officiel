"""
Database Configuration and Session Management
Gère la connexion à PostgreSQL avec SQLAlchemy
"""

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import settings
from .db_url import build_engine_config

# ============================================
# CONFIGURATION DU MOTEUR DE BASE DE DONNÉES
# ============================================

# L'URL passe par build_engine_config : une URL managée (Neon) porte
# `?sslmode=require`, que pg8000 refuse tel quel.
_engine_url, _connect_args = build_engine_config(settings.DATABASE_URL)

# Créer l'engine PostgreSQL
engine = create_engine(
    _engine_url,
    connect_args=_connect_args,
    pool_pre_ping=True,  # Vérifie la connexion avant chaque requête (Neon suspend les connexions inactives)
    echo=False,  # Log les requêtes SQL en mode debug
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