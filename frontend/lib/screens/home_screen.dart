import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_models.dart';
import '../widgets/shimmer_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfileResponse? _userProfile;
  bool _isLoading = true;
  String? _error;
  int _currentIndex = 0;


  // Couleurs du design system
  static const Color primaryColor = Color(0xFF2D6A4F);
  static const Color secondaryColor = Color(0xFF1B4332);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2B2D42);
  static const Color textLight = Color(0xFF8D99AE);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFE63946);
  static const Color successColor = Color(0xFF2D6A4F); // Using primary color as success for consistency, or a green

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await ApiService.getUserProfile();
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================
  // 🚪 DÉCONNEXION
  // ============================================
  Future<void> _handleLogout() async {
    // Afficher une confirmation
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: errorColor,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await StorageService.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }


  // ============================================
  // 🗺️ GESTION DES TRAJETS (ROUTES)
  // ============================================

  Future<void> _createRoute() async {
    final routeData = await Navigator.pushNamed(
      context,
      '/map',
      arguments: {'mode': 'edit'},
    ) as Map<String, dynamic>?;

    if (routeData != null) {
      try {
        await ApiService.saveGuideRoute(routeData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Trajet enregistré avec succès'),
              backgroundColor: successColor, // Utilise ta variable successColor
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: ${e.toString()}'),
              backgroundColor: errorColor, // Utilise ta variable errorColor
            ),
          );
        }
      }
    }
  }

  Future<void> _viewRoute(String guideId) async {
    final route = await ApiService.getGuideRoute(guideId);
    if (route != null) {
      Navigator.pushNamed(
        context,
        '/map',
        arguments: {
          'mode': 'view',
          'savedRoute': route,
        },
      );
    } else {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ℹ️ Ce guide n\'a pas encore de trajet')),
      );
    }
  }

  // ============================================
  // 🖼️ HELPER POUR AFFICHER L'AVATAR AVEC PHOTO
  // ============================================
  Widget _buildProfileAvatar({
    required String fullName,
    String? photoUrl,
    required double radius,
    double fontSize = 24,
  }) {
    // Si pas de photo, afficher les initiales
    if (photoUrl == null || photoUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor,
        child: Text(
          fullName[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    // Nettoyer l'URL pour éviter les doubles slashes //
String cleanPhotoUrl = photoUrl.startsWith('/') ? photoUrl.substring(1) : photoUrl;
String imageUrl = '${ApiService.baseUrl}/$cleanPhotoUrl';

// Debug : Ajoute ce print pour voir l'URL exacte générée dans la console d'Android Studio
print('DEBUG URL IMAGE: $imageUrl');

    // Afficher la photo avec gestion d'erreur
    return CircleAvatar(
      radius: radius,
      backgroundColor: primaryColor,
      child: CircleAvatar(
        radius: radius - 2,
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // En cas d'erreur, l'avatar par défaut sera affiché
          print('Erreur de chargement image: $exception');
        },
        child: Container(), // Vide pour montrer l'image de fond
      ),
    );
  }

  // Alternative avec gestion d'erreur plus visible
  Widget _buildProfileAvatarWithFallback({
    required String fullName,
    String? photoUrl,
    required double radius,
    double fontSize = 24,
  }) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return _buildDefaultAvatar(fullName, radius, fontSize);
    }

    String imageUrl = photoUrl;
    if (!photoUrl.startsWith('http')) {
      imageUrl = '${ApiService.baseUrl}/$photoUrl';
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultAvatar(fullName, radius, fontSize);
          },
          errorBuilder: (context, error, stackTrace) {
            print('Erreur image: $error');
            return _buildDefaultAvatar(fullName, radius, fontSize);
          },
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(String fullName, double radius, double fontSize) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: primaryColor,
      child: Text(
        fullName[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_error != null) {
      return _buildErrorScreen();
    }

    if (_userProfile == null) {
      return _buildErrorScreen();
    }

    // ============================================
    // 📱 NAVIGATION PAR ONGLETS
    // ============================================
    return Scaffold(
      backgroundColor: backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Page Accueil/Dashboard
          _userProfile!.user.role == 'guide'
              ? _buildGuideDashboard()
              : _buildTouristDashboard(),
          // Page Réservations/Agenda
          _userProfile!.user.role == 'guide'
              ? _buildGuideAgenda()
              : _buildReservations(),
          // Page Profil
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: _userProfile!.user.role == 'guide'
          ? _buildGuideBottomNav()
          : _buildTouristBottomNav(),
    );
  }

  // ============================================
  // 🔄 ÉCRAN DE CHARGEMENT
  // ============================================
  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const ShimmerWidget(width: 200, height: 32),
              const SizedBox(height: 8),
              const ShimmerWidget(width: 150, height: 20),
              const SizedBox(height: 40),
              Expanded(
                child: ListView.separated(
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (_, __) => const ShimmerCard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // ❌ ÉCRAN D'ERREUR
  // ============================================
  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Colors.red,
                ),
                const SizedBox(height: 24),
                Text(
                  _error ?? 'Une erreur est survenue',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _loadUserProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================
  // 🎒 DASHBOARD TOURISTE
  // ============================================
  Widget _buildTouristDashboard() {
    final user = _userProfile!.user;
    final stats = _userProfile!.stats ?? {};

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header avec nom complet
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ✅ CORRECTION: Affichage du nom complet
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white,
                        child: Text(
                          user.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Barre de recherche
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: textLight),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Rechercher une destination...',
                              hintStyle: TextStyle(color: textLight),
                              border: InputBorder.none,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fonctionnalité à venir !'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Statistiques
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate([
                _buildStatCard(
                  icon: Icons.bookmark,
                  title: 'Réservations',
                  value: stats['total_bookings']?.toString() ?? '0',
                  color: primaryColor,
                ),
                _buildStatCard(
                  icon: Icons.favorite,
                  title: 'Favoris',
                  value: stats['favorites']?.toString() ?? '0',
                  color: Colors.red,
                ),
              ]),
            ),
          ),

          // ✅ Section Guides avec bouton Voir trajet
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Découvrir les trajets',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Carte du trajet
                  InkWell(
                    onTap: () {
                      // TODO: Récupérer le trajet depuis l'API
                      final savedRoute = {
                        // Exemple de données (à remplacer par les vraies données de l'API)
                        'coordinates': [
                          {'lat': 33.5731, 'lng': -7.5898},
                          {'lat': 33.5850, 'lng': -7.6100},
                        ],
                        'distance': 5.2,
                        'duration': 15.0,
                        'start_address': 'Casablanca Marina',
                        'end_address': 'Mosquée Hassan II',
                      };
                      
                      Navigator.pushNamed(
                        context,
                        '/map',
                        arguments: {
                          'mode': 'view',
                          'savedRoute': savedRoute,
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.map,
                              color: primaryColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Voir le trajet du guide',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Découvrez l\'itinéraire préparé',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: primaryColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 🎯 DASHBOARD GUIDE
  // ============================================
  Widget _buildGuideDashboard() {
    final user = _userProfile!.user;
    final guide = _userProfile!.guideProfile;
    final stats = _userProfile!.stats ?? {};

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header avec nom complet
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bonjour,',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // ✅ CORRECTION: Affichage du nom complet
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      _buildProfileAvatarWithFallback(
                        fullName: user.fullName,
                        photoUrl: guide?.profilePhotoUrl,
                        radius: 28,
                        fontSize: 24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ✅ BANDEAU DE CERTIFICATION (si non vérifié)
          if (guide != null && !guide.isVerified)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: warningColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Compte en attente de vérification',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Votre profil est en cours de vérification par notre équipe.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Statistiques
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
              ),
              delegate: SliverChildListDelegate([
                _buildStatCard(
                  icon: Icons.calendar_today,
                  title: 'Réservations',
                  value: stats['total_bookings']?.toString() ?? '0',
                  color: primaryColor,
                ),
                _buildStatCard(
                  icon: Icons.eco,
                  title: 'Éco-Score',
                  value: guide?.ecoScore.toString() ?? '0',
                  color: Colors.green,
                ),
                _buildStatCard(
                  icon: Icons.star,
                  title: 'Avis',
                  value: stats['total_reviews']?.toString() ?? '0',
                  color: Colors.amber,
                ),
                _buildStatCard(
                  icon: Icons.attach_money,
                  title: 'Revenus',
                  value: '${stats['total_revenue'] ?? 0} DH',
                  color: Colors.blue,
                ),
              ]),
            ),
          ),

          // Actions rapides
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Actions Rapides',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.verified_user,
                    title: 'Demander la certification',
                    subtitle: 'Obtenez votre badge officiel',
                    enabled: guide?.isVerified == false,
                    onTap: () {
                      
                          Navigator.pushNamed(context, '/verify-guide');
                    },
                  ),
                  const SizedBox(height: 40),
                  // ============================================
                  // NOUVEAU: Bouton Définir mon trajet
                  // ============================================
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.map,
                    title: 'Définir mon trajet',
                    subtitle: 'Créez un itinéraire pour vos clients',
                    enabled: true,
                    onTap: () async {
                      final result = await Navigator.pushNamed(
                        context, 
                        '/map', 
                        arguments: {'mode': 'edit'}
                      );
                      
                      if (result != null) {
                        try {
                          await ApiService.saveGuideRoute(result as Map<String, dynamic>);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Trajet mis à jour !'), backgroundColor: successColor)
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: errorColor)
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 📅 PAGE RÉSERVATIONS (TOURISTE)
  // ============================================
  Widget _buildReservations() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Aucune réservation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vous n\'avez aucune réservation en cours.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textLight,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _currentIndex = 0);
                },
                icon: const Icon(Icons.search),
                label: const Text('Découvrir les guides'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // 📆 PAGE AGENDA (GUIDE)
  // ============================================
  Widget _buildGuideAgenda() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available_outlined,
                  size: 80,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Agenda vide',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Vous n\'avez aucune réservation planifiée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // 👤 PAGE PROFIL
  // ============================================
  Widget _buildProfile() {
    final user = _userProfile!.user;
    final guide = _userProfile!.guideProfile;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Avatar
            // ✅ Avatar avec PHOTO pour les guides
            _buildProfileAvatarWithFallback(
              fullName: user.fullName,
              photoUrl: guide?.profilePhotoUrl,
              radius: 60,
              fontSize: 48,
            ),
            const SizedBox(height: 24),
            // Nom complet
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Badge rôle
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: user.role == 'guide' 
                    ? primaryColor.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    user.role == 'guide' ? Icons.tour : Icons.flight_takeoff,
                    size: 18,
                    color: user.role == 'guide' ? primaryColor : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user.role == 'guide' ? 'Guide Touristique' : 'Touriste',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: user.role == 'guide' ? primaryColor : Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Informations
            _buildInfoCard(
              title: 'Informations personnelles',
              children: [
                _buildInfoRow(Icons.email, 'Email', user.email),
                _buildInfoRow(Icons.phone, 'Téléphone', user.phone),
                _buildInfoRow(
                  Icons.verified_user,
                  'Email vérifié',
                  user.isEmailVerified ? 'Oui' : 'Non',
                  valueColor: user.isEmailVerified ? Colors.green : Colors.orange,
                ),
                _buildInfoRow(
                  Icons.calendar_today,
                  'Membre depuis',
                  _formatDate(user.createdAt),
                ),
              ],
            ),

            // Informations guide (si applicable)
            if (guide != null) ...[
              const SizedBox(height: 16),
              _buildInfoCard(
                title: 'Profil Guide',
                children: [
                  _buildInfoRow(
                    Icons.eco,
                    'Éco-Score',
                    '${guide.ecoScore}/100',
                  ),
                  _buildInfoRow(
                    Icons.verified,
                    'Statut',
                    guide.isVerified ? 'Vérifié' : 'En attente',
                    valueColor: guide.isVerified ? Colors.green : warningColor,
                  ),
                  _buildInfoRow(
                    Icons.work,
                    'Expérience',
                    '${guide.yearsOfExperience} ans',
                  ),
                  _buildInfoRow(
                    Icons.language,
                    'Langues',
                    guide.languages.join(', '),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 32),

            // Bouton déconnexion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Déconnexion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: errorColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ============================================
  // 🎨 WIDGETS HELPERS
  // ============================================

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? primaryColor.withOpacity(0.2) : Colors.grey.shade300,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enabled
                      ? primaryColor.withOpacity(0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: enabled ? primaryColor : textLight,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled ? textDark : textLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: enabled ? primaryColor : textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ============================================
  // 🔽 BOTTOM NAVIGATION BARS
  // ============================================

  BottomNavigationBar _buildTouristBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      selectedItemColor: primaryColor,
      unselectedItemColor: textLight,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bookmark),
          label: 'Réservations',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  BottomNavigationBar _buildGuideBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      selectedItemColor: primaryColor,
      unselectedItemColor: textLight,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Agenda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}