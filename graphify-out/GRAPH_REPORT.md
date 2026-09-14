# Graph Report - projetmorchid  (2026-09-14)

## Corpus Check
- 160 files · ~73,972 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2293 nodes · 4118 edges · 120 communities (110 shown, 10 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 85 edges (avg confidence: 0.93)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Écran carte (Flutter)
- Modèles utilisateur (Dart)
- Service d'authentification
- Kit UI partagé
- Modèles admin (Dart)
- Client HTTP ApiService
- Assemblage FastAPI et dépendances
- Routeur admin
- Widgets d'authentification
- Modèles de recherche (Dart)
- Écran de paiement
- Point d'entrée et navigation
- Écran d'administration
- Routeur auth
- Contrôle d'accès admin
- Écran des avis
- Tests de divulgation et recherche
- Routes nommées Flutter
- Recherche et PublicGuideCard
- Écran d'accueil onboarding
- Widgets à état Flutter
- Avis : routeur et service
- Modèles de circuits (Dart)
- Écran d'inscription
- Service admin (Dart)
- Dépôt des guides
- Dépôts de base et support
- Écran mes sorties et stats
- Écran vérification guide
- Animations et interactions
- Palette de couleurs
- Tests circuits et créneaux
- Circuits : routeur et service
- Dépôt des abonnements
- Écran circuits disponibles
- Gestion des erreurs API
- Dépôt de fichiers et validation
- Dépôt utilisateurs et énumération
- Écran explorer
- Widgets sans état
- Écran de recherche
- Service admin (backend)
- Dépôt des avis
- Écran analytique admin
- Tableau de bord guide
- Écran vérification e-mail
- URL de base et TLS (Neon)
- Typographie et thème
- Créneaux horaires : modèle
- Tests analytique et abonnements
- Service analytique
- Tests API admin et avis
- Stockage local session
- Écran profil guide
- Service OSM et itinéraires
- Routeur guides
- Tests service avis
- Validateurs Pydantic
- Tests API auth
- Écran de connexion
- Effet shimmer
- Dépôt des circuits
- Fixtures de test
- Mot de passe oublié
- Démarrage et garde-fous config
- Modèles SQLAlchemy
- Tests service admin
- Profil et agenda
- Bouton contact WhatsApp
- Coquille de navigation
- Service des créneaux
- Garde d'authentification
- Construction géométrie circuit
- Tests widgets UI (1)
- Politique de mot de passe
- Tests service guides
- Tests limite gratuite circuits
- Graphique des revenus
- Tests navigation et garde
- Service de notification
- Tests chevauchement créneaux
- Tests coquille et erreurs
- Validateurs de formulaire
- Widget ErrorState
- Tests validateurs et config API
- Fenêtre Premium
- Tests animations (UI)
- Configuration URL de l'API
- Écran de démarrage
- Limitation de débit
- Tests service Premium
- Tests points de passage
- Tests service recherche
- Dessins personnalisés
- Tests limitation de débit
- Tests câblage connexions
- Tests jetons de design
- Tests groupe de stats
- Migration 0001 baseline
- Création de créneau (API)
- Tests écran recherche
- Formateurs carte bancaire
- Tests destinations shell
- Test de fumée application
- Paquet repositories
- Script de démarrage Docker
- Types de points de passage
- État de l'écran carte
- Validateur e-mail
- Type DateTime
- Référence GuideRoute

## God Nodes (most connected - your core abstractions)
1. `User` - 96 edges
2. `make_guide()` - 73 edges
3. `make_user()` - 60 edges
4. `Guide` - 44 edges
5. `auth_headers()` - 44 edges
6. `NotFoundError` - 43 edges
7. `BadRequestError` - 41 edges
8. `GuideRepository` - 38 edges
9. `ForbiddenError` - 36 edges
10. `_` - 36 edges

## Surprising Connections (you probably didn't know these)
- `test_debug_defaults_to_false()` --uses--> `Settings`  [INFERRED]
  backend/tests/unit/test_config_guards.py → backend/app/config.py
- `get_current_user()` --uses--> `User`  [INFERRED]
  backend/app/auth.py → backend/app/models.py
- `test_approve_guide_without_documents_raises()` --uses--> `BadRequestError`  [INFERRED]
  backend/tests/unit/test_admin_service.py → backend/app/exceptions.py
- `test_approve_non_pending_guide_raises_invalid_status()` --uses--> `BadRequestError`  [INFERRED]
  backend/tests/unit/test_admin_service.py → backend/app/exceptions.py
- `test_resolve_already_resolved_raises()` --uses--> `BadRequestError`  [INFERRED]
  backend/tests/unit/test_admin_service.py → backend/app/exceptions.py

## Import Cycles
- None detected.

## Communities (120 total, 10 thin omitted)

### Community 0 - "Écran carte (Flutter)"
Cohesion: 0.03
Nodes (75): _addMarker, backgroundColor, build, _buildActionButtons, _buildAddressInfo, _buildEditBody, _buildFreeLimitWarning, _buildInfoPanel (+67 more)

### Community 1 - "Modèles utilisateur (Dart)"
Cohesion: 0.03
Nodes (73): accessToken, ApiError, approvalStatus, averageRating, bio, cineCardUrl, citiesCovered, comment (+65 more)

### Community 2 - "Service d'authentification"
Cohesion: 0.06
Nodes (55): create_access_token(), decode_access_token(), hash_password(), Hash un mot de passe en utilisant bcrypt Args: password: Le mot de passe en…, Vérifie qu'un mot de passe correspond à son hash Args: plain_password: Le mot…, Crée un token JWT pour l'authentification Args: data: Les données à encoder…, Décode et vérifie un token JWT Args: token: Le token JWT à décoder Returns: Les…, verify_password() (+47 more)

### Community 3 - "Kit UI partagé"
Cohesion: 0.03
Nodes (62): EdgeInsets, actionLabel, actions, _apertureR, avatarUrl, build, byline, child (+54 more)

### Community 4 - "Modèles admin (Dart)"
Cohesion: 0.04
Nodes (53): active, activeSubscriptions, activeTotal, ApiError, approvalStatus, arpu, bio, byTier (+45 more)

### Community 5 - "Client HTTP ApiService"
Cohesion: 0.04
Nodes (48): adminGuidesEndpoint, ApiService, _authenticatedDelete, authenticatedGet, authenticatedPost, authHeadersForImages, baseUrl, deleteReview (+40 more)

### Community 6 - "Assemblage FastAPI et dépendances"
Cohesion: 0.07
Nodes (38): get_admin_service(), get_analytics_service(), get_auth_service(), get_premium_service(), get_route_service(), get_time_slot_service(), AdminService, Session (+30 more)

### Community 7 - "Routeur admin"
Cohesion: 0.10
Nodes (35): analytics_overview(), analytics_revenue(), analytics_subscriptions(), approve_guide(), delete_support_message(), get_admin_stats(), get_all_users(), get_guide_document() (+27 more)

### Community 8 - "Widgets d'authentification"
Cohesion: 0.06
Nodes (37): AuthHeader, build, controller, createState, CustomTextField, _CustomTextFieldState, dispose, hint (+29 more)

### Community 9 - "Modèles de recherche (Dart)"
Cohesion: 0.05
Nodes (36): ActiveRouteInfo?, bool get, double get, activeRoute, ActiveRouteInfo, averageRating, bio, cities (+28 more)

### Community 10 - "Écran de paiement"
Cohesion: 0.05
Nodes (36): amount, _benefit, build, _buildAlternativePaymentInfo, _buildAnimatedCard, _buildCardBack, _buildCardFront, _buildMethodSelector (+28 more)

### Community 11 - "Point d'entrée et navigation"
Cohesion: 0.06
Nodes (34): build, main, MorchidHubApp, activeIcon, destinationsForRole, _guideDestinations, icon, label (+26 more)

### Community 12 - "Écran d'administration"
Cohesion: 0.06
Nodes (35): _activeGuides, build, _buildDocumentSection, _buildGuideApprovalsTab, _buildGuideCard, _buildMissingDocumentPlaceholder, _buildProtectedDocumentSection, _buildStatsBanner (+27 more)

### Community 13 - "Routeur auth"
Cohesion: 0.11
Nodes (31): forgot_password(), get_current_user_profile(), login_user(), get, post, Request, Controller Authentification & Profil — inscription, connexion, email, mot de…, register_user() (+23 more)

### Community 14 - "Contrôle d'accès admin"
Cohesion: 0.12
Nodes (32): Garde : réserve l'accès aux comptes administrateurs. Source de vérité unique :…, require_admin(), Config, Classe de configuration qui charge automatiquement les variables depuis .env, Convertit la string CORS_ORIGINS en liste, Convertit la string ADMIN_EMAILS en liste d'emails normalisés (minuscules), Settings, ForbiddenError (+24 more)

### Community 15 - "Écran des avis"
Cohesion: 0.06
Nodes (34): build, _buildCompactRating, _buildEmptyReviews, _buildFormTab, _buildGuideAvatar, _buildHeader, _buildRatingBar, _buildRatingSummary (+26 more)

### Community 16 - "Tests de divulgation et recherche"
Cohesion: 0.10
Nodes (31): ensure_upload_dirs(), Crée l'arborescence uploads/ si elle n'existe pas (idempotent)., make_guide(), Tests d'intégration API — recherche & filtres (endpoints publics)., test_available_filters_reports_values(), test_search_excludes_pending_guides(), test_search_guides_city_filter(), Tests d'intégration GuideRepository — recherche filtrée (JSONB), listes, stats. (+23 more)

### Community 17 - "Routes nommées Flutter"
Cohesion: 0.06
Nodes (33): admin, adminAnalytics, amount, AppRoutes, availableRoutes, email, emailVerification, EmailVerificationArgs (+25 more)

### Community 18 - "Recherche et PublicGuideCard"
Cohesion: 0.08
Nodes (29): get_search_service(), get_available_filters(), get, Controller Recherche & Découverte — recherche de guides et de trajets., search_guides(), search_guides_with_routes(), ActiveRouteInfo, CheckpointSchema (+21 more)

### Community 19 - "Écran d'accueil onboarding"
Cohesion: 0.06
Nodes (32): Color?, build, _buildFeature, _buildFooter, _buildPage, _buildSkip, _buildWelcome, child (+24 more)

### Community 20 - "Widgets à état Flutter"
Cohesion: 0.10
Nodes (33): AdminAnalyticsScreen, _AdminAnalyticsScreenState, AdminScreen, _AdminScreenState, AvailableRoutesScreen, _AvailableRoutesScreenState, ExploreScreen, _ExploreScreenState (+25 more)

### Community 21 - "Avis : routeur et service"
Cohesion: 0.09
Nodes (28): get_review_service(), create_review(), delete_review(), list_guide_reviews(), delete, get, post, Review (+20 more)

### Community 22 - "Modèles de circuits (Dart)"
Cohesion: 0.06
Nodes (31): Checkpoint, checkpoints, coordinates, createdAt, description, distance, duration, endAddress (+23 more)

### Community 23 - "Écran d'inscription"
Cohesion: 0.06
Nodes (31): _acceptTerms, _animationController, _bioController, _birthYearController, build, _citiesController, _confirmPasswordController, createState (+23 more)

### Community 24 - "Service admin (Dart)"
Cohesion: 0.07
Nodes (28): api_config.dart, adminGuidesEndpoint, adminPendingGuidesEndpoint, AdminService, adminSupportMessagesEndpoint, adminUsersEndpoint, analyticsOverviewEndpoint, analyticsRevenueEndpoint (+20 more)

### Community 25 - "Dépôt des guides"
Cohesion: 0.10
Nodes (10): Guide, Recalcule average_rating et total_reviews en interrogeant directement la BDD —…, Retourne True si le guide a un abonnement Premium actif, GuideRepository, GuideRoute, Guide dont l'id ET le propriétaire (user_id) correspondent., Guide vérifié (utilisé pour l'éligibilité aux avis)., Guides visibles publiquement : approuvés uniquement. Le filtre… (+2 more)

### Community 26 - "Dépôts de base et support"
Cohesion: 0.11
Nodes (18): SupportMessage, BaseRepository, Session, Repository de base : porte la session SQLAlchemy., Toutes les repositories partagent une même session de requête., SupportMessage, Accès aux données de la table `support_messages`., Messages joints à leur auteur (non résolus d'abord, puis plus récents). Un LEFT… (+10 more)

### Community 27 - "Écran mes sorties et stats"
Cohesion: 0.08
Nodes (25): build, TripsScreen, build, InlineError, message, build, _buildCell, cells (+17 more)

### Community 28 - "Écran vérification guide"
Cohesion: 0.07
Nodes (27): File?, _basename, build, _buildSuccessDialog, _cineController, _cinePhoto, createState, dispose (+19 more)

### Community 29 - "Animations et interactions"
Cohesion: 0.08
Nodes (27): CurvedAnimation, _, AppMotion, build, child, _controller, createState, _curved (+19 more)

### Community 30 - "Palette de couleurs"
Cohesion: 0.07
Nodes (26): accent, AppColors, background, cardBorder, error, ink, mint, onImage (+18 more)

### Community 31 - "Tests circuits et créneaux"
Cohesion: 0.14
Nodes (23): make_route(), GuideRoute, Tests d'intégration API — trajets guides (création, actif, historique,…, test_create_route_free_limit_returns_403(), test_create_route_returns_201(), test_delete_route_by_owner(), test_get_active_route_and_history(), test_get_active_route_none_returns_404() (+15 more)

### Community 32 - "Circuits : routeur et service"
Cohesion: 0.13
Nodes (19): get_all_active_routes(), get_guide_route(), get_guide_routes_history(), get, GuideRoute, post, Controller Trajets — création, consultation, suppression, listing public., Mappe un GuideRoute vers sa réponse. Les drapeaux reproduisent les variantes de… (+11 more)

### Community 33 - "Dépôt des abonnements"
Cohesion: 0.11
Nodes (13): datetime, Accès aux données de la table `subscriptions` + agrégations analytics (Phase…, Abonnements encore valides (non expirés, non annulés)., Somme des montants des abonnements actifs (base du MRR)., (mois tronqué, revenu du mois, nb d'abonnements) depuis `since`, ordre…, (tier, nb d'abonnements actifs, revenu total du tier)., SubscriptionRepository, Session (+5 more)

### Community 34 - "Écran circuits disponibles"
Cohesion: 0.08
Nodes (24): _allRoutes, build, _buildEmptyState, _buildError, _buildLoader, _buildRouteCard, _buildRoutesList, _buildSearchBar (+16 more)

### Community 35 - "Gestion des erreurs API"
Cohesion: 0.15
Nodes (22): app_error_handler(), AppError, _describe_validation_error(), _error_payload(), http_exception_handler(), JSONResponse, Request, Domain exceptions + FastAPI exception handlers. Les services lèvent des… (+14 more)

### Community 36 - "Dépôt de fichiers et validation"
Cohesion: 0.16
Nodes (19): BadRequestError, ServerError, UploadFile, Service des profils guides : vérification d'identité et consultation., UploadFile, Gestion du stockage des fichiers uploadés (photos de vérification guide).…, Sauvegarde un fichier uploadé sous un nom unique, après validation. Trois…, save_upload_file() (+11 more)

### Community 37 - "Dépôt utilisateurs et énumération"
Cohesion: 0.13
Nodes (13): UserRepository, make_user(), _forgot(), Un appelant anonyme ne doit pas pouvoir distinguer un compte existant d'un…, _resend(), test_forgot_password_is_indistinguishable(), test_resend_verification_is_indistinguishable(), Tests d'intégration UserRepository (vraie BDD, transaction rollback). (+5 more)

### Community 38 - "Écran explorer"
Cohesion: 0.09
Nodes (23): build, _buildLeaveReviewSection, _buildTouristDashboard, createState, _error, _experts, _expertsSection, _exploreRegions (+15 more)

### Community 39 - "Widgets sans état"
Cohesion: 0.08
Nodes (24): LanguagesInput, RoleDropdown, TextLink, ActionButton, ActionRow, AppCard, AppFilterChip, AppHeaderBar (+16 more)

### Community 40 - "Écran de recherche"
Cohesion: 0.09
Nodes (22): double?, build, _buildAvatar, _buildGuideCard, _buildResultsList, _buildSearchHeader, _cities, createState (+14 more)

### Community 41 - "Service admin (backend)"
Cohesion: 0.13
Nodes (7): NotFoundError, AdminService, SupportMessage, Service d'administration : utilisateurs, approbation des guides, support, stats., Guide par id, ou None. Utilisé par l'accès aux documents., Active le Premium 30 jours. Retourne (message, data) pour la réponse., Review

### Community 42 - "Dépôt des avis"
Cohesion: 0.15
Nodes (13): Review, Review, Accès aux données de la table `reviews`., Avis d'un guide joints à l'auteur, du plus récent au plus ancien., Retourne (nombre d'avis, note moyenne brute) pour un guide., ReviewRepository, make_review(), Review (+5 more)

### Community 43 - "Écran analytique admin"
Cohesion: 0.09
Nodes (21): RevenueOverview, RevenueTimeseries, SubscriptionsBreakdown, TierBreakdown, build, createState, currency, _DashboardData (+13 more)

### Community 44 - "Tableau de bord guide"
Cohesion: 0.10
Nodes (20): build, _buildHeader, _buildPremiumBanner, _buildVerificationNotice, createState, _gutter, _openReviewScreen, profile (+12 more)

### Community 45 - "Écran vérification e-mail"
Cohesion: 0.11
Nodes (19): _animationController, build, _buildInstructionStep, _canResend, _countdown, createState, dispose, email (+11 more)

### Community 46 - "URL de base et TLS (Neon)"
Cohesion: 0.16
Nodes (15): Any, Environnement Alembic pour Morchid Hub. - Résout l'URL depuis…, run_migrations_online(), build_engine_config(), Préparation de DATABASE_URL pour le pilote pg8000. Les hébergeurs Postgres…, Retourne l'URL nettoyée et les `connect_args` à passer à `create_engine`. L'URL…, Traduction des URL Postgres managées (format libpq) pour le pilote pg8000., test_channel_binding_is_stripped() (+7 more)

### Community 47 - "Typographie et thème"
Cohesion: 0.11
Nodes (17): AppTextStyles, bodyLg, bodySm, bodyXs, displayLg, displayMd, headlineLg, headlineMd (+9 more)

### Community 48 - "Créneaux horaires : modèle"
Cohesion: 0.16
Nodes (9): generate_uuid(), SQLAlchemy Database Models Définit la structure des tables PostgreSQL, Génère un UUID v4 unique, Vrai si [start, end] chevauche ce créneau (RG21). Les créneaux annulés ne…, TimeSlot, Accès aux données de la table `time_slots` (créneaux programmés — Phase B)., Créneaux non annulés de tous les trajets d'un guide (base du contrôle RG21)., TimeSlotRepository (+1 more)

### Community 49 - "Tests analytique et abonnements"
Cohesion: 0.16
Nodes (13): Subscription, make_subscription(), datetime, Session, Fabriques d'entités pour les tests d'intégration. Insèrent directement des…, _route_payload(), _uid(), Tests d'intégration API — analytics admin (revenu/abonnements réels). (+5 more)

### Community 50 - "Service analytique"
Cohesion: 0.19
Nodes (13): _add_months(), _month_start(), datetime, Service analytics admin — revenu & abonnements réels (Phase B). Alimente le…, Décale `dt` (au 1er du mois) de `n` mois (n peut être négatif)., Série mensuelle continue (mois vides remplis à 0) sur `months` mois., Tests unitaires du AnalyticsService — calculs revenu/abonnements (repo mocké)., _service() (+5 more)

### Community 51 - "Tests API admin et avis"
Cohesion: 0.18
Nodes (16): auth_headers(), En-tête Authorization Bearer pour un utilisateur donné., Tests d'intégration API — administration (approbation guide, stats, garde rôle)., Le rôle `administrator` (même avec `is_admin=True`) ne donne plus accès. La…, test_admin_stats_structure(), test_administrator_role_alone_no_longer_grants_access(), test_approve_guide_returns_200_and_verifies(), test_list_guides_by_status() (+8 more)

### Community 52 - "Stockage local session"
Cohesion: 0.11
Nodes (17): dart:convert, clearLoginData, getAccessToken, getLastGuide, getUserData, hasSeenOnboarding, isLoggedIn, _keyAccessToken (+9 more)

### Community 53 - "Écran profil guide"
Cohesion: 0.11
Nodes (17): SearchGuideResult, build, _buildActionButtons, _buildAvatar, _buildBadgesRow, _buildInfoCard, _buildSectionTitle, _buildSliverAppBar (+9 more)

### Community 54 - "Service OSM et itinéraires"
Cohesion: 0.11
Nodes (17): calculateDistance, _decodeCoordinates, _extractSteps, formatDistance, formatDuration, getAddressFromCoordinates, getCurrentLocation, getRoute (+9 more)

### Community 55 - "Routeur guides"
Cohesion: 0.15
Nodes (14): get_guide_service(), get_all_guides(), get_guide_contact(), get, post, UploadFile, Controller Profils Guides — vérification d'identité et listing., Listing public des guides approuvés — aucune donnée personnelle. (+6 more)

### Community 56 - "Tests service avis"
Cohesion: 0.27
Nodes (16): ConflictError, _data(), Tests unitaires du ReviewService — règles métier des avis., Un administrateur supprime l'avis d'autrui — droit tiré de ADMIN_EMAILS., La colonne `is_admin` ne donne aucun droit : elle n'est qu'un cache. Elle n'est…, _service(), test_create_review_duplicate_blocked(), test_create_review_rejects_non_tourist() (+8 more)

### Community 57 - "Validateurs Pydantic"
Cohesion: 0.12
Nodes (8): Remplace les backslashes Windows par des slashes URL, Valide le format du numéro de téléphone marocain, Valide que le trajet a suffisamment de points, Valide l'année de naissance, Remplace les backslashes Windows par des slashes URL., Valide que les spécialités sont dans la liste autorisée, Vérifie que guide_details est fourni si role = 'guide, validator

### Community 58 - "Tests API auth"
Cohesion: 0.16
Nodes (15): Tests d'intégration API — flux d'authentification (TestClient + BDD de test)., Une erreur 422 doit être lisible par le client, pas brute de FastAPI. FastAPI…, Ne montrer que la première erreur désignerait un champ arbitraire., Le lien navigateur doit expirer comme l'endpoint POST., Un token émis avant l'incrément doit être refusé après., _registration_body(), test_bumping_token_version_revokes_existing_token(), test_login_success_returns_token() (+7 more)

### Community 59 - "Écran de connexion"
Cohesion: 0.12
Nodes (16): build, createState, dispose, _emailController, _errorMessage, _formKey, _handleLogin, _isLoading (+8 more)

### Community 60 - "Effet shimmer"
Cohesion: 0.13
Nodes (15): Animation, AnimationController, BorderRadius?, _animation, borderRadius, build, _controller, createState (+7 more)

### Community 61 - "Dépôt des circuits"
Cohesion: 0.17
Nodes (5): GuideRoute, Trajets actifs de guides vérifiés, joints au guide et à l'utilisateur (endpoint…, RouteRepository, Session, Session

### Community 62 - "Fixtures de test"
Cohesion: 0.17
Nodes (15): admin_user(), client(), db_session(), _ensure_database_exists(), fixture, Fixtures partagées de la suite de tests Morchid Hub. Deux niveaux : * **unit**…, Session transactionnelle : rollback complet en fin de test (isolation)., Compte administrateur au sens de la nouvelle règle : seul son email, inscrit… (+7 more)

### Community 63 - "Mot de passe oublié"
Cohesion: 0.13
Nodes (15): FormState, build, _buildFormView, _buildSuccessView, createState, dispose, _emailController, _emailSent (+7 more)

### Community 64 - "Démarrage et garde-fous config"
Cohesion: 0.20
Nodes (13): _assert_secret_key_is_safe(), create_app(), Refuse de démarrer avec une clé d'exemple ou trop courte. Échec à l'ouverture…, Gardes de configuration — refus de démarrer avec des réglages non sûrs., test_debug_defaults_to_false(), test_strong_secret_key_is_accepted(), test_weak_secret_key_is_rejected(), Le bootstrap de schéma au démarrage ne doit exister qu'en développement. En… (+5 more)

### Community 65 - "Modèles SQLAlchemy"
Cohesion: 0.16
Nodes (8): GuideRoute, Convertit le modèle en dictionnaire pour la réponse API, Accès aux données de la table `guides`, incluant la recherche filtrée. Le bloc…, Accès aux données de la table `guide_routes` (trajets géolocalisés PostGIS). La…, Service d'abonnement Premium (paiement simulé)., Service des trajets guides : création (règle Premium/limite), consultation,…, Service de recherche et découverte (lecture seule)., Base

### Community 66 - "Tests service admin"
Cohesion: 0.24
Nodes (14): Tests unitaires du AdminService — approbation guides, support, garde-fous., RG15 : impossible d'approuver un guide qui n'a pas soumis ses documents., _service(), test_approve_guide_sets_approved_and_verified(), test_approve_guide_without_documents_raises(), test_approve_non_pending_guide_raises_invalid_status(), test_approve_unknown_guide_raises_not_found(), test_get_stats_aggregates_counts() (+6 more)

### Community 67 - "Profil et agenda"
Cohesion: 0.14
Nodes (13): AgendaScreen, build, profile, build, _buildProfileAvatarWithFallback, createState, _formatDate, _handleLogout (+5 more)

### Community 68 - "Bouton contact WhatsApp"
Cohesion: 0.13
Nodes (14): build, _buildWhatsAppUri, _cleanPhone, guideName, _openWhatsApp, paint, phone, shouldRepaint (+6 more)

### Community 69 - "Coquille de navigation"
Cohesion: 0.14
Nodes (13): ApiError?, build, createState, _currentIndex, _error, initialProfile, initState, _isLoading (+5 more)

### Community 70 - "Service des créneaux"
Cohesion: 0.21
Nodes (7): list_slots(), get, datetime, Session, RG21 : vrai si [start, end] chevauche un créneau non annulé du guide., Normalise en UTC tz-aware pour un stockage/comparaison cohérents (les entrées…, TimeSlotService

### Community 71 - "Garde d'authentification"
Cohesion: 0.15
Nodes (13): error_state.dart, allowedRoles, AuthGuard, _AuthGuardState, build, _checkAuth, child, createState (+5 more)

### Community 72 - "Construction géométrie circuit"
Cohesion: 0.27
Nodes (10): Construit une entité GuideRoute (géométries PostGIS incluses) sans l'insérer., GuideRouteCreate, Schema pour créer un nouveau trajet de guide Reçu depuis le frontend Flutter, _payload(), Tests unitaires de RouteRepository.build_route (construction géométrie…, PostGIS attend (lng, lat) — vérifie l'ordre du start_point., test_build_route_coordinates_json_roundtrip(), test_build_route_empty_checkpoints_default() (+2 more)

### Community 73 - "Tests widgets UI (1)"
Cohesion: 0.17
Nodes (10): main, pump, main, wrap, main, wrap, package:morchid_hub/utils/app_colors.dart, package:morchid_hub/widgets/ui_kit.dart (+2 more)

### Community 74 - "Politique de mot de passe"
Cohesion: 0.21
Nodes (9): Valide la force d'un mot de passe Args: password: Le mot de passe à valider…, validate_password_strength(), Même politique qu'à l'inscription : une réinitialisation ne doit pas permettre…, Applique la politique unique définie dans auth.validate_password_strength., parametrize, Politique de mot de passe — plancher à 10 caractères, lettres + chiffres., test_accepts_strong_password(), test_rejects_letters_only() (+1 more)

### Community 75 - "Tests service guides"
Cohesion: 0.35
Nodes (10): Couche Service — règles métier et orchestration (sans HTTP, sans SQL brut)., _file(), _files(), Tests unitaires du GuideService — soumission de vérification d'identité., _service(), test_submit_verification_already_verified_raises(), test_submit_verification_bad_extension_raises(), test_submit_verification_missing_profile_raises() (+2 more)

### Community 76 - "Tests limite gratuite circuits"
Cohesion: 0.39
Nodes (11): _guide(), _payload(), Tests unitaires du RouteService — règle Premium / limite gratuite (RG20-bis)., _service(), test_create_route_free_limit_reached_blocks_third_route(), test_create_route_free_under_limit_deactivates_previous(), test_create_route_missing_guide_profile_raises(), test_create_route_premium_bypasses_limit() (+3 more)

### Community 77 - "Graphique des revenus"
Cohesion: 0.17
Nodes (11): build, currency, height, paint, points, RevenueBarChart, _short, shouldRepaint (+3 more)

### Community 78 - "Tests navigation et garde"
Cohesion: 0.17
Nodes (9): main, harness, main, main, package:morchid_hub/routes/app_routes.dart, package:morchid_hub/screens/onboarding_screen.dart, package:morchid_hub/services/storage_service.dart, package:morchid_hub/widgets/auth_guard.dart (+1 more)

### Community 79 - "Service de notification"
Cohesion: 0.20
Nodes (4): Session, Service d'authentification et de gestion de compte. Couvre : inscription,…, NotificationService, Service de notification (emails transactionnels). Encapsule `email_utils`…

### Community 80 - "Tests chevauchement créneaux"
Cohesion: 0.47
Nodes (10): _dt(), _existing_slot(), Tests unitaires du TimeSlotService — RG21 (non-chevauchement), propriété,…, _service(), test_cancel_slot_already_cancelled_raises(), test_create_slot_adjacent_ok(), test_create_slot_ignores_cancelled_conflict(), test_create_slot_overlap_rejected_rg21() (+2 more)

### Community 81 - "Tests coquille et erreurs"
Cohesion: 0.18
Nodes (9): BottomNavigationBar, main, _profile, tab, main, wrap, package:morchid_hub/models/user_models.dart, package:morchid_hub/shell/main_shell.dart (+1 more)

### Community 82 - "Validateurs de formulaire"
Cohesion: 0.18
Nodes (10): birthYear, confirmPassword, _email, fullName, _letterAndDigit, password, _phone, required (+2 more)

### Community 83 - "Widget ErrorState"
Cohesion: 0.18
Nodes (10): build, ErrorState, fromApiError, icon, message, onRetry, retryLabel, title (+2 more)

### Community 84 - "Tests validateurs et config API"
Cohesion: 0.18
Nodes (8): main, main, main, wrap, package:flutter_test/flutter_test.dart, package:morchid_hub/services/api_config.dart, package:morchid_hub/utils/validators.dart, package:morchid_hub/widgets/inline_error.dart

### Community 85 - "Fenêtre Premium"
Cohesion: 0.20
Nodes (9): build, _buildBenefit, daysRemaining, isCurrentlyPremium, PremiumModal, show, _upgradeToPremium, int? (+1 more)

### Community 86 - "Tests animations (UI)"
Cohesion: 0.22
Nodes (7): AnimatedScale, main, wrap, main, wrap, Opacity, package:morchid_hub/widgets/motion.dart

### Community 87 - "Configuration URL de l'API"
Cohesion: 0.25
Nodes (7): dart:io, ApiConfig, baseUrl, _override, resolveBaseUrl, static const String, static String get

### Community 88 - "Écran de démarrage"
Cohesion: 0.29
Nodes (7): build, createState, _decide, initState, SplashScreen, _SplashScreenState, ../services/storage_service.dart

### Community 89 - "Limitation de débit"
Cohesion: 0.29
Nodes (7): JSONResponse, Request, rate_limit_handler(), rate_limit_key(), Clé de comptage : IP seule. Les routes visant un compte précis (login, mot de…, Renvoie le format d'erreur standard du projet, pas celui de slowapi., RateLimitExceeded

### Community 90 - "Tests service Premium"
Cohesion: 0.48
Nodes (6): Tests unitaires du PremiumService — activation 30j, no-op si déjà actif., _service(), test_upgrade_already_active_is_noop(), test_upgrade_fresh_activates_30_days_and_records_subscription(), test_upgrade_missing_profile_raises(), test_upgrade_rejects_non_guide()

### Community 91 - "Tests points de passage"
Cohesion: 0.47
Nodes (4): Checkpoint, Tests d'intégration — table `checkpoints` (promotion du JSON, dual-write)., test_build_route_populates_checkpoint_table(), test_create_route_api_writes_checkpoints()

### Community 92 - "Tests service recherche"
Cohesion: 0.53
Nodes (5): Tests unitaires du SearchService — agrégation des valeurs de filtres., _service(), test_available_filters_dedupes_and_sorts(), test_available_filters_handles_empty_fields(), test_search_guides_delegates_to_repository()

### Community 93 - "Dessins personnalisés"
Cohesion: 0.33
Nodes (6): CustomPainter, _RoutePainter, _BarChartPainter, _DashedRectPainter, _KhatimRosePainter, _WhatsAppPainter

### Community 94 - "Tests limitation de débit"
Cohesion: 0.40
Nodes (3): Limitation de débit sur les routes d'authentification., Au-delà du seuil, la route répond 429 dans le format d'erreur du projet., test_login_is_rate_limited()

### Community 95 - "Tests câblage connexions"
Cohesion: 0.40
Nodes (3): parametrize, Garde-fous de câblage : chaque création d'engine passe par build_engine_config.…, test_engine_site_uses_build_engine_config()

### Community 96 - "Tests jetons de design"
Cohesion: 0.40
Nodes (4): dart:async, _allTextStyles, main, package:morchid_hub/theme/app_text_styles.dart

### Community 97 - "Tests groupe de stats"
Cohesion: 0.40
Nodes (4): cells, main, pumpAt, package:morchid_hub/widgets/stat_tile.dart

### Community 99 - "Création de créneau (API)"
Cohesion: 0.50
Nodes (4): create_slot(), post, Corps de POST /api/v1/guides/routes/{route_id}/slots. Programme un créneau pour…, TimeSlotCreate

### Community 100 - "Tests écran recherche"
Cohesion: 0.50
Nodes (3): main, package:morchid_hub/screens/search_screen.dart, TextField

### Community 107 - "Formateurs carte bancaire"
Cohesion: 0.67
Nodes (3): _CardNumberFormatter, _ExpiryFormatter, TextInputFormatter

## Knowledge Gaps
- **980 isolated node(s):** `Config`, `docker-entrypoint.sh script`, `main`, `build`, `UserData` (+975 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `unit` connect `Démarrage et garde-fous config` to `Écran mes sorties et stats`?**
  _High betweenness centrality (0.485) - this node is a cross-community bridge._
- **Why does `create_app()` connect `Démarrage et garde-fous config` to `Tests de divulgation et recherche`, `Gestion des erreurs API`, `Assemblage FastAPI et dépendances`?**
  _High betweenness centrality (0.246) - this node is a cross-community bridge._
- **Are the 5 inferred relationships involving `User` (e.g. with `get_current_user()` and `auth_headers()`) actually correct?**
  _`User` has 5 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `Guide` (e.g. with `make_review()` and `make_route()`) actually correct?**
  _`Guide` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `Config`, `docker-entrypoint.sh script`, `main` to the rest of the system?**
  _980 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Écran carte (Flutter)` be split into smaller, more focused modules?**
  _Cohesion score 0.02631578947368421 - nodes in this community are weakly interconnected._
- **Should `Modèles utilisateur (Dart)` be split into smaller, more focused modules?**
  _Cohesion score 0.02702702702702703 - nodes in this community are weakly interconnected._