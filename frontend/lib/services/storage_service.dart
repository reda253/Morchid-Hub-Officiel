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
}