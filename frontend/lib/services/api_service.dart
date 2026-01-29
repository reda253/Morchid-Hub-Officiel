import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import '../models/user_models.dart';
import 'storage_service.dart';

/// Service central pour toutes les communications avec l'API Backend
class ApiService {
  // ============================================
  // 🌐 CONFIGURATION
  // ============================================

  // IMPORTANT: Remplacez par l'URL de votre serveur
  // Pour l'émulateur Android: http://10.0.2.2:8000
  // Pour l'émulateur iOS: http://localhost:8000
  // Pour un appareil physique: http://YOUR_COMPUTER_IP:8000
  // static const String baseUrl = 'http://127.0.0.1:8000';
  
  static String get baseUrl {
    if (io.Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Endpoints
  static const String registerEndpoint = '/api/v1/register';
  static const String loginEndpoint = '/api/v1/login';

  // Timeout des requêtes
  static const Duration timeout = Duration(seconds: 30);

  // ============================================
  // 📝 INSCRIPTION (REGISTER)
  // ============================================

  /// Inscrit un nouvel utilisateur (touriste ou guide)
  ///
  /// Throws [ApiError] en cas d'erreur
  static Future<RegistrationResponse> register({
    required UserRegistrationRequest registrationData,
  }) async {
    try {
      print('📤 Envoi de la requête d\'inscription à $baseUrl$registerEndpoint');

      final response = await http
          .post(
            Uri.parse('$baseUrl$registerEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: registrationData.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');
      print('📜 Body: ${response.body}');

      // ============================================
      // GÉRER LES DIFFÉRENTS CODES DE STATUT
      // ============================================

      if (response.statusCode == 201) {
        // Succès - Inscription réussie
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return RegistrationResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        // Erreur de validation (email existe déjà, etc.)
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      } else if (response.statusCode == 500) {
        // Erreur serveur
        String message = 'Erreur du serveur. Veuillez réessayer plus tard.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['details'] != null) {
            message += '\n${errorData['details']}';
          } else if (errorData['message'] != null) {
            message = errorData['message'];
          }
        } catch (_) {}
        
        throw ApiError(
          errorCode: 'SERVER_ERROR',
          message: message,
        );
      } else {
        // Autre erreur
        throw ApiError(
          errorCode: 'UNKNOWN_ERROR',
          message: 'Une erreur inattendue est survenue (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      // Erreur de connexion réseau
      print('❌ Erreur réseau: $e');
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message: 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.',
      );
    } on ApiError {
      // Re-throw les ApiError
      rethrow;
    } catch (e) {
      // Autres erreurs
      print('❌ Erreur inattendue: $e');
      throw ApiError(
        errorCode: 'UNEXPECTED_ERROR',
        message: 'Une erreur inattendue est survenue: ${e.toString()}',
      );
    }
  }

  // ============================================
  // 🔐 CONNEXION (LOGIN)
  // ============================================

  /// Connecte un utilisateur existant
  ///
  /// Sauvegarde automatiquement le token et les données utilisateur en local
  /// Throws [ApiError] en cas d'erreur
  static Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      print('📤 Envoi de la requête de connexion à $baseUrl$loginEndpoint');

      final loginRequest = LoginRequest(email: email, password: password);

      final response = await http
          .post(
            Uri.parse('$baseUrl$loginEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: loginRequest.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');

      // ============================================
      // GÉRER LES DIFFÉRENTS CODES DE STATUT
      // ============================================

      if (response.statusCode == 200) {
        // Succès - Connexion réussie
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(responseData);

        // Sauvegarder le token et les données utilisateur
        await StorageService.saveLoginData(
          accessToken: loginResponse.accessToken,
          userData: loginResponse.user,
        );

        print('✅ Connexion réussie et données sauvegardées localement');
        return loginResponse;
      } else if (response.statusCode == 401) {
        // Identifiants invalides
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      } else if (response.statusCode == 403) {
        // Compte désactivé
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      } else if (response.statusCode == 500) {
        // Erreur serveur
        throw ApiError(
          errorCode: 'SERVER_ERROR',
          message: 'Erreur du serveur. Veuillez réessayer plus tard.',
        );
      } else {
        // Autre erreur
        throw ApiError(
          errorCode: 'UNKNOWN_ERROR',
          message: 'Une erreur inattenue est survenue (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      // Erreur de connexion réseau
      print('❌ Erreur réseau: $e');
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message: 'Impossible de se connecter au serveur. Vérifiez votre connexion internet.',
      );
    } on ApiError {
      // Re-throw les ApiError
      rethrow;
    } catch (e) {
      // Autres erreurs
      print('❌ Erreur inattendue: $e');
      throw ApiError(
        errorCode: 'UNEXPECTED_ERROR',
        message: 'Une erreur inattendue est survenue: ${e.toString()}',
      );
    }
  }

  // ============================================
  // 🚪 DÉCONNEXION (LOGOUT)
  // ============================================

  /// Déconnecte l'utilisateur et supprime les données locales
  static Future<void> logout() async {
    await StorageService.logout();
    print('✅ Déconnexion réussie');
  }

  // ============================================
  // 🔒 REQUÊTES AUTHENTIFIÉES (Pour plus tard)
  // ============================================

  /// Effectue une requête GET authentifiée
  static Future<http.Response> authenticatedGet(String endpoint) async {
    final token = await StorageService.getAccessToken();

    if (token == null) {
      throw ApiError(
        errorCode: 'NOT_AUTHENTICATED',
        message: 'Vous devez être connecté pour effectuer cette action',
      );
    }

    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    ).timeout(timeout);
  }

  /// Effectue une requête POST authentifiée
  static Future<http.Response> authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await StorageService.getAccessToken();

    if (token == null) {
      throw ApiError(
        errorCode: 'NOT_AUTHENTICATED',
        message: 'Vous devez être connecté pour effectuer cette action',
      );
    }

    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(timeout);
  }

  // ============================================
  // 🧪 TEST DE CONNEXION
  // ============================================

  /// Teste la connexion au serveur
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Test de connexion échoué: $e');
      return false;
    }
  }
}