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
  final bool isActive;
  final DateTime createdAt;

  UserData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.createdAt,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      phone: json['phone'],
      role: json['role'],
      isActive: json['is_active'] ?? true,
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
    );
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