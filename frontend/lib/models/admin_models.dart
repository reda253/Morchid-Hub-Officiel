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
      approvalStatus: json['approval_status'] ?? 'pending',
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
// ANALYTICS MODELS (revenu / abonnements réels)
// ============================================

/// KPI globaux du tableau de bord admin (endpoint /admin/analytics/overview).
class RevenueOverview {
  final String currency;
  final double totalRevenue;
  final double revenueThisMonth;
  final double revenueLastMonth;
  final double revenueGrowthPct;
  final int activeSubscriptions;
  final double mrr;
  final int newSubscriptionsThisMonth;
  final int totalSubscriptions;
  final double arpu;

  RevenueOverview({
    required this.currency,
    required this.totalRevenue,
    required this.revenueThisMonth,
    required this.revenueLastMonth,
    required this.revenueGrowthPct,
    required this.activeSubscriptions,
    required this.mrr,
    required this.newSubscriptionsThisMonth,
    required this.totalSubscriptions,
    required this.arpu,
  });

  factory RevenueOverview.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => (v ?? 0).toDouble();
    int i(dynamic v) => (v ?? 0) as int;
    return RevenueOverview(
      currency: json['currency'] ?? 'MAD',
      totalRevenue: d(json['total_revenue']),
      revenueThisMonth: d(json['revenue_this_month']),
      revenueLastMonth: d(json['revenue_last_month']),
      revenueGrowthPct: d(json['revenue_growth_pct']),
      activeSubscriptions: i(json['active_subscriptions']),
      mrr: d(json['mrr']),
      newSubscriptionsThisMonth: i(json['new_subscriptions_this_month']),
      totalSubscriptions: i(json['total_subscriptions']),
      arpu: d(json['arpu']),
    );
  }
}

/// Un point de la série mensuelle du revenu.
class RevenuePoint {
  final String month;   // 'YYYY-MM'
  final String label;   // 'Août'
  final double revenue;
  final int subscriptions;

  RevenuePoint({
    required this.month,
    required this.label,
    required this.revenue,
    required this.subscriptions,
  });

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        month: json['month'] ?? '',
        label: json['label'] ?? '',
        revenue: (json['revenue'] ?? 0).toDouble(),
        subscriptions: (json['subscriptions'] ?? 0) as int,
      );
}

class RevenueTimeseries {
  final String currency;
  final double totalRevenue;
  final List<RevenuePoint> points;

  RevenueTimeseries({
    required this.currency,
    required this.totalRevenue,
    required this.points,
  });

  factory RevenueTimeseries.fromJson(Map<String, dynamic> json) => RevenueTimeseries(
        currency: json['currency'] ?? 'MAD',
        totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
        points: (json['points'] as List<dynamic>? ?? [])
            .map((e) => RevenuePoint.fromJson(e))
            .toList(),
      );
}

/// Répartition des abonnements actifs par tier.
class TierBreakdown {
  final String tier;
  final int active;
  final double revenue;

  TierBreakdown({required this.tier, required this.active, required this.revenue});

  factory TierBreakdown.fromJson(Map<String, dynamic> json) => TierBreakdown(
        tier: json['tier'] ?? '',
        active: (json['active'] ?? 0) as int,
        revenue: (json['revenue'] ?? 0).toDouble(),
      );
}

class SubscriptionsBreakdown {
  final String currency;
  final int activeTotal;
  final List<TierBreakdown> byTier;

  SubscriptionsBreakdown({
    required this.currency,
    required this.activeTotal,
    required this.byTier,
  });

  factory SubscriptionsBreakdown.fromJson(Map<String, dynamic> json) => SubscriptionsBreakdown(
        currency: json['currency'] ?? 'MAD',
        activeTotal: (json['active_total'] ?? 0) as int,
        byTier: (json['by_tier'] as List<dynamic>? ?? [])
            .map((e) => TierBreakdown.fromJson(e))
            .toList(),
      );
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