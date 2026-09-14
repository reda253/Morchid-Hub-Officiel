<p align="center">
  <img src="frontend/assets/brand/morchid-logo.svg" alt="Morchid Hub" width="220">
</p>

<h1 align="center">Morchid Hub</h1>

<p align="center">
  Plateforme de mise en relation entre touristes et guides touristiques certifiés au Maroc.
</p>

<p align="center">
  <a href="https://github.com/reda253/Morchid-Hub-Officiel/actions/workflows/ci.yml"><img src="https://github.com/reda253/Morchid-Hub-Officiel/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/API-FastAPI-009688" alt="FastAPI">
  <img src="https://img.shields.io/badge/mobile-Flutter-02569B" alt="Flutter">
  <img src="https://img.shields.io/badge/base-PostgreSQL%20%2B%20PostGIS-336791" alt="PostgreSQL + PostGIS">
</p>

---

Au Maroc, un touriste n'a pas de moyen simple de vérifier qu'un guide est officiellement reconnu
avant de le contacter. Morchid Hub part de là : un guide s'inscrit, dépose sa licence et sa carte
d'identité, et n'apparaît dans les recherches qu'une fois ses documents validés par un
administrateur. Il peut ensuite publier ses circuits sur une carte et les programmer sur des
créneaux horaires.

Le projet a été réalisé dans le cadre d'un Projet de Fin d'Année (PFA) à la FST de Tanger,
filière Logiciels et Systèmes Intelligents, 2025/2026.

**API de démonstration :** https://morchid-hub-api.onrender.com
(documentation interactive sur [`/docs`](https://morchid-hub-api.onrender.com/docs)).
Le service est hébergé sur une offre gratuite : la première requête après une période
d'inactivité peut prendre environ une minute.

## Fonctionnalités

**Pour les touristes**
- Recherche de guides par ville, spécialité, langue, expérience minimale et note.
- Consultation des profils et des circuits sans créer de compte.
- Avis et note de 1 à 5 après une sortie ; la note moyenne du guide est recalculée
  automatiquement.

**Pour les guides**
- Inscription avec dépôt des documents (photo de profil, licence, CINE).
- Création de circuits sur une carte : tracé, points d'intérêt, distance, durée, prix optionnel.
- Programmation sur des créneaux horaires ; le serveur refuse deux créneaux qui se chevauchent.
- Offre gratuite limitée à deux circuits, Premium sans limite (paiement simulé).

**Pour les administrateurs**
- File des guides en attente, consultation des documents, approbation ou rejet motivé.
- Activation et désactivation des comptes, messages de support, statistiques.

## Architecture

```mermaid
flowchart LR
    APP["Application mobile<br/>Flutter"] -->|"HTTPS · JWT"| API["API REST<br/>FastAPI"]
    API --> SVC["Services<br/>règles de gestion"]
    SVC --> REPO["Dépôts<br/>SQLAlchemy"]
    REPO --> DB[("PostgreSQL 16<br/>+ PostGIS")]
```

| Composant | Technologies |
|---|---|
| Client mobile | Flutter, `flutter_map` (OpenStreetMap), OSRM pour le calcul d'itinéraires |
| API | Python 3.11, FastAPI, Pydantic v2, SQLAlchemy 2, pilote `pg8000`, Alembic |
| Base de données | PostgreSQL 16 avec PostGIS (itinéraires en `LINESTRING`, SRID 4326) |
| Sécurité | JWT révocables, limitation de débit (slowapi), validation des fichiers déposés |
| Infrastructure | Docker, Docker Compose, GitHub Actions, Render + Neon pour la démonstration |

Le backend est organisé en trois couches : les routeurs (`api/`) ne gèrent que HTTP, les services
(`services/`) portent les règles de gestion, et les dépôts (`repositories/`) l'accès aux données.
L'API expose 43 points d'entrée répartis dans neuf routeurs.

## Structure du dépôt

```
.
├── backend/
│   ├── app/
│   │   ├── api/            # routeurs : auth, guides, routes, search, reviews, premium, admin…
│   │   ├── services/       # règles de gestion
│   │   ├── repositories/   # requêtes SQLAlchemy
│   │   ├── models.py       # modèles SQLAlchemy / GeoAlchemy2
│   │   └── schemas.py      # schémas Pydantic
│   ├── alembic/            # migrations (0001 → 0007)
│   ├── tests/              # unit/ et integration/
│   ├── Dockerfile
│   └── docker-entrypoint.sh
├── frontend/
│   ├── lib/
│   │   ├── screens/        # écrans de l'application
│   │   ├── services/       # client HTTP, configuration de l'API
│   │   ├── widgets/        # composants partagés (ui_kit.dart)
│   │   └── theme/          # couleurs et typographie
│   └── test/
├── .github/workflows/      # ci.yml (vérification), cd.yml (publication de l'image)
├── docker-compose.yml      # PostGIS + API en local
├── docker-compose.test.yml # base PostGIS jetable pour les tests
└── render.yaml             # déploiement de démonstration sur Render
```

## Démarrage rapide

### Avec Docker (recommandé)

Seul Docker est nécessaire.

```bash
git clone https://github.com/reda253/Morchid-Hub-Officiel.git
cd Morchid-Hub-Officiel

cp .env.example .env
# Renseigner SECRET_KEY (au moins 32 caractères) :
#   python -c "import secrets; print(secrets.token_urlsafe(48))"

docker compose up --build
```

L'API démarre sur http://127.0.0.1:8000 après avoir appliqué les migrations. La documentation
interactive est sur http://127.0.0.1:8000/docs.

L'API refuse de démarrer si `SECRET_KEY` est vide, trop courte ou égale à une valeur d'exemple.
C'est volontaire.

### Sans Docker

Prérequis : Python 3.11, PostgreSQL 16 avec l'extension PostGIS.

```bash
cd backend
python -m venv venv
source venv/bin/activate          # Windows : venv\Scripts\activate
pip install -r requirements-dev.txt

# Créer backend/.env avec DATABASE_URL, SECRET_KEY, CORS_ORIGINS, ADMIN_EMAILS
# DATABASE_URL=postgresql+pg8000://utilisateur:motdepasse@localhost:5432/morchid

alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Application mobile

Prérequis : Flutter (canal stable) et un émulateur Android ou un téléphone.

```bash
cd frontend
flutter pub get
flutter run
```

Sans configuration, l'application vise l'API locale (`http://10.0.2.2:8000` sur l'émulateur
Android, `http://127.0.0.1:8000` ailleurs). Pour viser un autre serveur, passer son adresse à la
construction :

```bash
flutter build apk --release --dart-define=API_BASE_URL=https://morchid-hub-api.onrender.com
```

### Devenir administrateur

Il n'existe pas de compte administrateur par défaut, et le rôle ne s'attribue pas en base. Ajouter
l'adresse e-mail du compte à la variable `ADMIN_EMAILS` (liste séparée par des virgules), puis se
reconnecter.

## Tests

```bash
# Backend — depuis la racine, démarrer la base de test (port 5433)
docker compose -f docker-compose.test.yml up -d

cd backend
pytest                  # suite complète : 198 tests
pytest -m unit          # services uniquement, sans base de données
pytest -m integration   # dépôts et API, sur PostGIS
```

Les tests d'intégration sont ignorés, et non en échec, quand aucune base n'est joignable. En
local, vérifiez donc qu'aucun test n'est marqué *skipped* avant de conclure que tout passe.

```bash
# Frontend
cd frontend
flutter analyze
flutter test            # 88 tests
```

## Intégration continue

Chaque *pull request* et chaque `push` déclenchent `ci.yml`, qui comporte trois tâches bloquantes :

- **backend-tests** : suite pytest sur un conteneur PostGIS, puis `alembic upgrade head` sur une
  base vierge. La tâche échoue si un seul test est ignoré, pour qu'une base mal configurée ne
  produise pas une suite verte mais vide.
- **frontend-tests** : `flutter analyze` puis `flutter test`.
- **docker-build** : construction de l'image de l'API.

Sur `main`, `cd.yml` publie l'image dans le GitHub Container Registry
(`ghcr.io/reda253/morchid-hub-api`), et Render redéploie l'API de démonstration une fois la CI au
vert.

## Sécurité

Quelques choix à connaître avant de contribuer :

- Les points d'entrée publics renvoient `PublicGuideCard`, une projection qui liste ses champs un
  par un. Ne jamais y renvoyer `GuideResponse` ou `UserResponse`, qui contiennent l'e-mail et les
  liens vers les documents d'identité.
- Seules les photos de profil sont servies en statique (`/uploads/profiles`). Les licences et les
  CINE ne sont accessibles que par un point d'entrée réservé aux administrateurs.
- Les droits d'administration viennent uniquement de `ADMIN_EMAILS`. Modifier une ligne en base
  ne rend personne administrateur.
- Les réponses d'authentification ne varient jamais selon qu'un compte existe ou non.
- Aucun secret n'est versionné : `.env` est ignoré par Git, et `.env.example` ne contient aucune
  valeur réelle.

Si vous trouvez une faille, merci de la signaler en privé plutôt que dans une *issue* publique.

## Limites actuelles

- Le paiement Premium et l'envoi d'e-mails sont simulés : les liens de vérification sont écrits
  dans les journaux du serveur.
- La réservation d'un créneau par un touriste n'existe pas encore.
- Sur l'offre gratuite de Render, les fichiers déposés sont effacés à chaque redémarrage du
  service. N'y déposez jamais de vrais documents d'identité.

## Pistes d'évolution

- Réservation des créneaux par les touristes.
- Vérification des guides par carte NFC, en partenariat avec le Ministère du Tourisme.
- Passerelle de paiement réelle, envoi d'e-mails, stockage durable des documents.
- Interface en arabe et en anglais.
- Publication sur le Google Play Store, puis iOS.

## Auteur

**Mohamed Reda El Arroud** — Projet de Fin d'Année, FST de Tanger, 2025/2026.
Encadré par **M. Lotfi El Aachak**.
