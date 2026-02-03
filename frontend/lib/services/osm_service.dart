import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';

/// Service de cartographie et routing gratuit avec OpenStreetMap
/// Compatible avec l'architecture Morchid Hub
class OSMService {
  // ============================================
  // CONFIGURATION
  // ============================================
  
  /// Base URL OSRM (Open Source Routing Machine)
  /// Service 100% gratuit, pas de clé API nécessaire
  static const String _osrmUrl = 'https://router.project-osrm.org';
  
  /// Base URL Nominatim (Géocodage)
  /// Service gratuit d'OpenStreetMap
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';

  // ============================================
  // ROUTING (CALCUL DE TRAJET)
  // ============================================
  
  /// Calcule le trajet entre deux points
  /// 
  /// Returns:
  /// - coordinates: Liste des points du trajet
  /// - distance: Distance en kilomètres
  /// - duration: Durée en minutes
  static Future<Map<String, dynamic>> getRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    final url = '$_osrmUrl/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson&steps=true';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['code'] != 'Ok') {
          throw Exception('Aucun trajet trouvé entre ces points');
        }
        
        return {
          'coordinates': _decodeCoordinates(data),
          'distance': data['routes'][0]['distance'] / 1000, // en km
          'duration': data['routes'][0]['duration'] / 60, // en minutes
          'steps': _extractSteps(data), // Instructions de navigation
        };
      } else {
        throw Exception('Erreur routing: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Décode les coordonnées du trajet depuis la réponse OSRM
  static List<LatLng> _decodeCoordinates(Map<String, dynamic> data) {
    try {
      final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
      return coordinates
          .map((coord) => LatLng(coord[1] as double, coord[0] as double))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Extrait les étapes de navigation
  static List<String> _extractSteps(Map<String, dynamic> data) {
    try {
      final legs = data['routes'][0]['legs'] as List;
      final steps = legs[0]['steps'] as List;
      
      return steps.map((step) {
        final instruction = step['maneuver']['instruction'] ?? '';
        final distance = (step['distance'] / 1000).toStringAsFixed(1);
        return '$instruction ($distance km)';
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // GÉOLOCALISATION
  // ============================================
  
  /// Obtient la position GPS actuelle de l'utilisateur
  static Future<Position> getCurrentLocation() async {
    // Vérifier que le GPS est activé
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Les services de localisation sont désactivés. Veuillez les activer dans les paramètres.');
    }

    // Vérifier les permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission de localisation refusée définitivement. Veuillez l\'activer dans les paramètres.');
    }

    // Obtenir la position avec haute précision
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Stream de tracking GPS en temps réel
  /// Met à jour la position tous les 10 mètres
  static Stream<Position> trackLocation() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update tous les 10 mètres
        timeLimit: Duration(seconds: 5), // Timeout de 5 secondes
      ),
    );
  }

  /// Calcule la distance entre deux points en mètres
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  // ============================================
  // GÉOCODAGE (Adresse <-> Coordonnées)
  // ============================================
  
  /// Obtient l'adresse à partir de coordonnées GPS (Reverse Geocoding)
  static Future<String> getAddressFromCoordinates(LatLng position) async {
    final url = '$_nominatimUrl/reverse'
        '?lat=${position.latitude}&lon=${position.longitude}'
        '&format=json&zoom=18&addressdetails=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MorchidHub/1.0 (contact@morchidhub.ma)', // Requis par Nominatim
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Construire une adresse lisible
        final address = data['address'];
        final parts = <String>[];
        
        if (address['road'] != null) parts.add(address['road']);
        if (address['suburb'] != null) parts.add(address['suburb']);
        if (address['city'] != null) parts.add(address['city']);
        if (address['country'] != null) parts.add(address['country']);
        
        return parts.isNotEmpty ? parts.join(', ') : data['display_name'] ?? 'Adresse inconnue';
      }
      return 'Adresse non disponible';
    } catch (e) {
      return 'Erreur géocodage: $e';
    }
  }

  /// Recherche de coordonnées à partir d'une adresse (Geocoding)
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    final url = '$_nominatimUrl/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=5&addressdetails=1&countrycodes=ma'; // Limité au Maroc

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'MorchidHub/1.0 (contact@morchidhub.ma)',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> results = json.decode(response.body);
        
        return results.map((result) {
          return {
            'display_name': result['display_name'],
            'lat': double.parse(result['lat']),
            'lon': double.parse(result['lon']),
            'type': result['type'] ?? 'unknown',
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ============================================
  // UTILITAIRES
  // ============================================
  
  /// Formate une distance en texte lisible
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formate une durée en texte lisible
  static String formatDuration(double durationInMinutes) {
    if (durationInMinutes < 60) {
      return '${durationInMinutes.toStringAsFixed(0)} min';
    } else {
      final hours = (durationInMinutes / 60).floor();
      final minutes = (durationInMinutes % 60).toStringAsFixed(0);
      return '${hours}h ${minutes}min';
    }
  }

  /// Vérifie si l'utilisateur est proche d'un point (rayon de 50m par défaut)
  static bool isNearPoint(LatLng currentPos, LatLng targetPos, {double radiusInMeters = 50}) {
    final distance = calculateDistance(currentPos, targetPos);
    return distance <= radiusInMeters;
  }
}