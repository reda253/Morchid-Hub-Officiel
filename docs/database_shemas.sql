CREATE DATABASE "MORCHID-HUB-OFFICIEL";

-- Activation de l'extension pour la géolocalisation
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Table des Utilisateurs
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) CHECK (role IN ('touriste', 'guide')),
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Table des Guides (Reliée à Users)
CREATE TABLE guides (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    licence_number VARCHAR(50) UNIQUE NOT NULL,
    is_verified BOOLEAN DEFAULT FALSE, -- Validé via le scan NFC de la CINE
    specialite VARCHAR(100), -- Ex: Montagne, Ville, Désert
    eco_score INTEGER DEFAULT 0, -- Calculé par votre algorithme
    bio TEXT,
    current_location GEOGRAPHY(POINT, 4326) -- Position GPS pour la recherche
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
