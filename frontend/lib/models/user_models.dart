import 'dart:convert';

// ============================================
// 📝 MODELS POUR L'INSCRIPTION
// ============================================

class PersonalInfo {
  final String fullName;
  final String email;
  final String phone;
  final String dateOfBirth;

  PersonalInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth,
      };
}

class GuideDetails {
  final List<String> languages;
  final List<String> specialties;
  final List<String> citiesCovered;
  final int yearsOfExperience;
  final String bio;

  GuideDetails({
    required this.languages,
    required this.specialties,
    required this.citiesCovered,
    required this.yearsOfExperience,
    required this.bio,
  });

  Map<String, dynamic> toJson() => {
        'languages': languages,
        'specialties': specialties,
        'cities_covered': citiesCovered,
        'years_of_experience': yearsOfExperience,
        'bio': bio,
      };
}

class UserRegistrationRequest {
  final PersonalInfo personalInfo;
  final String role;
  final String password;
  final GuideDetails? guideDetails;

  UserRegistrationRequest({
    required this.personalInfo,
    required this.role,
    required this.password,
    this.guideDetails,
  });

  Map<String, dynamic> toJson() {
    final json = {
      'personal_info': personalInfo.toJson(),
      'role': role,
      'password': password,
    };

    if (guideDetails != null) {
      json['guide_details'] = guideDetails!.toJson();
    }

    return json;
  }

  String toJsonString() => jsonEncode(toJson());
}

// ============================================
// 👤 MODELS POUR LA CONNEXION
// ============================================

class LoginRequest {
  final String email;
  final String password;

  LoginRequest({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };

  String toJsonString() => jsonEncode(toJson());
}

// ============================================
// 📥 MODELS POUR LES RÉPONSES
// ============================================

class UserData {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  final bool isAdmin; // <--- Add this line
  final bool isActive;
    final bool isEmailVerified;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isAdmin,
    required this.isActive,
    required this.isEmailVerified,
    required this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
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

class GuideProfile {
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
  // ✅ NOUVEAU - URLs des photos
  final String? profilePhotoUrl;
  final String? licenseCardUrl;
  final String? cineCardUrl;

   // ✅ Classement — synchronisés depuis le backend à chaque avis
  final double averageRating;  // 0.0 – 5.0, arrondi 1 décimale
  final int totalReviews;      // Nombre absolu d'avis

  GuideProfile({
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
    this.profilePhotoUrl,      // ✅ Optionnel
    this.licenseCardUrl,        // ✅ Optionnel
    this.cineCardUrl,           // ✅ Optionnel
    this.averageRating = 0.0,
    this.totalReviews  = 0,
  });

  factory GuideProfile.fromJson(Map<String, dynamic> json) {
    return GuideProfile(
      id: json['id'],
      userId: json['user_id'],
      languages: List<String>.from(json['languages']),
      specialties: List<String>.from(json['specialties']),
      citiesCovered: List<String>.from(json['cities_covered']),
      yearsOfExperience: json['years_of_experience'],
      bio: json['bio'],
      isVerified: json['is_verified'] ?? false,
      ecoScore: json['eco_score'] ?? 0,
      approvalStatus: json['approval_status'] ?? 'pending_approval',
       // ✅ NOUVEAU - Récupération des URLs
      profilePhotoUrl: json['profile_photo_url'],
      licenseCardUrl: json['license_card_url'],
      cineCardUrl: json['cine_card_url'],
      averageRating:       (json['average_rating'] ?? 0.0).toDouble(),
      totalReviews:        json['total_reviews']   ?? 0,
    );
  }


// ── Helpers d'affichage ──────────────────────────────────────────────────

  /// "4.7 ★" ou "Nouveau guide" si aucun avis
  String get ratingDisplay =>
      totalReviews == 0 ? 'Nouveau guide' : '${averageRating.toStringAsFixed(1)} ★';

  /// "4.7 ★ (34 avis)" ou "Aucun avis"
  String get ratingWithCount {
    if (totalReviews == 0) return 'Aucun avis';
    final label = totalReviews > 1 ? 'avis' : 'avis';
    return '${averageRating.toStringAsFixed(1)} ★ ($totalReviews $label)';
  }

  /// Renvoie un entier arrondi de la note pour afficher des étoiles pleines
  int get roundedRating => averageRating.round().clamp(0, 5);
}

// ============================================
// ✅ MODELS POUR LES AVIS (REVIEWS)
// ============================================

/// Corps de la requête POST /api/v1/reviews
class ReviewCreateRequest {
  final String guideId;
  final String? routeId;  // Optionnel — avis sur un trajet spécifique
  final int rating;       // 1 à 5 (validé ici et côté backend)
  final String? comment;  // Texte libre, optionnel

  ReviewCreateRequest({
    required this.guideId,
    this.routeId,
    required this.rating,
    this.comment,
  }) : assert(rating >= 1 && rating <= 5, 'La note doit être entre 1 et 5');

  Map<String, dynamic> toJson() => {
        'guide_id': guideId,
        if (routeId != null && routeId!.isNotEmpty) 'route_id': routeId,
        'rating':   rating,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };

  String toJsonString() => jsonEncode(toJson());
}

/// Avis retourné par le backend (GET ou POST /reviews)
class Review {
  final String id;
  final String guideId;
  final String touristId;
  final String touristName;   // Enrichi par le backend depuis users.full_name
  final String? routeId;
  final int rating;           // 1–5
  final String? comment;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.guideId,
    required this.touristId,
    required this.touristName,
    this.routeId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id:           json['id'],
        guideId:      json['guide_id'],
        touristId:    json['tourist_id'],
        touristName:  json['tourist_name'] ?? 'Touriste anonyme',
        routeId:      json['route_id'],
        rating:       json['rating'],
        comment:      json['comment'],
        createdAt:    json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  // ── Helpers d'affichage ──────────────────────────────────────────────────

  /// "★★★★☆"  (étoiles Unicode, toujours 5 caractères)
  String get starsDisplay => '★' * rating + '☆' * (5 - rating);

  /// Date relative : "Il y a 3 jours", "Hier", "Il y a 2 semaines"…
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes <  1)  return 'À l\'instant';
    if (diff.inMinutes < 60)  return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours   <  2)  return 'Il y a 1h';
    if (diff.inHours   < 24)  return 'Il y a ${diff.inHours}h';
    if (diff.inDays    ==  1) return 'Hier';
    if (diff.inDays    <  7)  return 'Il y a ${diff.inDays} jours';
    if (diff.inDays    < 30)  return 'Il y a ${diff.inDays ~/ 7} semaine(s)';
    return '${createdAt.day.toString().padLeft(2,'0')}/'
           '${createdAt.month.toString().padLeft(2,'0')}/'
           '${createdAt.year}';
  }

  /// True si l'avis porte sur un trajet précis
  bool get hasRoute => routeId != null && routeId!.isNotEmpty;
}

/// Réponse de GET /api/v1/guides/{guide_id}/reviews
class ReviewListResponse {
  final String guideId;
  final double averageRating;   // Arrondi 1 décimale (ex: 4.7)
  final int    totalReviews;
  final List<Review> reviews;

  ReviewListResponse({
    required this.guideId,
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
  });

  factory ReviewListResponse.fromJson(Map<String, dynamic> json) =>
      ReviewListResponse(
        guideId:       json['guide_id'],
        averageRating: (json['average_rating'] ?? 0.0).toDouble(),
        totalReviews:  json['total_reviews']   ?? 0,
        reviews: (json['reviews'] as List<dynamic>? ?? [])
            .map((r) => Review.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  /// "4.7 ★ (34 avis)" ou "Aucun avis"
  String get summaryDisplay {
    if (totalReviews == 0) return 'Aucun avis';
    return '${averageRating.toStringAsFixed(1)} ★ ($totalReviews avis)';
  }
}

class RegistrationResponse {
  final String status;
  final String message;
  final UserData user;
  final GuideProfile? guideProfile;

  RegistrationResponse({
    required this.status,
    required this.message,
    required this.user,
    this.guideProfile,
  });

  factory RegistrationResponse.fromJson(Map<String, dynamic> json) {
    return RegistrationResponse(
      status: json['status'],
      message: json['message'],
      user: UserData.fromJson(json['user']),
      guideProfile: json['guide_profile'] != null
          ? GuideProfile.fromJson(json['guide_profile'])
          : null,
    );
  }
}

class LoginResponse {
  final String accessToken;
  final String tokenType;
  final UserData user;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'],
      tokenType: json['token_type'],
      user: UserData.fromJson(json['user']),
    );
  }
}

// ============================================
// ❌ MODEL POUR LES ERREURS
// ============================================

class ApiError {
  final String errorCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiError({
    required this.errorCode,
    required this.message,
    this.details,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      errorCode: json['error_code'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? 'Une erreur est survenue',
      details: json['details'],
    );
  }

  @override
  String toString() => message;
}

// ============================================
// 📧 MODELS POUR VÉRIFICATION & MOT DE PASSE
// ============================================

class ForgotPasswordRequest {
  final String email;

  ForgotPasswordRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
  String toJsonString() => jsonEncode(toJson());
}

class ResetPasswordRequest {
  final String token;
  final String newPassword;

  ResetPasswordRequest({
    required this.token,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'token': token,
        'new_password': newPassword,
      };
  String toJsonString() => jsonEncode(toJson());
}

class VerifyEmailRequest {
  final String token;

  VerifyEmailRequest({required this.token});

  Map<String, dynamic> toJson() => {'token': token};
  String toJsonString() => jsonEncode(toJson());
}

class ResendVerificationRequest {
  final String email;

  ResendVerificationRequest({required this.email});

  Map<String, dynamic> toJson() => {'email': email};
  String toJsonString() => jsonEncode(toJson());
}

class SuccessResponse {
  final String status;
  final String message;
  final Map<String, dynamic>? data;

  SuccessResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory SuccessResponse.fromJson(Map<String, dynamic> json) {
    return SuccessResponse(
      status: json['status'],
      message: json['message'],
      data: json['data'],
    );
  }
}

// ============================================
// 📊 MODELS POUR LE PROFIL COMPLET
// ============================================

class UserProfileResponse {
  final UserData user;
  final GuideProfile? guideProfile;
  final Map<String, dynamic>? stats;

  UserProfileResponse({
    required this.user,
    this.guideProfile,
    this.stats,
  });

  factory UserProfileResponse.fromJson(Map<String, dynamic> json) {
    return UserProfileResponse(
      user: UserData.fromJson(json['user']),
      guideProfile: json['guide_profile'] != null
          ? GuideProfile.fromJson(json['guide_profile'])
          : null,
      stats: json['stats'],
    );
  }
}