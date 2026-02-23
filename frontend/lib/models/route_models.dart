import 'dart:convert';

// ════════════════════════════════════════════════════════════════════════════
// MODÈLES POUR LES TRAJETS (ROUTES)
// ════════════════════════════════════════════════════════════════════════════

/// Un checkpoint (point d'intérêt) sur un trajet
class Checkpoint {
  final String id;
  final String name;
  final String description;
  final double lat;
  final double lng;
  final String type; // "Monument", "Repos", "Photo", "Panorama"
  final int estimatedTime;
  final String? imageUrl;

  Checkpoint({
    required this.id,
    required this.name,
    required this.description,
    required this.lat,
    required this.lng,
    required this.type,
    required this.estimatedTime,
    this.imageUrl,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) => Checkpoint(
        id:            json['id'] ?? '',
        name:          json['name'] ?? '',
        description:   json['description'] ?? '',
        lat:           (json['lat'] as num).toDouble(),
        lng:           (json['lng'] as num).toDouble(),
        type:          json['type'] ?? 'Monument',
        estimatedTime: json['estimated_time'] ?? 0,
        imageUrl:      json['image_url'],
      );

  Map<String, dynamic> toJson() => {
        'id':             id,
        'name':           name,
        'description':    description,
        'lat':            lat,
        'lng':            lng,
        'type':           type,
        'estimated_time': estimatedTime,
        'image_url':      imageUrl,
      };
}

/// Réponse complète d'un trajet (incluant les checkpoints)
class GuideRoute {
  final String id;
  final String guideId;
  final List<Map<String, double>> coordinates;
  final double distance;
  final double duration;
  final String? startAddress;
  final String? endAddress;
  final String? description;
  final List<Checkpoint> checkpoints;
  final double? price; // ✅ Ajoute cette ligne
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  GuideRoute({
    required this.id,
    required this.guideId,
    required this.coordinates,
    required this.distance,
    required this.duration,
    this.startAddress,
    this.endAddress,
    this.description,
    this.checkpoints = const [],
    this.price, // ✅ Ajoute au constructeur
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory GuideRoute.fromJson(Map<String, dynamic> json) {
    return GuideRoute(
      id:           json['id'],
      guideId:      json['guide_id'],
      coordinates:  (json['coordinates'] as List<dynamic>)
          .map((c) => {
                'lat': (c['lat'] as num).toDouble(),
                'lng': (c['lng'] as num).toDouble(),
              })
          .toList(),
      distance:     (json['distance'] as num).toDouble(),
      duration:     (json['duration'] as num).toDouble(),
      startAddress: json['start_address'],
      endAddress:   json['end_address'],
      description:  json['description'],
      checkpoints: (json['checkpoints'] as List<dynamic>? ?? [])
          .map((cp) => Checkpoint.fromJson(cp as Map<String, dynamic>))
          .toList(),
      price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
      isActive:  json['is_active'] ?? true,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id':            id,
        'guide_id':      guideId,
        'coordinates':   coordinates,
        'distance':      distance,
        'duration':      duration,
        'start_address': startAddress,
        'end_address':   endAddress,
        'description':   description,
        'checkpoints':   checkpoints.map((cp) => cp.toJson()).toList(),
        'is_active':     isActive,
        'created_at':    createdAt?.toIso8601String(),
        'updated_at':    updatedAt?.toIso8601String(),
      };
  String get priceDisplay {
    if (price == null || price == 0) return 'Gratuit';
    return '${price!.toStringAsFixed(0)} DH';
  }
}

/// Résultat de recherche enrichi avec info du guide
class RouteWithGuideInfo {
  final GuideRoute route;
  final String guideName;
  final String? guidePhotoUrl;
  final double guideRating;
  final int guideTotalReviews;

  RouteWithGuideInfo({
    required this.route,
    required this.guideName,
    this.guidePhotoUrl,
    required this.guideRating,
    required this.guideTotalReviews,
  });

  factory RouteWithGuideInfo.fromJson(Map<String, dynamic> json) {
    return RouteWithGuideInfo(
      route:             GuideRoute.fromJson(json['route']),
      guideName:         json['guide_name'] ?? 'Guide anonyme',
      guidePhotoUrl:     json['guide_photo_url'],
      guideRating:       (json['guide_rating'] as num?)?.toDouble() ?? 0.0,
      guideTotalReviews: json['guide_total_reviews'] ?? 0,
    );
  }
  

  /// "4.7 ★" ou "Nouveau guide"
  String get ratingDisplay =>
      guideTotalReviews == 0 ? 'Nouveau guide' : '${guideRating.toStringAsFixed(1)} ★';

  /// "4.7 ★ (34 avis)" ou "Aucun avis"
  String get ratingWithCount {
    if (guideTotalReviews == 0) return 'Aucun avis';
    return '${guideRating.toStringAsFixed(1)} ★ ($guideTotalReviews avis)';
  }
  
}