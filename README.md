# 🧭 Morchid Hub - Tourisme Durable & Certifié au Maroc (2026)
**Morchid Hub** est une plateforme innovante qui structure le secteur du guidage touristique au Maroc. Notre solution combine **Vérification d'Identité Forte (NFC/CINE)** et **Éco-Score par IA** pour garantir un tourisme sûr, officiel et respectueux de l'environnement.
## 🚀 Vision & Innovation
Dans le cadre de la vision Maroc 2026 et de la Coupe du Monde 2030, Morchid Hub répond à trois défis majeurs :
1. **Sécurité :** Élimination des faux guides via le scan NFC des cartes d'identité (CINE).
2. **Durabilité :** Incitation aux éco-trajets grâce à un algorithme de recommandation intelligent.
3. **Inclusion :** Valorisation des guides officiels certifiés par le Ministère du Tourisme.
## 🛠️ Architecture Technique

### Stack Technique :
* **Frontend :** Flutter (Mobile Android/iOS) pour une expérience fluide.
* **Backend :** FastAPI (Python) pour une API asynchrone haute performance.
* **Base de données :** PostgreSQL avec extension **PostGIS** pour la géolocalisation.
* **Sécurité :** Authentification JWT et scan NFC crypté.

-----
## 📦 Structure du Projet
Morchid-Hub/
├── mobile_app/         # Code source Flutter (Frontend)
│   ├── lib/services/   # Appels API et NFC
│   └── lib/screens/    # Interfaces Onboarding, Guide & Touriste
├── backend_api/        # Code source FastAPI (Backend)
│   ├── app/models/     # Schémas de base de données
│   └── app/api/        # Endpoints de recherche et vérification
└── docs/               # Schémas, documentation et visuels
