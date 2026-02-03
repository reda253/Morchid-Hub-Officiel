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





