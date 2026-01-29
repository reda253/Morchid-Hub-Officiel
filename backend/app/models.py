"""
SQLAlchemy Database Models
Définit la structure des tables PostgreSQL
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, JSON
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime
import uuid

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
    
    # Métadonnées
    approval_status = Column(String(20), default='pending_approval')  # pending_approval, approved, rejected
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relation inverse avec User
    user = relationship("User", back_populates="guide_profile")
    
    def __repr__(self):
        return f"<Guide(id={self.id}, user_id={self.user_id}, is_verified={self.is_verified})>"