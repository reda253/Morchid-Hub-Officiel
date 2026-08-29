import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_models.dart';

/// Service pour gérer le stockage local des données utilisateur
/// Utilise SharedPreferences pour persister les données
class StorageService {
  // Clés de stockage
  static const String _keyAccessToken = 'access_token';
  static const String _keyUserData = 'user_data';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyLastGuide = 'last_guide_data';

  /// Présentation vue. Volontairement **absente** de [clearLoginData] :
  /// l'introduction est une propriété de l'appareil, pas du compte. Se
  /// déconnecter puis se reconnecter ne doit pas la rejouer.
  static const String _keyOnboardingSeen = 'onboarding_seen';
  // ============================================
  // 💾 SAUVEGARDER LES DONNÉES DE CONNEXION
  // ============================================

  /// Sauvegarde le token et les données utilisateur après connexion
  static Future<void> saveLoginData({
    required String accessToken,
    required UserData userData,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Sauvegarder le token
    await prefs.setString(_keyAccessToken, accessToken);

    // Sauvegarder les données utilisateur en JSON
    final userJson = jsonEncode({
      'id': userData.id,
      'full_name': userData.fullName,
      'email': userData.email,
      'phone': userData.phone,
      'role': userData.role,
      'is_active': userData.isActive,
      'is_admin': userData.isAdmin, // <--- AJOUTEZ CETTE LIGNE ICI ✅
      'is_email_verified': userData.isEmailVerified,
      'created_at': userData.createdAt.toIso8601String(),
    });
    await prefs.setString(_keyUserData, userJson);

    // Marquer comme connecté
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // ============================================
  // 📥 RÉCUPÉRER LES DONNÉES
  // ============================================

  /// Récupère le token d'accès
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  /// Récupère les données utilisateur
  static Future<UserData?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUserData);

    if (userJson == null) return null;

    final Map<String, dynamic> userData = jsonDecode(userJson);
    return UserData.fromJson(userData);
  }

  /// Vérifie si l'utilisateur est connecté
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // ============================================
  // 🗑️ SUPPRIMER LES DONNÉES (LOGOUT)
  // ============================================

  /// Supprime toutes les données de connexion
  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyUserData);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  /// Déconnexion complète
  static Future<void> logout() async {
    await clearLoginData();
  }

  // ============================================
  // 👋 PRÉSENTATION (première ouverture)
  // ============================================

  /// Vrai dès que l'utilisateur a traversé — ou passé — la présentation.
  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingSeen) ?? false;
  }

  /// Marque la présentation comme vue. Appelée aussi bien à la fin du parcours
  /// qu'au « Passer » : dans les deux cas l'utilisateur a tranché.
  static Future<void> markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingSeen, true);
  }
  static Future<void> saveLastGuide(Map<String, dynamic> guideData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastGuide, jsonEncode(guideData));
  }
  static Future<Map<String, dynamic>?> getLastGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_keyLastGuide);
    return data != null ? jsonDecode(data) : null;
  }
}