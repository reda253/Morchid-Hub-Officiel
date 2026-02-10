import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/admin_models.dart';
import 'storage_service.dart';
import 'dart:io' as io;

class AdminService {
  // ============================================
  // CONFIGURATION
  // ============================================
  
  static String get baseUrl {
    if (io.Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  // Endpoints
  static const String adminUsersEndpoint = '/api/v1/admin/users';
  static const String adminPendingGuidesEndpoint = '/api/v1/admin/guides/pending';
  static const String adminSupportMessagesEndpoint = '/api/v1/admin/support/messages';
  
  static String approveGuideEndpoint(String id) => '/api/v1/admin/guides/$id/approve';
  static String rejectGuideEndpoint(String id) => '/api/v1/admin/guides/$id/reject';
  static String toggleUserStatusEndpoint(String id) => '/api/v1/admin/users/$id/toggle-status';
  static String resolveSupportEndpoint(String id) => '/api/v1/admin/support/messages/$id/resolve';

  // ============================================
  // HELPER POUR REQUÊTES AUTHENTIFIÉES
  // ============================================
  
  static Future<http.Response> _authenticatedRequest(
    String method, 
    String endpoint, 
    {Object? body}
  ) async {
    final token = await StorageService.getAccessToken();
    
    if (token == null) {
      throw ApiError(
        errorCode: 'NOT_AUTHENTICATED',
        message: 'Vous devez être connecté',
      );
    }
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    
    final uri = Uri.parse('$baseUrl$endpoint');
    
    switch (method) {
      case 'GET':
        return await http.get(uri, headers: headers);
      case 'PUT':
        return await http.put(
          uri, 
          headers: headers, 
          body: body != null ? jsonEncode(body) : null,
        );
      case 'DELETE':
        return await http.delete(uri, headers: headers);
      default:
        throw Exception('Méthode HTTP non supportée: $method');
    }
  }

  // ============================================
  // GESTION DES UTILISATEURS
  // ============================================
  
  /// Récupère la liste de tous les utilisateurs
  static Future<List<UserData>> fetchUsers({String? role}) async {
    try {
      String url = adminUsersEndpoint;
      if (role != null) url += '?role=$role';
      
      final response = await _authenticatedRequest('GET', url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserData.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'FETCH_USERS_ERROR',
        message: 'Erreur lors de la récupération des utilisateurs: $e',
      );
    }
  }

  /// Active ou désactive un utilisateur
  static Future<SuccessResponse> toggleUserStatus(String userId) async {
    try {
      final response = await _authenticatedRequest(
        'PUT', 
        toggleUserStatusEndpoint(userId),
      );
      
      if (response.statusCode == 200) {
        return SuccessResponse.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'TOGGLE_STATUS_ERROR',
        message: 'Erreur lors du changement de statut: $e',
      );
    }
  }

  // ============================================
  // GESTION DES GUIDES
  // ============================================
  
  /// Récupère la liste des guides en attente d'approbation
  static Future<List<GuideProfile>> fetchPendingGuides() async {
    try {
      final response = await _authenticatedRequest('GET', adminPendingGuidesEndpoint);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => GuideProfile.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'FETCH_GUIDES_ERROR',
        message: 'Erreur lors de la récupération des guides: $e',
      );
    }
  }

  /// Approuve un guide
  static Future<SuccessResponse> approveGuide(String guideId) async {
    try {
      final response = await _authenticatedRequest(
        'PUT', 
        approveGuideEndpoint(guideId),
      );
      
      if (response.statusCode == 200) {
        return SuccessResponse.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'APPROVE_GUIDE_ERROR',
        message: 'Erreur lors de l\'approbation: $e',
      );
    }
  }

  /// Rejette un guide avec un motif
  static Future<SuccessResponse> rejectGuide(
    String guideId, 
    String reason,
  ) async {
    try {
      final response = await _authenticatedRequest(
        'PUT', 
        rejectGuideEndpoint(guideId),
        body: {'reason': reason},
      );
      
      if (response.statusCode == 200) {
        return SuccessResponse.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'REJECT_GUIDE_ERROR',
        message: 'Erreur lors du rejet: $e',
      );
    }
  }

  // ============================================
  // GESTION DU SUPPORT TECHNIQUE
  // ============================================
  
  /// Récupère la liste des messages de support
  static Future<List<SupportMessage>> fetchSupportMessages({
    bool? resolved,
  }) async {
    try {
      String url = adminSupportMessagesEndpoint;
      if (resolved != null) {
        url += '?resolved=$resolved';
      }
      
      final response = await _authenticatedRequest('GET', url);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => SupportMessage.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'FETCH_SUPPORT_ERROR',
        message: 'Erreur lors de la récupération des messages: $e',
      );
    }
  }

  /// Marque un message de support comme résolu
  static Future<SuccessResponse> resolveSupportMessage(String messageId) async {
    try {
      final response = await _authenticatedRequest(
        'PUT', 
        resolveSupportEndpoint(messageId),
      );
      
      if (response.statusCode == 200) {
        return SuccessResponse.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw ApiError.fromJson(error);
      }
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError(
        errorCode: 'RESOLVE_SUPPORT_ERROR',
        message: 'Erreur lors de la résolution: $e',
      );
    }
  }

  // ============================================
  // HELPER POUR CONSTRUIRE LES URLs DES IMAGES
  // ============================================
  
  /// Construit l'URL complète pour une image
  static String getImageUrl(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) {
      return '';
    }
    
    // Si le chemin commence déjà par http, le retourner tel quel
    if (relativePath.startsWith('http')) {
      return relativePath;
    }
    
    // Sinon, construire l'URL complète
    // Enlever le slash initial si présent pour éviter les doubles slashes
    final path = relativePath.startsWith('/') 
        ? relativePath.substring(1) 
        : relativePath;
    
    return '$baseUrl/$path';
  }
}