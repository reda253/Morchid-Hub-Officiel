import 'dart:convert';
import 'dart:io' as io;
import 'package:http/http.dart' as http;
import '../models/user_models.dart';
import '../models/search_models.dart'; // ✅ NOUVEAU : modèles de recherche
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
  static const String profileEndpoint = '/api/v1/auth/me';
  static const String forgotPasswordEndpoint = '/api/v1/auth/forgot-password';
  static const String resetPasswordEndpoint = '/api/v1/auth/reset-password';
  static const String verifyEmailEndpoint = '/api/v1/auth/verify-email';
  static const String resendVerificationEndpoint = '/api/v1/auth/resend-verification';
  static const String verifyGuideEndpoint = '/api/v1/auth/verify-guide';
  static const String premiumEndpoint = '/api/v1/guides/upgrade-premium';

  // ✅ NOUVEAUX endpoints de recherche
  static const String searchGuidesEndpoint          = '/api/v1/search/guides';
  static const String searchGuidesWithRoutesEndpoint = '/api/v1/search/guides-with-routes';
  static const String searchFiltersEndpoint          = '/api/v1/search/filters';

  // ── ✅ Endpoints Avis ─────────────────────────────────────────────────────
  static const String _reviewsBase = '/api/v1/reviews';
  static String _guideReviewsEndpoint(String guideId) =>
      '/api/v1/guides/$guideId/reviews';

  // Timeout des requêtes
  static const Duration timeout = Duration(seconds: 60);

  /// Headers sans token (endpoints publics)
  static Map<String, String> _publicHeaders() =>
      {'Content-Type': 'application/json', 'Accept': 'application/json'};

 

   static Future<http.Response> _authenticatedPost(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    return http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: await _getAuthHeaders(),
          body:    jsonEncode(body),
        )
        .timeout(timeout);
  }
   /// DELETE authentifié
  static Future<http.Response> _authenticatedDelete(String endpoint) async {
    return http
        .delete(
          Uri.parse('$baseUrl$endpoint'),
          headers: await _getAuthHeaders(),
        )
        .timeout(timeout);
  }


  

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
  // 👤 PROFIL UTILISATEUR
  // ============================================

  /// Récupère le profil complet de l'utilisateur connecté
  static Future<UserProfileResponse> getUserProfile() async {
    try {
      print('📤 Récupération du profil utilisateur');

      final response = await authenticatedGet(profileEndpoint);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return UserProfileResponse.fromJson(responseData);
      } else if (response.statusCode == 401) {
        // Token invalide, déconnecter l'utilisateur
        await logout();
        throw ApiError(
          errorCode: 'UNAUTHORIZED',
          message: 'Session expirée. Veuillez vous reconnecter.',
        );
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'PROFILE_ERROR',
        message: 'Erreur lors de la récupération du profil: ${e.toString()}',
      );
    }
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
   // ============================================
  // 📧 VÉRIFICATION EMAIL
  // ============================================

  /// Vérifie l'email avec le token reçu
  static Future<SuccessResponse> verifyEmail({
    required String token,
  }) async {
    try {
      print('📤 Vérification email avec token');

      final request = VerifyEmailRequest(token: token);

      final response = await http
          .post(
            Uri.parse('$baseUrl$verifyEmailEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: request.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return SuccessResponse.fromJson(responseData);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'VERIFICATION_ERROR',
        message: 'Erreur lors de la vérification: ${e.toString()}',
      );
    }
  }

  /// Renvoie l'email de vérification
  static Future<SuccessResponse> resendVerification({
    required String email,
  }) async {
    try {
      print('📤 Renvoi email de vérification à $email');

      final request = ResendVerificationRequest(email: email);

      final response = await http
          .post(
            Uri.parse('$baseUrl$resendVerificationEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: request.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return SuccessResponse.fromJson(responseData);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'RESEND_ERROR',
        message: 'Erreur lors du renvoi: ${e.toString()}',
      );
    }
  }

  // ============================================
  // 🔐 MOT DE PASSE OUBLIÉ
  // ============================================

  /// Demande un lien de réinitialisation de mot de passe
  static Future<SuccessResponse> forgotPassword({
    required String email,
  }) async {
    try {
      print('📤 Demande de réinitialisation pour $email');

      final request = ForgotPasswordRequest(email: email);

      final response = await http
          .post(
            Uri.parse('$baseUrl$forgotPasswordEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: request.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return SuccessResponse.fromJson(responseData);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'FORGOT_PASSWORD_ERROR',
        message: 'Erreur lors de la demande: ${e.toString()}',
      );
    }
  }

  /// Réinitialise le mot de passe avec le token
  static Future<SuccessResponse> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      print('📤 Réinitialisation du mot de passe');

      final request = ResetPasswordRequest(
        token: token,
        newPassword: newPassword,
      );

      final response = await http
          .post(
            Uri.parse('$baseUrl$resetPasswordEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: request.toJsonString(),
          )
          .timeout(timeout);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return SuccessResponse.fromJson(responseData);
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'RESET_PASSWORD_ERROR',
        message: 'Erreur lors de la réinitialisation: ${e.toString()}',
      );
    }
  }



  // ============================================
  // 🎫 VÉRIFICATION GUIDE (NOUVEAU)
  // ============================================

  /// Soumet les documents d'identité pour vérification du guide
  static Future<SuccessResponse> submitGuideVerification({
    required String cineNumber,
    required String licenseNumber,
    required io.File profilePhoto,
    required io.File licensePhoto,
    required io.File cinePhoto,
  }) async {
    try {
      print('📤 Envoi des documents de vérification');

      // Récupérer le token d'authentification
      final token = await StorageService.getAccessToken();
      if (token == null) {
        throw ApiError(
          errorCode: 'NOT_AUTHENTICATED',
          message: 'Vous devez être connecté',
        );
      }

      // Créer une requête multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$verifyGuideEndpoint'),
      );

      // Ajouter le token d'authentification
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      // Ajouter les champs texte
      request.fields['cine_number'] = cineNumber;
      request.fields['license_number'] = licenseNumber;

      // Ajouter les fichiers
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_photo',
          profilePhoto.path,
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'license_photo',
          licensePhoto.path,
        ),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'cine_photo',
          cinePhoto.path,
        ),
      );

      print('📤 Envoi de ${request.files.length} fichiers...');

      // Envoyer la requête
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Réponse reçue: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return SuccessResponse.fromJson(responseData);
      } else if (response.statusCode == 400) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      } else if (response.statusCode == 401) {
        throw ApiError(
          errorCode: 'UNAUTHORIZED',
          message: 'Session expirée. Veuillez vous reconnecter.',
        );
      } else if (response.statusCode == 403) {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        throw ApiError.fromJson(errorData);
      } else {
        throw ApiError(
          errorCode: 'UPLOAD_ERROR',
          message: 'Erreur lors de l\'envoi des documents (${response.statusCode})',
        );
      }
    } on http.ClientException catch (e) {
      print('❌ Erreur réseau: $e');
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message: 'Erreur de connexion. Vérifiez votre connexion internet.',
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      print('❌ Erreur inattendue: $e');
      throw ApiError(
        errorCode: 'UNEXPECTED_ERROR',
        message: 'Erreur inattendue: ${e.toString()}',
      );
    }
  }



  // Obtenir les headers avec authentification
static Future<Map<String, String>> _getAuthHeaders() async {
  final token = await StorageService.getAccessToken();
  return {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };
}

// Sauvegarder un trajet
static Future<Map<String, dynamic>> saveGuideRoute(Map<String, dynamic> routeData) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/guides/routes'),
      headers: await _getAuthHeaders(),
      body: jsonEncode(routeData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw ApiError(
        errorCode: error['error_code'] ?? 'SAVE_ERROR',
        message: error['message'] ?? 'Erreur lors de la sauvegarde',
      );
    }
  } catch (e) {
    throw ApiError(
      errorCode: 'NETWORK_ERROR',
      message: 'Erreur de connexion: ${e.toString()}',
    );
  }
}

// Récupérer un trajet
static Future<Map<String, dynamic>?> getGuideRoute(String guideId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/guides/$guideId/route'),
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Erreur ${response.statusCode}');
    }
  } catch (e) {
    print('Erreur lors de la récupération: $e');
    return null;
  }
}

// ============================================
  // ✅ RECHERCHE DE GUIDES (AMÉLIORÉE)
  // ============================================

  /// Recherche des guides avec filtres avancés (sans trajet)
  ///
  /// Retourne une liste de [SearchGuideResult] (contient user + guide imbriqués).
  /// Utilisé pour la page de liste simple des guides.
  static Future<List<SearchGuideResult>> searchGuides({
    String? query,
    String? city,
    String? specialty,
    String? language,
    int? minExperience,
    double? minRating,      // ✅ NOUVEAU
    int? minEcoScore,       // ✅ NOUVEAU
    bool verifiedOnly = false,
    int limit = 20,         // ✅ NOUVEAU : pagination
    int offset = 0,         // ✅ NOUVEAU : pagination
  }) async {
    try {
      final params = <String, String>{};

      if (query != null && query.isNotEmpty)       params['q']              = query;
      if (city != null && city.isNotEmpty)         params['city']           = city;
      if (specialty != null && specialty.isNotEmpty) params['specialty']    = specialty;
      if (language != null && language.isNotEmpty) params['language']       = language;
      if (minExperience != null)                   params['min_experience'] = minExperience.toString();
      if (minRating != null)                       params['min_rating']     = minRating.toString();
      if (minEcoScore != null)                     params['min_eco_score']  = minEcoScore.toString();
      params['verified_only'] = verifiedOnly.toString();
      params['limit']  = limit.toString();
      params['offset'] = offset.toString();

      final uri = Uri.parse('$baseUrl$searchGuidesEndpoint')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => SearchGuideResult.fromJson(json))
            .toList();
      } else {
          final dynamic errorData = jsonDecode(response.body); 
          if (errorData is Map<String, dynamic>) {
             throw ApiError.fromJson(errorData);
        }else {
          throw ApiError(
            errorCode: 'SEARCH_ERROR', 
            message: 'Erreur serveur lors de la recherche: ${response.body}'
          );
        }  
          }
    
    } catch (e) {
      throw ApiError(errorCode: 'SEARCH_ERROR', message: 'Erreur de recherche: $e');
    }
  }

  /// ✅ NOUVEAU : Recherche des guides avec leur trajet actif
  ///
  /// Retourne une liste de [SearchRouteResult] (guide + trajet actif).
  /// Utilisé pour la carte interactive et la recherche par parcours.
  static Future<List<SearchRouteResult>> searchGuidesWithRoutes({
    String? query,
    String? city,
    String? specialty,
    String? language,
    int? minExperience,
    double? minRating,
    int? minEcoScore,
    bool verifiedOnly = false,
    String? routeQuery,              // Recherche dans les adresses du trajet
    bool includeWithoutRoute = false, // Inclure les guides sans trajet
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{};

      if (query != null && query.isNotEmpty)       params['q']              = query;
      if (city != null && city.isNotEmpty)         params['city']           = city;
      if (specialty != null && specialty.isNotEmpty) params['specialty']    = specialty;
      if (language != null && language.isNotEmpty) params['language']       = language;
      if (minExperience != null)                   params['min_experience'] = minExperience.toString();
      if (minRating != null)                       params['min_rating']     = minRating.toString();
      if (minEcoScore != null)                     params['min_eco_score']  = minEcoScore.toString();
      if (routeQuery != null && routeQuery.isNotEmpty) params['route_query'] = routeQuery;
      params['verified_only']         = verifiedOnly.toString();
      params['include_without_route'] = includeWithoutRoute.toString();
      params['limit']  = limit.toString();
      params['offset'] = offset.toString();

      final uri = Uri.parse('$baseUrl$searchGuidesWithRoutesEndpoint')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((json) => SearchRouteResult.fromJson(json))
            .toList();
      } else {
        throw ApiError.fromJson(jsonDecode(response.body));
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(errorCode: 'SEARCH_ROUTES_ERROR', message: 'Erreur de recherche: $e');
    }
  }

  /// ✅ NOUVEAU : Récupère les valeurs disponibles pour les filtres de recherche
  ///
  /// Utilisé pour peupler les dropdowns (villes, spécialités, langues).
  static Future<SearchFilters> getSearchFilters() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl$searchFiltersEndpoint'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        return SearchFilters.fromJson(jsonDecode(response.body));
      } else {
        throw ApiError.fromJson(jsonDecode(response.body));
      }
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(errorCode: 'FILTERS_ERROR', message: 'Erreur lors de la récupération des filtres: $e');
    }
  }

  // ============================================
  // ✅ AVIS (REVIEWS)
  // ============================================

  /// Soumet un avis d'un touriste sur un guide.
  ///
  /// [reviewData] doit contenir :
  /// ```json
  /// { "guide_id": "abc", "rating": 5, "comment": "...", "route_id": null }
  /// ```
  /// Utilisez [ReviewCreateRequest.toJson()] pour construire ce map.
  ///
  /// Retourne le [Review] créé, enrichi avec le nom du touriste.
  ///
  /// Erreurs possibles :
  /// - 403 FORBIDDEN_ROLE         : l'utilisateur n'est pas un touriste
  /// - 404 GUIDE_NOT_FOUND        : guide inexistant ou non approuvé
  /// - 400 SELF_REVIEW            : un guide essaie de se noter lui-même
  /// - 409 REVIEW_ALREADY_EXISTS  : avis déjà posté pour ce guide
  /// - 404 ROUTE_NOT_FOUND        : route_id invalide
  static Future<Review> submitReview(Map<String, dynamic> reviewData) async {
    try {
      final response = await _authenticatedPost(_reviewsBase, reviewData);

      if (response.statusCode == 201) {
        return Review.fromJson(jsonDecode(response.body));
      }

      // Retransmettre l'erreur métier du backend telle quelle
      final body = jsonDecode(response.body);
      throw ApiError(
        errorCode: body['error_code'] ?? 'REVIEW_ERROR',
        message:   body['message']   ?? 'Erreur lors de la soumission de l\'avis',
      );
    } on ApiError {
      rethrow;
    } on http.ClientException {
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message:   'Impossible de se connecter au serveur.',
      );
    } catch (e) {
      throw ApiError(
        errorCode: 'UNEXPECTED_ERROR',
        message:   'Erreur inattendue: ${e.toString()}',
      );
    }
  }

  /// Récupère la liste paginée des avis d'un guide.
  ///
  /// Endpoint public — aucun token requis.
  ///
  /// Retourne un [ReviewListResponse] contenant :
  /// - `averageRating` : note moyenne arrondie à 1 décimale (ex : 4.7)
  /// - `totalReviews`  : nombre total d'avis
  /// - `reviews`       : liste paginée, du plus récent au plus ancien
  ///
  /// Usage :
  /// ```dart
  /// final result = await ApiService.fetchGuideReviews(guideId, limit: 10);
  /// print(result.summaryDisplay); // "4.7 ★ (34 avis)"
  /// ```
  static Future<ReviewListResponse> fetchGuideReviews(
    String guideId, {
    int limit  = 20,
    int offset = 0,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl${_guideReviewsEndpoint(guideId)}')
          .replace(queryParameters: {
            'limit':  '$limit',
            'offset': '$offset',
          });

      final response = await http
          .get(uri, headers: _publicHeaders())
          .timeout(timeout);

      if (response.statusCode == 200) {
        return ReviewListResponse.fromJson(jsonDecode(response.body));
      }
      if (response.statusCode == 404) {
        throw ApiError(errorCode: 'GUIDE_NOT_FOUND', message: 'Guide introuvable');
      }
      throw ApiError.fromJson(jsonDecode(response.body));
    } on ApiError {
      rethrow;
    } on http.ClientException {
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message:   'Impossible de se connecter au serveur.',
      );
    } catch (e) {
      throw ApiError(
        errorCode: 'FETCH_REVIEWS_ERROR',
        message:   'Erreur inattendue: ${e.toString()}',
      );
    }
  }

  /// Supprime l'avis [reviewId] (auteur uniquement, ou admin).
  ///
  /// Recalcule automatiquement les stats du guide côté backend.
  static Future<SuccessResponse> deleteReview(String reviewId) async {
    try {
      final response = await _authenticatedDelete('$_reviewsBase/$reviewId');
      if (response.statusCode == 200) return SuccessResponse.fromJson(jsonDecode(response.body));
      throw ApiError.fromJson(jsonDecode(response.body));
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(errorCode: 'DELETE_REVIEW_ERROR', message: e.toString());
    }
  }
   /// Récupère tous les trajets actifs avec les informations du guide
  ///
  /// Endpoint public — filtrage optionnel par ville.
  /// Retourne une liste de Map<String, dynamic> (JSON brut) pour RouteWithGuideInfo.fromJson
  static Future<List<dynamic>> fetchAllRoutes({
    String? city,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final params = <String, String>{
        'limit':  '$limit',
        'offset': '$offset',
      };
      if (city != null && city.isNotEmpty) {
        params['city'] = city;
      }

      final uri = Uri.parse('$baseUrl/api/v1/routes/all')
          .replace(queryParameters: params);

      final response = await http
          .get(uri, headers: _publicHeaders())
          .timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data;
      }
      if (response.statusCode == 404) {
        return []; // Aucun trajet disponible
      }
      throw ApiError.fromJson(jsonDecode(response.body));
    } on ApiError {
      rethrow;
    } on http.ClientException {
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message:   'Impossible de se connecter au serveur.',
      );
    } catch (e) {
      throw ApiError(
        errorCode: 'FETCH_ROUTES_ERROR',
        message:   'Erreur inattendue: ${e.toString()}',
      );
    }
  }
  // ============================================
  // 👑 GESTION PREMIUM (NOUVEAU)
  // ============================================

  /// Active l'abonnement Premium pour le guide connecté
  /// 
  /// Retourne un [SuccessResponse] contenant le message de succès du backend.
  static Future<SuccessResponse> upgradeToPremium() async {
    try {
      print('📤 Requête upgrade Premium → $premiumEndpoint');

      final response = await http.post(
        Uri.parse('$baseUrl$premiumEndpoint'),
        headers: await _getAuthHeaders(),
      ).timeout(timeout);

      print('📥 Réponse Premium: ${response.statusCode}');
      print('📜 Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return SuccessResponse.fromJson(data);
      }

      // Gestion détaillée des erreurs métier du backend
      final Map<String, dynamic> errorData = jsonDecode(response.body);
      throw ApiError(
        errorCode: errorData['error_code'] ?? 'PREMIUM_ERROR',
        message:   errorData['message']    ?? 'Erreur lors de l\'activation Premium',
      );

    } on http.ClientException {
      throw ApiError(
        errorCode: 'NETWORK_ERROR',
        message:   'Impossible de contacter le serveur pour l\'activation Premium.',
      );
    } on ApiError {
      rethrow;
    } catch (e) {
      throw ApiError(
        errorCode: 'PREMIUM_ERROR',
        message:   'Erreur inattendue : ${e.toString()}',
      );
    }
  }

  }

