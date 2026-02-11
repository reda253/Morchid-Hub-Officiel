/// Modèles Dart pour les réponses de l'API de recherche.
/// À placer dans lib/models/search_models.dart

// ============================================
// MODÈLE : SearchGuideResult
// Correspond à SearchGuideResponse (backend)
// Utilisé pour GET /api/v1/search/guides
// ============================================

class SearchGuideUserInfo {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isAdmin;
  final bool isActive;
  final bool isEmailVerified;
  final DateTime createdAt;

  SearchGuideUserInfo({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.isActive,
    required this.isEmailVerified,
    required this.createdAt,
  });

  factory SearchGuideUserInfo.fromJson(Map<String, dynamic> json) {
    return SearchGuideUserInfo(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      role: json['role'],
      isAdmin: json['is_admin'] ?? false,
      isActive: json['is_active'] ?? true,
      isEmailVerified: json['is_email_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class SearchGuideInfo {
  final String id;
  final String userId;
  final List<String> languages;
  final List<String> specialties;
  final List<String> citiesCovered;
  final int yearsOfExperience;
  final String bio;
  final bool isVerified;
  final int ecoScore;
  final String approvalStatus;
  final String? profilePhotoUrl;
  final String? licenseCardUrl;
  final String? cineCardUrl;

  // ✅ NOUVEAU
  final double averageRating;
  final int totalReviews;

  SearchGuideInfo({
    required this.id,
    required this.userId,
    required this.languages,
    required this.specialties,
    required this.citiesCovered,
    required this.yearsOfExperience,
    required this.bio,
    required this.isVerified,
    required this.ecoScore,
    required this.approvalStatus,
    this.profilePhotoUrl,
    this.licenseCardUrl,
    this.cineCardUrl,
    this.averageRating = 0.0,
    this.totalReviews = 0,
  });

  factory SearchGuideInfo.fromJson(Map<String, dynamic> json) {
    return SearchGuideInfo(
      id: json['id'],
      userId: json['user_id'],
      languages: List<String>.from(json['languages'] ?? []),
      specialties: List<String>.from(json['specialties'] ?? []),
      citiesCovered: List<String>.from(json['cities_covered'] ?? []),
      yearsOfExperience: json['years_of_experience'] ?? 0,
      bio: json['bio'] ?? '',
      isVerified: json['is_verified'] ?? false,
      ecoScore: json['eco_score'] ?? 0,
      approvalStatus: json['approval_status'] ?? 'approved',
      profilePhotoUrl: json['profile_photo_url'],
      licenseCardUrl: json['license_card_url'],
      cineCardUrl: json['cine_card_url'],
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
    );
  }
}

/// Résultat de /search/guides (user + guide imbriqués)
class SearchGuideResult {
  final SearchGuideUserInfo user;
  final SearchGuideInfo guide;

  SearchGuideResult({required this.user, required this.guide});

  factory SearchGuideResult.fromJson(Map<String, dynamic> json) {
    return SearchGuideResult(
      user: SearchGuideUserInfo.fromJson(json['user']),
      guide: SearchGuideInfo.fromJson(json['guide']),
    );
  }

  // Helpers pratiques
  String get fullName => user.fullName;
  String get profilePhotoUrl => guide.profilePhotoUrl ?? '';
  double get rating => guide.averageRating;
  int get reviews => guide.totalReviews;
  bool get isVerified => guide.isVerified;
}


// ============================================
// MODÈLE : SearchRouteResult
// Correspond à SearchRouteResponse (backend)
// Utilisé pour GET /api/v1/search/guides-with-routes
// ============================================

class ActiveRouteInfo {
  final String routeId;
  final double distance;         // en kilomètres
  final double duration;         // en minutes
  final String? startAddress;
  final String? endAddress;
  final int coordinatesCount;    // nombre de points GPS

  ActiveRouteInfo({
    required this.routeId,
    required this.distance,
    required this.duration,
    this.startAddress,
    this.endAddress,
    this.coordinatesCount = 0,
  });

  factory ActiveRouteInfo.fromJson(Map<String, dynamic> json) {
    return ActiveRouteInfo(
      routeId: json['route_id'],
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: (json['duration'] ?? 0.0).toDouble(),
      startAddress: json['start_address'],
      endAddress: json['end_address'],
      coordinatesCount: json['coordinates_count'] ?? 0,
    );
  }

  /// Formate la distance pour l'affichage (ex: "5.2 km")
  String get distanceFormatted {
    if (distance < 1.0) {
      return '${(distance * 1000).toInt()} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }

  /// Formate la durée pour l'affichage (ex: "1h 30min" ou "45 min")
  String get durationFormatted {
    final totalMinutes = duration.toInt();
    if (totalMinutes < 60) return '$totalMinutes min';
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
  }
}

/// Résultat de /search/guides-with-routes (structure plate + trajet actif)
class SearchRouteResult {
  // Identité
  final String userId;
  final String guideId;
  final String fullName;
  final String? profilePhotoUrl;

  // Informations professionnelles
  final List<String> languages;
  final List<String> specialties;
  final List<String> citiesCovered;
  final int yearsOfExperience;
  final String bio;
  final bool isVerified;

  // Scores
  final int ecoScore;
  final double averageRating;
  final int totalReviews;

  // ✅ Trajet actif (null si le guide n'a pas de trajet)
  final ActiveRouteInfo? activeRoute;

  SearchRouteResult({
    required this.userId,
    required this.guideId,
    required this.fullName,
    this.profilePhotoUrl,
    required this.languages,
    required this.specialties,
    required this.citiesCovered,
    required this.yearsOfExperience,
    required this.bio,
    required this.isVerified,
    required this.ecoScore,
    required this.averageRating,
    required this.totalReviews,
    this.activeRoute,
  });

  factory SearchRouteResult.fromJson(Map<String, dynamic> json) {
    return SearchRouteResult(
      userId: json['user_id'],
      guideId: json['guide_id'],
      fullName: json['full_name'] ?? '',
      profilePhotoUrl: json['profile_photo_url'],
      languages: List<String>.from(json['languages'] ?? []),
      specialties: List<String>.from(json['specialties'] ?? []),
      citiesCovered: List<String>.from(json['cities_covered'] ?? []),
      yearsOfExperience: json['years_of_experience'] ?? 0,
      bio: json['bio'] ?? '',
      isVerified: json['is_verified'] ?? false,
      ecoScore: json['eco_score'] ?? 0,
      averageRating: (json['average_rating'] ?? 0.0).toDouble(),
      totalReviews: json['total_reviews'] ?? 0,
      activeRoute: json['active_route'] != null
          ? ActiveRouteInfo.fromJson(json['active_route'])
          : null,
    );
  }

  /// True si ce guide a un trajet actif défini
  bool get hasRoute => activeRoute != null;

  /// Affichage de la note (ex: "4.7 ★ (34 avis)")
  String get ratingDisplay {
    if (totalReviews == 0) return 'Nouveau guide';
    return '${averageRating.toStringAsFixed(1)} ★ ($totalReviews avis)';
  }
}


// ============================================
// MODÈLE : SearchFilters
// Correspond à GET /api/v1/search/filters
// ============================================

class SearchFilters {
  final List<String> cities;
  final List<String> specialties;
  final List<String> languages;
  final int totalGuides;

  SearchFilters({
    required this.cities,
    required this.specialties,
    required this.languages,
    required this.totalGuides,
  });

  factory SearchFilters.fromJson(Map<String, dynamic> json) {
    return SearchFilters(
      cities: List<String>.from(json['cities'] ?? []),
      specialties: List<String>.from(json['specialties'] ?? []),
      languages: List<String>.from(json['languages'] ?? []),
      totalGuides: json['total_guides'] ?? 0,
    );
  }
}