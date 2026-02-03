"""
SQLAlchemy Database Models
Définit la structure des tables PostgreSQL
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, JSON, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import uuid
from geoalchemy2 import Geometry
from .database import Base


def generate_uuid():
    """Génère un UUID v4 unique"""
    return str(uuid.uuid4())


# ============================================
# TABLE USERS (Tous les utilisateurs)
# ============================================

class User(Base):
    __tablename__ = "users"
    
    # Colonnes principales
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    full_name = Column(String(100), nullable=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    phone = Column(String(20), nullable=True)
    # Change String(10) en String(255) temporairement pour tester
    date_of_birth = Column(String(255), nullable=True)
    password_hash = Column(String(255), nullable=True)
    role = Column(String(20), nullable=True ) # 'tourist' ou 'guide'

    # Sécurité et vérification
    is_email_verified = Column(Boolean, default=False, nullable=False)
    verification_token = Column(String(255), nullable=True, index=True)
    reset_password_token = Column(String(255), nullable=True, index=True)
    token_expires_at = Column(DateTime(timezone=True), nullable=True)
    
    # Métadonnées
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relation avec la table guides (si role = 'guide')
    guide_profile = relationship("Guide", back_populates="user", uselist=False, cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(id={self.id}, email={self.email}, role={self.role})>"


# ============================================
# TABLE GUIDES (Informations supplémentaires pour les guides)
# ============================================

class Guide(Base):
    __tablename__ = "guides"
    
    # Clé primaire
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    
    # Informations professionnelles
    languages = Column(JSON, nullable=False)  # ['Arabe', 'Français', 'Anglais']
    specialties = Column(JSON, nullable=False)  # ['nature', 'culture', 'history']
    cities_covered = Column(JSON, nullable=False)  # ['Marrakech', 'Fès']
    years_of_experience = Column(Integer, nullable=False, default=0)
    bio = Column(Text, nullable=False)
    
    # Vérification et statut
    is_verified = Column(Boolean, default=False, nullable=False)  
    eco_score = Column(Integer, default=0, nullable=False)  # Score écologique (0-100)
    
    # Certifications
    has_official_license = Column(Boolean, default=False)
    license_number = Column(String(50), nullable=True)
    
    # NFC Data (pour vérification future)
    cine_number = Column(String(20), nullable=True)

    profile_photo_url = Column(Text, nullable=True)  # Chemin vers la photo de profil
    license_card_url = Column(Text, nullable=True)   # Chemin vers la photo de la licence
    cine_card_url = Column(Text, nullable=True)      # Chemin vers la photo de la CINE
    
    # Métadonnées
    approval_status = Column(String(20), default='pending_approval')  # pending_approval, approved, rejected
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relation inverse avec User
    user = relationship("User", back_populates="guide_profile")
    routes = relationship("GuideRoute", back_populates="guide", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<Guide(id={self.id}, user_id={self.user_id}, is_verified={self.is_verified})>"
    


class GuideRoute(Base):
    __tablename__ = "guide_routes"
    
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    guide_id = Column(String, ForeignKey("guides.id", on_delete="CASCADE"), nullable=False, index=True)
    
    # Coordonnées stockées en JSON
    route_line = Column(
        Geometry(geometry_type='LINESTRING', srid=4326),
        nullable=False,
        index=True  # Index spatial pour requêtes géographiques rapides
    )
    
    # Points de départ et arrivée (POINT avec coordonnées WGS84)
    start_point = Column(
        Geometry(geometry_type='POINT', srid=4326),
        nullable=False,
        index=True
    )
    
    end_point = Column(
        Geometry(geometry_type='POINT', srid=4326),
        nullable=False,
        index=True
    )
    coordinates = Column(JSON, nullable=False)
    
    
    
    distance = Column(Float, nullable=False)
    duration = Column(Float, nullable=False)
    start_address = Column(Text, nullable=True)
    end_address = Column(Text, nullable=True)
    
    is_active = Column(Boolean, default=True, nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    guide = relationship("Guide", back_populates="routes")

    def __repr__(self):
        return f"<GuideRoute(id={self.id}, guide_id={self.guide_id}, distance={self.distance}km, is_active={self.is_active})>"
    
    # ============================================
    # MÉTHODES UTILITAIRES
    # ============================================
    
    def to_dict(self):
        """Convertit le modèle en dictionnaire pour la réponse API"""
        return {
            'id': self.id,
            'guide_id': self.guide_id,
            'coordinates': self.coordinates,
            'distance': self.distance,
            'duration': self.duration,
            'start_address': self.start_address,
            'end_address': self.end_address,
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }