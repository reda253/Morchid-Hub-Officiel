"""
SQLAlchemy Database Models
Définit la structure des tables PostgreSQL
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text, JSON, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime, timezone
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
    is_admin = Column(Boolean, default=False, nullable=False) #

    # Sécurité et vérification
    is_email_verified = Column(Boolean, default=False, nullable=False)
    verification_token = Column(String(255), nullable=True, index=True)
    reset_password_token = Column(String(255), nullable=True, index=True)
    # Deux expirations distinctes : une seule colonne partagée faisait que
    # demander un reset de mot de passe re-datait le lien de vérification.
    verification_token_expires_at = Column(DateTime(timezone=True), nullable=True)
    reset_token_expires_at = Column(DateTime(timezone=True), nullable=True)

    # Incrémenté pour révoquer toutes les sessions d'un utilisateur.
    token_version = Column(Integer, nullable=False, default=0, server_default="0")
    
    # Métadonnées
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relation avec la table guides (si role = 'guide')
    guide_profile = relationship("Guide", back_populates="user", uselist=False, cascade="all, delete-orphan")
    support_messages = relationship("SupportMessage", back_populates="user", cascade="all, delete-orphan")
    reviews_given    = relationship("Review",         back_populates="tourist",        cascade="all, delete-orphan",
                                    foreign_keys="Review.tourist_id")

    
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

    # ✅ NOUVEAU : Classement et avis
    average_rating = Column(Float, default=0.0, nullable=False)   # Note moyenne (0.0 - 5.0)
    total_reviews = Column(Integer, default=0, nullable=False)     # Nombre total d'avis
    
    # Certifications
    has_official_license = Column(Boolean, default=False)
    license_number = Column(String(50), nullable=True)
    
    # NFC Data (pour vérification future)
    cine_number = Column(String(20), nullable=True)

    profile_photo_url = Column(Text, nullable=True)  # Chemin vers la photo de profil
    license_card_url = Column(Text, nullable=True)   # Chemin vers la photo de la licence
    cine_card_url = Column(Text, nullable=True)      # Chemin vers la photo de la CINE

    is_premium = Column(Boolean, default=False, nullable=False, index=True)
    premium_until = Column(DateTime(timezone=True), nullable=True)  # Date d'expiration
    
    # Métadonnées
    # RG14 (UML étape 12) : statut unique `pending` — le sous-état "documents
    # soumis" est dérivé (has_official_license), plus de `pending_review`.
    approval_status = Column(String(20), default='pending')  # pending, approved, rejected
    rejection_reason = Column(Text, nullable=True)  # ✅ NOUVEAU : Motif de rejet

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relation inverse avec User
    user = relationship("User", back_populates="guide_profile")
    routes = relationship("GuideRoute", back_populates="guide", cascade="all, delete-orphan")
    reviews = relationship("Review",     back_populates="guide",   cascade="all, delete-orphan")
    subscriptions = relationship("Subscription", back_populates="guide", cascade="all, delete-orphan")
     # ------------------------------------------------------------------
    # Méthode utilitaire appelée dans reviews.py après chaque INSERT/DELETE
    # ------------------------------------------------------------------
    def refresh_rating_stats(self, db_session) -> None:
        """
        Recalcule average_rating et total_reviews en interrogeant directement
        la BDD — thread-safe même sous charge concurrente.

        Formule : AVG(rating) arrondi à 1 décimale via round() Python.
        Exemple  : (5 + 4 + 4 + 5 + 4) / 5 = 4.4 → average_rating = 4.4
        """
        from sqlalchemy import func as sqlfunc

        row = (
            db_session.query(
                sqlfunc.count(Review.id).label("cnt"),
                sqlfunc.avg(Review.rating).label("avg"),
            )
            .filter(Review.guide_id == self.id)
            .one()
        )

        self.total_reviews  = row.cnt or 0
        # round() garantit une précision à 1 décimale (ex: 4.666… → 4.7)
        self.average_rating = round(float(row.avg), 1) if row.avg else 0.0
    

    # ✅ NOUVEAU : Vérifier si le premium est encore valide
    def is_premium_active(self) -> bool:
        """Retourne True si le guide a un abonnement Premium actif"""
        if not self.is_premium:
            return False
        if self.premium_until is None:
            return True  # Premium illimité (cas admin)
        return datetime.now(self.premium_until.tzinfo) < self.premium_until

    def __repr__(self):
    # On détermine si on affiche la couronne
      premium = "👑" if self.is_premium_active() else ""
    
    # On combine toutes les infos des deux versions
      return f"<Guide{premium}(id={self.id}, rating={self.average_rating}/5, reviews={self.total_reviews})>"


# ============================================
# TABLE REVIEWS  ← NOUVELLE TABLE
# ============================================

class Review(Base):
    __tablename__ = "reviews"

    # ── Clé primaire ──────────────────────────────────────────────────────
    id          = Column(String, primary_key=True, default=generate_uuid, index=True)

    # ── Clés étrangères ───────────────────────────────────────────────────
    guide_id    = Column(
        String,
        ForeignKey("guides.id",      ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    tourist_id  = Column(
        String,
        ForeignKey("users.id",       ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    route_id    = Column(
        String,
        ForeignKey("guide_routes.id", ondelete="SET NULL"),
        nullable=True,   # Optionnel : avis sur le guide sans trajet précis
        index=True,
    )

    # ── Contenu ───────────────────────────────────────────────────────────
    rating      = Column(Integer, nullable=False)   # 1–5 (contrainte CHECK en SQL, validé en Pydantic)
    comment     = Column(Text, nullable=True)        # Texte libre, optionnel

    # ── Métadonnées ───────────────────────────────────────────────────────
    created_at  = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    # ── Relations ─────────────────────────────────────────────────────────
    guide   = relationship("Guide",      back_populates="reviews")
    tourist = relationship("User",       back_populates="reviews_given", foreign_keys=[tourist_id])
    route   = relationship("GuideRoute", foreign_keys=[route_id])   # lecture seule, pas de back_populates

    def __repr__(self):
        return f"<Review(id={self.id}, guide={self.guide_id}, tourist={self.tourist_id}, rating={self.rating}/5)>"


    
    


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
    description = Column(Text, nullable=True)

    checkpoints = Column(JSON, nullable=True, default=list)
    # ✅ NOUVEAU : TARIFICATION
    price = Column(Float, nullable=True)  # Prix en DH (Dirhams marocains)

    
    is_active = Column(Boolean, default=True, nullable=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    guide = relationship("Guide", back_populates="routes")
    # Phase B (UML étape 10/11) : checkpoints promus en table propre + créneaux programmés.
    # La colonne JSON `checkpoints` est conservée (dénormalisation de compat frontend) ;
    # `checkpoint_rows` est la source canonique côté modèle relationnel.
    checkpoint_rows = relationship(
        "Checkpoint", back_populates="route", cascade="all, delete-orphan",
        order_by="Checkpoint.position",
    )
    time_slots = relationship(
        "TimeSlot", back_populates="route", cascade="all, delete-orphan"
    )

    def __repr__(self):
    # Logique pour le prix
      price_str = f"{self.price}DH" if self.price else "Gratuit"
    
    # Logique pour les checkpoints
      cp_count = len(self.checkpoints) if self.checkpoints else 0
    
    # Construction de la chaîne finale avec toutes les infos
      return (f"<GuideRoute(id={self.id}, guide_id={self.guide_id}, "
            f"dist={self.distance}km, price={price_str}, "
            f"checkpoints={cp_count}, active={self.is_active})>")
    
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
            'description':   self.description,
            'checkpoints':   self.checkpoints or [],
            'price': self.price,  # ✅ NOUVEAU
            'is_active': self.is_active,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
# ============================================
# TABLE SUPPORT_MESSAGES (Messages de support technique)
# ============================================

class SupportMessage(Base):
    __tablename__ = "support_messages"
    
    # Clé primaire
    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    
    # Clé étrangère vers l'utilisateur
    user_id = Column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Contenu du message
    subject = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)
    
    # Statut
    is_resolved = Column(Boolean, default=False, nullable=False, index=True)
    
    # Métadonnées
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Relation
    user = relationship("User", back_populates="support_messages")
    
    def __repr__(self):
        return f"<SupportMessage(id={self.id}, user_id={self.user_id}, subject={self.subject}, is_resolved={self.is_resolved})>"


# ============================================
# TABLE CHECKPOINTS (Phase B — UML étape 10/11)
# ============================================
# Promotion du JSON imbriqué `guide_routes.checkpoints` en table propre
# (relation Route 1—0..* Checkpoint). La colonne JSON reste alimentée en
# parallèle pour ne pas casser le contrat de réponse existant.

class Checkpoint(Base):
    __tablename__ = "checkpoints"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    route_id = Column(
        String, ForeignKey("guide_routes.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    name = Column(String(120), nullable=False)
    description = Column(Text, nullable=False)
    lat = Column(Float, nullable=False)
    lng = Column(Float, nullable=False)
    type = Column(String(20), nullable=False)  # Monument, Repos, Photo, Panorama
    estimated_time = Column(Integer, nullable=False, default=0)  # minutes d'arrêt
    image_url = Column(Text, nullable=True)
    position = Column(Integer, nullable=False, default=0)  # ordre sur le trajet
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    route = relationship("GuideRoute", back_populates="checkpoint_rows")

    def __repr__(self):
        return f"<Checkpoint(id={self.id}, route={self.route_id}, name={self.name}, type={self.type})>"


# ============================================
# TABLE TIME_SLOTS (Phase B — UML étape 11/12, entité nouvelle)
# ============================================
# Créneaux programmés d'un trajet. RG21 : pas de chevauchement entre créneaux
# d'un même guide (vérifié dans RouteService/TimeSlotService avant création).

class TimeSlot(Base):
    __tablename__ = "time_slots"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    route_id = Column(
        String, ForeignKey("guide_routes.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    scheduled_start = Column(DateTime(timezone=True), nullable=False, index=True)
    scheduled_end = Column(DateTime(timezone=True), nullable=False)
    # État dérivé possible, mais persisté pour tracer l'annulation explicite.
    status = Column(String(20), default="upcoming", nullable=False)
    # upcoming, in_progress, completed, cancelled
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    route = relationship("GuideRoute", back_populates="time_slots")

    def overlaps(self, start, end) -> bool:
        """Vrai si [start, end] chevauche ce créneau (RG21). Les créneaux
        annulés ne comptent pas comme conflit.

        Normalise l'awareness des datetimes : la BDD (TIMESTAMPTZ) renvoie des
        valeurs tz-aware alors que les entrées HTTP peuvent être naïves — on
        aligne tout sur UTC pour éviter les comparaisons naïf/aware.
        """
        if self.status == "cancelled":
            return False

        def _aware(dt):
            if dt.tzinfo is None:
                return dt.replace(tzinfo=timezone.utc)
            return dt

        s_start, s_end = _aware(self.scheduled_start), _aware(self.scheduled_end)
        c_start, c_end = _aware(start), _aware(end)
        return s_start < c_end and c_start < s_end

    def __repr__(self):
        return (
            f"<TimeSlot(id={self.id}, route={self.route_id}, "
            f"{self.scheduled_start}→{self.scheduled_end}, status={self.status})>"
        )


# ============================================
# TABLE SUBSCRIPTIONS (Phase B — UML `Subscription`, historique de paiement)
# ============================================
# Chaque activation Premium crée un enregistrement d'abonnement (montant + dates).
# Source des analytics revenu/abonnements du tableau de bord admin.
# NB : `Guide.is_premium`/`premium_until` restent l'état courant (lecture rapide) ;
# cette table est l'HISTORIQUE facturable qui les alimente.

class Subscription(Base):
    __tablename__ = "subscriptions"

    id = Column(String, primary_key=True, default=generate_uuid, index=True)
    guide_id = Column(
        String, ForeignKey("guides.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    tier = Column(String(20), nullable=False, default="pro")  # pro, agency
    amount = Column(Float, nullable=False)                    # montant payé (DH)
    currency = Column(String(3), nullable=False, default="MAD")
    status = Column(String(20), nullable=False, default="active", index=True)  # active, expired, cancelled
    started_at = Column(DateTime(timezone=True), nullable=False, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    guide = relationship("Guide", back_populates="subscriptions")

    def __repr__(self):
        return (
            f"<Subscription(id={self.id}, guide={self.guide_id}, "
            f"tier={self.tier}, {self.amount}{self.currency}, status={self.status})>"
        )
