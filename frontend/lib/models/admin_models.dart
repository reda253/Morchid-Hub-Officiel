import 'dart:convert';

// ============================================
// USER DATA MODEL
// ============================================

class UserData {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final bool isAdmin; //
  final bool isActive;

  UserData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.isAdmin,
    required this.isActive,
  });

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      id: json['id'],
      fullName: json['full_name'],
      email: json['email'],
      role: json['role'],
      isAdmin: json['is_admin'] ?? false, //
      isActive: json['is_active'] ?? true,
    );
  }
}

// ============================================
// GUIDE PROFILE MODEL (AVEC DOCUMENTS ET REJET)
// ============================================

class GuideProfile {
  final String id;
  final String userId;
  final List<String> specialties;
  final List<String> citiesCovered;
  final int yearsOfExperience;
  final String bio;
  final String approvalStatus;
  
  // ✅ URLs des documents
  final String? profilePhotoUrl;
  final String? licenseCardUrl;
  final String? cineCardUrl;
  
  // ✅ Motif de rejet
  final String? rejectionReason;

  GuideProfile({
    required this.id,
    required this.userId,
    required this.specialties,
    required this.citiesCovered,
    required this.yearsOfExperience,
    required this.bio,
    required this.approvalStatus,
    this.profilePhotoUrl,
    this.licenseCardUrl,
    this.cineCardUrl,
    this.rejectionReason,
  });

  factory GuideProfile.fromJson(Map<String, dynamic> json) {
    return GuideProfile(
      id: json['id'],
      userId: json['user_id'],
      specialties: json['specialties'] != null 
          ? List<String>.from(json['specialties']) 
          : [],
      citiesCovered: json['cities_covered'] != null 
          ? List<String>.from(json['cities_covered']) 
          : [],
      yearsOfExperience: json['years_of_experience'] ?? 0,
      bio: json['bio'] ?? '',
      approvalStatus: json['approval_status'] ?? 'pending_approval',
      profilePhotoUrl: json['profile_photo_url'],
      licenseCardUrl: json['license_card_url'],
      cineCardUrl: json['cine_card_url'],
      rejectionReason: json['rejection_reason'],
    );
  }
}

// ============================================
// SUPPORT MESSAGE MODEL
// ============================================

class SupportMessage {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String message;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  SupportMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.message,
    required this.isResolved,
    required this.createdAt,
    this.resolvedAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      userEmail: json['user_email'],
      subject: json['subject'],
      message: json['message'],
      isResolved: json['is_resolved'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      resolvedAt: json['resolved_at'] != null 
          ? DateTime.parse(json['resolved_at']) 
          : null,
    );
  }
}

// ============================================
// API ERROR MODEL
// ============================================

class ApiError {
  final String errorCode;
  final String message;

  ApiError({required this.errorCode, required this.message});

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      errorCode: json['error_code'] ?? 'UNKNOWN_ERROR',
      message: json['message'] ?? 'Une erreur est survenue',
    );
  }
  
  @override
  String toString() => message;
}

// ============================================
// SUCCESS RESPONSE MODEL
// ============================================

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