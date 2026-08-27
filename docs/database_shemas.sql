CREATE DATABASE "MORCHID-HUB-OFFICIEL";

-- Activation de l'extension pour la géolocalisation
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Table des Utilisateurs
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY, -- Correspond au UUID String du code Python
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(20) NOT NULL,
    date_of_birth VARCHAR(10) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL, -- 'tourist' ou 'guide'
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- 2. Table des Guides
CREATE TABLE guides (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    languages TEXT[] NOT NULL, -- Correspond au ARRAY(String) de SQLAlchemy
    specialties TEXT[] NOT NULL,
    cities_covered TEXT[] NOT NULL,
    years_of_experience INTEGER DEFAULT 0,
    bio TEXT NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE,
    eco_score INTEGER DEFAULT 0,
    has_official_license BOOLEAN DEFAULT FALSE,
    license_number VARCHAR(50),
    approval_status VARCHAR(20) DEFAULT 'pending_approval',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE
);

-- 3. Table des Trajets (Éco-responsables)
CREATE TABLE trajets (
    id SERIAL PRIMARY KEY,
    guide_id INTEGER REFERENCES guides(id) ON DELETE CASCADE,
    titre VARCHAR(150),
    description TEXT,
    mode_transport VARCHAR(50), -- Ex: Marche, Vélo, Transport Électrique
    co2_estime FLOAT, -- Estimation en kg pour le trajet
    prix_moyen DECIMAL(10, 2)
);

-- 4. Table des Réservations
CREATE TABLE reservations (
    id SERIAL PRIMARY KEY,
    tourist_id INTEGER REFERENCES users(id),
    trajet_id INTEGER REFERENCES trajets(id),
    date_reservation TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    statut VARCHAR(20) DEFAULT 'en_attente'
);


CREATE TABLE guide_routes (
    -- Clé primaire
    id VARCHAR PRIMARY KEY,
    
    -- Clé étrangère vers le guide
    guide_id VARCHAR NOT NULL,
    
    -- ============================================
    -- COLONNES GÉOSPATIALES (PostGIS)
    -- ============================================
    
    -- Ligne du trajet complet (LINESTRING)
    route_line GEOMETRY(LINESTRING, 4326) NOT NULL,
    
    -- Point de départ (POINT)
    start_point GEOMETRY(POINT, 4326) NOT NULL,
    
    -- Point d'arrivée (POINT)
    end_point GEOMETRY(POINT, 4326) NOT NULL,
    
    -- ============================================
    -- MÉTADONNÉES DU TRAJET
    -- ============================================
    
    -- Coordonnées JSON (pour compatibilité frontend)
    coordinates JSONB NOT NULL,
    
    -- Distance en kilomètres
    distance DOUBLE PRECISION NOT NULL,
    
    -- Durée en minutes
    duration DOUBLE PRECISION NOT NULL,
    
    -- Adresses lisibles
    start_address TEXT,
    end_address TEXT,
    
    -- Statut (un seul trajet actif par guide)
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    
    -- Métadonnées temporelles
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE,
    
    -- Contrainte de clé étrangère
    CONSTRAINT fk_guide
        FOREIGN KEY(guide_id)
        REFERENCES guides(id)
        ON DELETE CASCADE
);

ALTER TABLE users ADD COLUMN is_admin BOOLEAN DEFAULT FALSE;


DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'guides' 
        AND column_name = 'rejection_reason'
    ) THEN
        ALTER TABLE guides 
        ADD COLUMN rejection_reason TEXT NULL;
        
        COMMENT ON COLUMN guides.rejection_reason IS 'Motif du rejet du guide par l''admin';
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS support_messages (
    -- Clé primaire
    id VARCHAR PRIMARY KEY,
    
    -- Clé étrangère vers l'utilisateur
    user_id VARCHAR NOT NULL,
    
    -- Contenu du message
    subject VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    
    -- Statut
    is_resolved BOOLEAN DEFAULT FALSE NOT NULL,
    
    -- Métadonnées
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP WITH TIME ZONE,
    
    -- Contrainte de clé étrangère
    CONSTRAINT fk_support_user
        FOREIGN KEY(user_id)
        REFERENCES users(id)
        ON DELETE CASCADE
);


-- Index sur user_id pour les jointures rapides
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id 
ON support_messages(user_id);

-- Index sur is_resolved pour filtrer les messages non résolus
CREATE INDEX IF NOT EXISTS idx_support_messages_is_resolved 
ON support_messages(is_resolved);

-- Index sur created_at pour trier par date
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at 
ON support_messages(created_at DESC);

-- ============================================
-- 4. AJOUTER DES COMMENTAIRES
-- ============================================

COMMENT ON TABLE support_messages IS 'Messages de support technique des utilisateurs';
COMMENT ON COLUMN support_messages.subject IS 'Sujet du message (max 200 caractères)';
COMMENT ON COLUMN support_messages.message IS 'Contenu détaillé du message';
COMMENT ON COLUMN support_messages.is_resolved IS 'TRUE = résolu, FALSE = en attente';
COMMENT ON COLUMN support_messages.resolved_at IS 'Date et heure de résolution';



-- 1. Ajouter average_rating
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'guides' AND column_name = 'average_rating'
    ) THEN
        ALTER TABLE guides ADD COLUMN average_rating FLOAT DEFAULT 0.0 NOT NULL;
        COMMENT ON COLUMN guides.average_rating IS 'Note moyenne des avis (0.0 - 5.0)';
        RAISE NOTICE '✅ Colonne average_rating ajoutée';
    ELSE
        RAISE NOTICE 'ℹ️  Colonne average_rating existe déjà';
    END IF;
END $$;

-- 2. Ajouter total_reviews
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'guides' AND column_name = 'total_reviews'
    ) THEN
        ALTER TABLE guides ADD COLUMN total_reviews INTEGER DEFAULT 0 NOT NULL;
        COMMENT ON COLUMN guides.total_reviews IS 'Nombre total d''avis reçus';
        RAISE NOTICE '✅ Colonne total_reviews ajoutée';
    ELSE
        RAISE NOTICE 'ℹ️  Colonne total_reviews existe déjà';
    END IF;
END $$;

-- 3. Index sur average_rating pour tris rapides
CREATE INDEX IF NOT EXISTS idx_guides_average_rating
ON guides(average_rating DESC);

-- 4. Index sur eco_score pour filtres
CREATE INDEX IF NOT EXISTS idx_guides_eco_score
ON guides(eco_score);

-- 5. Index texte sur start_address et end_address pour recherche par trajet
CREATE INDEX IF NOT EXISTS idx_guide_routes_start_address
ON guide_routes(start_address);

CREATE INDEX IF NOT EXISTS idx_guide_routes_end_address
ON guide_routes(end_address);

ALTER TABLE guide_routes ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE guide_routes ADD COLUMN IF NOT EXISTS checkpoints JSONB NOT NULL DEFAULT '[]';
CREATE INDEX IF NOT EXISTS idx_guide_routes_checkpoints ON guide_routes USING GIN (checkpoints);

ALTER TABLE guides
    ADD COLUMN IF NOT EXISTS is_premium BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE guides
    ADD COLUMN IF NOT EXISTS premium_until TIMESTAMP WITH TIME ZONE;

-- Index pour optimiser les requêtes premium
CREATE INDEX IF NOT EXISTS idx_guides_is_premium
    ON guides(is_premium) WHERE is_premium = TRUE;

-- 2. Ajout colonne prix dans la table guide_routes
ALTER TABLE guide_routes
    ADD COLUMN IF NOT EXISTS price FLOAT;

-- Commentaire pour documenter
COMMENT ON COLUMN guide_routes.price IS 'Prix du trajet en DH (Dirhams marocains)';
COMMENT ON COLUMN guides.is_premium IS 'Indique si le guide a un abonnement Premium actif';
COMMENT ON COLUMN guides.premium_until IS 'Date d''expiration de l''abonnement Premium (NULL = illimité)';


-- ============================================================================
-- PHASE B — ALIGNEMENT MODÈLE UML  (miroir des migrations Alembic backend/alembic)
-- Source canonique en déploiement : `alembic upgrade head`. Ces blocs idempotents
-- gardent docs/database_shemas.sql synchronisé avec models.py (règle du projet).
-- ============================================================================

-- #1 (0002) RG14 : fusion des statuts pending_approval / pending_review -> pending
UPDATE guides SET approval_status = 'pending'
    WHERE approval_status IN ('pending_approval', 'pending_review');
ALTER TABLE guides ALTER COLUMN approval_status SET DEFAULT 'pending';

-- #2 (0003) RG1/RG2 : rôle `administrator` (backfill depuis is_admin ; is_admin conservé en transition)
UPDATE users SET role = 'administrator' WHERE is_admin = TRUE;

-- #3 (0004) Promotion des checkpoints (JSON guide_routes.checkpoints) en table propre
CREATE TABLE IF NOT EXISTS checkpoints (
    id             VARCHAR PRIMARY KEY,
    route_id       VARCHAR NOT NULL REFERENCES guide_routes(id) ON DELETE CASCADE,
    name           VARCHAR(120) NOT NULL,
    description    TEXT NOT NULL,
    lat            DOUBLE PRECISION NOT NULL,
    lng            DOUBLE PRECISION NOT NULL,
    type           VARCHAR(20) NOT NULL,           -- Monument, Repos, Photo, Panorama
    estimated_time INTEGER NOT NULL DEFAULT 0,     -- minutes d'arrêt
    image_url      TEXT,
    position       INTEGER NOT NULL DEFAULT 0,     -- ordre sur le trajet
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_checkpoints_route_id ON checkpoints(route_id);
-- Backfill des lignes existantes depuis le JSON (idempotent : seulement si la table est vide)
INSERT INTO checkpoints (id, route_id, name, description, lat, lng, type, estimated_time, image_url, position, created_at)
SELECT gen_random_uuid()::text, gr.id,
       COALESCE(elem->>'name','Checkpoint'), COALESCE(elem->>'description',''),
       COALESCE((elem->>'lat')::float,0), COALESCE((elem->>'lng')::float,0),
       COALESCE(elem->>'type','Monument'), COALESCE((elem->>'estimated_time')::int,0),
       elem->>'image_url', (ord-1)::int, CURRENT_TIMESTAMP
FROM guide_routes gr,
     jsonb_array_elements(gr.checkpoints::jsonb) WITH ORDINALITY AS t(elem, ord)
WHERE gr.checkpoints IS NOT NULL
  AND jsonb_typeof(gr.checkpoints::jsonb) = 'array'
  AND NOT EXISTS (SELECT 1 FROM checkpoints);
COMMENT ON TABLE checkpoints IS 'Points d''intérêt d''un trajet (promotion du JSON guide_routes.checkpoints — UML étape 10/11)';

-- #4 (0005) Nouvelle table des créneaux programmés (RG21 non-chevauchement appliqué côté service)
CREATE TABLE IF NOT EXISTS time_slots (
    id              VARCHAR PRIMARY KEY,
    route_id        VARCHAR NOT NULL REFERENCES guide_routes(id) ON DELETE CASCADE,
    scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
    scheduled_end   TIMESTAMP WITH TIME ZONE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'upcoming',  -- upcoming, in_progress, completed, cancelled
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_time_slots_route_id ON time_slots(route_id);
CREATE INDEX IF NOT EXISTS idx_time_slots_scheduled_start ON time_slots(scheduled_start);
COMMENT ON TABLE time_slots IS 'Créneaux programmés d''un trajet (entité UML nouvelle — étapes 11/12)';

-- #5 (0006) Table des abonnements — historique de paiement Premium (analytics revenu)
CREATE TABLE IF NOT EXISTS subscriptions (
    id         VARCHAR PRIMARY KEY,
    guide_id   VARCHAR NOT NULL REFERENCES guides(id) ON DELETE CASCADE,
    tier       VARCHAR(20) NOT NULL DEFAULT 'pro',    -- pro, agency
    amount     DOUBLE PRECISION NOT NULL,             -- montant payé (DH)
    currency   VARCHAR(3) NOT NULL DEFAULT 'MAD',
    status     VARCHAR(20) NOT NULL DEFAULT 'active', -- active, expired, cancelled
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_subscriptions_guide_id ON subscriptions(guide_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_subscriptions_started_at ON subscriptions(started_at);
COMMENT ON TABLE subscriptions IS 'Historique des abonnements Premium (montant + dates) — source des analytics revenu/abonnements';
-- Backfill des guides déjà Premium (idempotent : seulement si la table est vide)
INSERT INTO subscriptions (id, guide_id, tier, amount, currency, status, started_at, expires_at, created_at)
SELECT gen_random_uuid()::text, g.id, 'pro', 399.0, 'MAD',
       CASE WHEN g.premium_until IS NULL OR g.premium_until > CURRENT_TIMESTAMP THEN 'active' ELSE 'expired' END,
       COALESCE(g.premium_until - INTERVAL '30 days', CURRENT_TIMESTAMP),
       COALESCE(g.premium_until, CURRENT_TIMESTAMP + INTERVAL '30 days'),
       CURRENT_TIMESTAMP
FROM guides g
WHERE g.is_premium = TRUE
  AND NOT EXISTS (SELECT 1 FROM subscriptions);
