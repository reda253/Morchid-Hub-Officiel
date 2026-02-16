import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../services/osm_service.dart';

/// Écran de carte interactif avec routing et tracking GPS
/// Intégré au design system Morchid Hub
/// 
/// Mode 'edit': Permet de créer et modifier un trajet
/// Mode 'view': Affiche un trajet existant en lecture seule
/// modele checkpoint

enum CheckpointType { Monument, Repos, Photo, Panorama}
extension CheckpointTypeX on CheckpointType{
  
    String get label {
    switch (this) {
      case CheckpointType.Monument: return 'Monument';
      case CheckpointType.Repos:    return 'Repos';
      case CheckpointType.Photo:    return 'Photo';
      case CheckpointType.Panorama: return 'Panorama';
    }
  }
    IconData get icon {
    switch (this) {
      case CheckpointType.Monument: return Icons.account_balance;
      case CheckpointType.Repos:    return Icons.coffee;
      case CheckpointType.Photo:    return Icons.camera_alt;
      case CheckpointType.Panorama: return Icons.landscape;
    }
  }

  Color get color {
    switch (this) {
      case CheckpointType.Monument: return const Color(0xFF8B4513);
      case CheckpointType.Repos:    return const Color(0xFF1976D2);
      case CheckpointType.Photo:    return const Color(0xFFE91E63);
      case CheckpointType.Panorama: return const Color(0xFF388E3C);
    }
  }
}

class Checkpoint {
  final String id;
  final String name;
  final String description;
  final LatLng position;
  final CheckpointType type;
  final int estimatedTime;
  final String? imageUrl;

  Checkpoint({
    required this.id,
    required this.name,
    required this.description,
    required this.position,
    required this.type,
    required this.estimatedTime,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'id':             id,
    'name':           name,
    'description':    description,
    'lat':            position.latitude,
    'lng':            position.longitude,
    'type':           type.label,
    'estimated_time': estimatedTime,
    'image_url':      imageUrl,
  };

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] as String?) ?? 'Monument';
    final cpType = CheckpointType.values.firstWhere(
      (t) => t.label == typeStr,
      orElse: () => CheckpointType.Monument,
    );
    return Checkpoint(
      id:            json['id'] ?? '',
      name:          json['name'] ?? '',
      description:   json['description'] ?? '',
      position:      LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      type:          cpType,
      estimatedTime: json['estimated_time'] ?? 0,
      imageUrl:      json['image_url'],
    );
  }
}

class MapScreen extends StatefulWidget {
  final String mode; // 'edit' ou 'view'
  final Map<String, dynamic>? savedRoute; // Trajet sauvegardé à afficher en mode 'view'
  
  const MapScreen({
    Key? key,
    this.mode = 'edit',
    this.savedRoute,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ============================================
  // VARIABLES D'ÉTAT
  // ============================================
  
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  bool _isTracking = false;
  bool _isLoadingRoute = false;
  double _distance = 0;
  double _duration = 0;
  List<Marker> _markers = [];
  LatLng? _trackedPosition;
  String? _startAddress;
  String? _endAddress;
  // ── Description globale du trajet ─────────────────────────────────────────
  String? _routeDescription;
  final TextEditingController _descController = TextEditingController();

  // ── Checkpoints ───────────────────────────────────────────────────────────
  final List<Checkpoint> _checkpoints = [];
  int? _highlightedCheckpointIndex;  // Index du checkpoint surligné sur la carte

  // ── Vue touriste : timeline dépliée ──────────────────────────────────────
  bool _showTimeline = true;
  // Couleurs du design system Morchid Hub
  static const Color primaryColor = Color(0xFF2D6A4F);
  static const Color secondaryColor = Color(0xFF1B4332);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color textDark        = Color(0xFF2B2D42);
  static const Color textLight       = Color(0xFF8D99AE);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color errorColor = Color(0xFFE63946);
  static const Color successColor = Color(0xFF52B788);

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    
    // Si mode 'view' et trajet existant, charger le trajet
    if (widget.mode == 'view' && widget.savedRoute != null) {
      _loadSavedRoute();
    }
  }
  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // ============================================
  // INITIALISATION
  // ============================================
  
  Future<void> _initializeLocation() async {
    try {
      final position = await OSMService.getCurrentLocation();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _trackedPosition = _currentPosition;
      });
      
      _mapController.move(_currentPosition!, 14.0);
      _showSnackbar('📍 Position obtenue', isSuccess: true);
    } catch (e) {
      _showError('Erreur localisation: ${e.toString()}');
      // Position par défaut : Casablanca
      setState(() {
        _currentPosition = const LatLng(33.5731, -7.5898);
      });
      _mapController.move(_currentPosition!, 12.0);
    }
  }

  /// Charge un trajet sauvegardé en mode visualisation
  Future<void> _loadSavedRoute() async {
    if (widget.savedRoute == null) return;

    try {
      // Extraire les données du trajet sauvegardé
      final coordinates = widget.savedRoute!['coordinates'] as List;
      final distance = widget.savedRoute!['distance'] as double;
      final duration = widget.savedRoute!['duration'] as double;
      final startAddress = widget.savedRoute!['start_address'] as String?;
      final endAddress = widget.savedRoute!['end_address'] as String?;
      final description  = widget.savedRoute!['description'] as String?;
      final rawCps       = widget.savedRoute!['checkpoints'] as List?;

      // Convertir les coordonnées en LatLng
      final routePoints = coordinates.map((coord) {
        return LatLng(
          (coord['lat'] as num).toDouble(),
          (coord['lng'] as num).toDouble(),
        );
      }).toList();
       final checkpoints = (rawCps ?? [])
          .map((cp) => Checkpoint.fromJson(cp as Map<String, dynamic>))
          .toList();

      setState(() {
        _routePoints = routePoints;
        _startPoint = routePoints.first;
        _endPoint = routePoints.last;
        _distance = distance;
        _duration = duration;
        _startAddress = startAddress;
        _endAddress = endAddress;
        _routeDescription  = description;
        _checkpoints
          ..clear()
          ..addAll(checkpoints);
        _addMarker(_startPoint!, MarkerType.start);
        _addMarker(_endPoint!,   MarkerType.end);

        // Ajouter les marqueurs
        _addMarker(_startPoint!, MarkerType.start);
        _addMarker(_endPoint!, MarkerType.end);
      });

      // Zoomer sur le trajet
      if (_routePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(80),
          ),
        );
      }

      _showSnackbar('✅ Trajet chargé', isSuccess: true);
    } catch (e) {
      _showError('Erreur lors du chargement: ${e.toString()}');
    }
  }

  // ============================================
  // GESTION DES INTERACTIONS CARTE
  // ============================================
  
  void _onMapTap(TapPosition tapPosition, LatLng position) async {
    // Désactiver les interactions en mode 'view'
    if (widget.mode == 'view') return;
    
    if (_isLoadingRoute) return; // Empêcher les taps pendant le calcul

    setState(() {
      if (_startPoint == null) {
        _startPoint = position;
        _addMarker(position, MarkerType.start);
        _showSnackbar('📍 Point de départ défini', isSuccess: true);
        _getAddressForPoint(position, isStart: true);
      } else if (_endPoint == null) {
        _endPoint = position;
        _addMarker(position, MarkerType.end);
        _showSnackbar('🎯 Destination définie', isSuccess: true);
        _getAddressForPoint(position, isStart: false);
        _calculateRoute();
      } else {
        // Reset et nouveau départ
        _resetMap();
        _startPoint = position;
        _addMarker(position, MarkerType.start);
        _showSnackbar('🔄 Nouveau point de départ', isSuccess: true);
        _getAddressForPoint(position, isStart: true);
      }
    });
  }
  // ✅ Long Press → ajouter un checkpoint (mode edit uniquement)
  void _onMapLongPress(TapPosition tapPosition, LatLng position) {
    if (widget.mode != 'edit') return;
    if (_routePoints.isEmpty) {
      _showSnackbar('Créez d\'abord un trajet avant d\'ajouter des checkpoints', isSuccess: false);
      return;
    }
    _showAddCheckpointDialog(position);
  }

  /// Récupère l'adresse d'un point
  Future<void> _getAddressForPoint(LatLng point, {required bool isStart}) async {
    try {
      final address = await OSMService.getAddressFromCoordinates(point);
      setState(() {
        if (isStart) {
          _startAddress = address;
        } else {
          _endAddress = address;
        }
      });
    } catch (e) {
      // Ignore silencieusement les erreurs de géocodage
    }
  }

  // ============================================
  // GESTION DES MARQUEURS
  // ============================================
  
  void _addMarker(LatLng position, MarkerType type) {
    _markers.add(
      Marker(
        point: position,
        width: 50,
        height: 50,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: type == MarkerType.start ? Colors.green : errorColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                type == MarkerType.start ? Icons.play_arrow : Icons.flag,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ✅ Construire les markers de checkpoints dynamiquement
  List<Marker> _buildCheckpointMarkers() {
    return List.generate(_checkpoints.length, (i) {
      final cp         = _checkpoints[i];
      final isHighlighted = _highlightedCheckpointIndex == i;
      return Marker(
        point:  cp.position,
        width:  isHighlighted ? 60 : 48,
        height: isHighlighted ? 60 : 48,
        child: GestureDetector(
          onTap: () {
            setState(() => _highlightedCheckpointIndex = i);
            _mapController.move(cp.position, 16.0);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: cp.type.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isHighlighted ? Colors.white : Colors.transparent,
                width: isHighlighted ? 3 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: cp.type.color.withOpacity(0.5),
                  blurRadius: isHighlighted ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(cp.type.icon, color: Colors.white, size: isHighlighted ? 30 : 22),
          ),
        ),
      );
    });
  }

  // ============================================
  // CALCUL DU TRAJET
  // ============================================
  
  Future<void> _calculateRoute() async {
    if (_startPoint == null || _endPoint == null) return;

    setState(() => _isLoadingRoute = true);

    try {
      _showSnackbar('🔄 Calcul du trajet...', isSuccess: true);
      
      final result = await OSMService.getRoute(
        start: _startPoint!,
        end: _endPoint!,
      );

      setState(() {
        _routePoints = result['coordinates'];
        _distance = result['distance'];
        _duration = result['duration'];
        _isLoadingRoute = false;
      });

      // Zoom sur le trajet complet
      if (_routePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(80),
          ),
        );
      }

      _showSnackbar(
        '✅ ${OSMService.formatDistance(_distance * 1000)} - ${OSMService.formatDuration(_duration)}',
        isSuccess: true,
      );
    } catch (e) {
      setState(() => _isLoadingRoute = false);
      _showError('Impossible de calculer le trajet: ${e.toString()}');
    }
  }
  // ════════════════════════════════════════════════════════════════════════════
  // CHECKPOINT — DIALOG D'AJOUT
  // ════════════════════════════════════════════════════════════════════════════

  void _showAddCheckpointDialog(LatLng position) {
    final nameCtrl  = TextEditingController();
    final descCtrl  = TextEditingController();
    final timeCtrl  = TextEditingController(text: '15');
    final imageCtrl = TextEditingController();
    CheckpointType selectedType = CheckpointType.Monument;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Titre ───────────────────────────────────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_location_alt, color: primaryColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Ajouter un point d\'intérêt',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Nom ─────────────────────────────────────────────────
                _dialogField(nameCtrl, 'Nom du lieu *', Icons.label_outline),
                const SizedBox(height: 12),

                // ── Description ─────────────────────────────────────────
                _dialogField(descCtrl, 'Description *', Icons.notes, maxLines: 3),
                const SizedBox(height: 12),

                // ── Type (dropdown) ──────────────────────────────────────
                DropdownButtonFormField<CheckpointType>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    prefixIcon: Icon(selectedType.icon, color: selectedType.color),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 1.5),
                    ),
                  ),
                  items: CheckpointType.values.map((t) => DropdownMenuItem(
                    value: t,
                    child: Row(children: [
                      Icon(t.icon, color: t.color, size: 18),
                      const SizedBox(width: 8),
                      Text(t.label),
                    ]),
                  )).toList(),
                  onChanged: (v) {
                    if (v != null) setStateDlg(() => selectedType = v);
                  },
                ),
                const SizedBox(height: 12),

                // ── Temps estimé ─────────────────────────────────────────
                _dialogField(
                  timeCtrl, 'Temps d\'arrêt (minutes)', Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // ── URL image ────────────────────────────────────────────
                _dialogField(imageCtrl, 'URL de la photo (facultatif)', Icons.image_outlined),
                const SizedBox(height: 24),

                // ── Boutons ──────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Annuler', style: TextStyle(color: primaryColor)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Nom et description requis')),
                          );
                          return;
                        }
                        final cp = Checkpoint(
                          id:            DateTime.now().millisecondsSinceEpoch.toString(),
                          name:          nameCtrl.text.trim(),
                          description:   descCtrl.text.trim(),
                          position:      position,
                          type:          selectedType,
                          estimatedTime: int.tryParse(timeCtrl.text) ?? 15,
                          imageUrl:      imageCtrl.text.trim().isEmpty ? null : imageCtrl.text.trim(),
                        );
                        setState(() => _checkpoints.add(cp));
                        Navigator.pop(ctx);
                        _showSnackbar('✅ Checkpoint "${cp.name}" ajouté', isSuccess: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller:   ctrl,
      maxLines:     maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        border:       OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
      ),
    );
  }

  // ── Dialog description globale du trajet ─────────────────────────────────
  void _showDescriptionDialog() {
    _descController.text = _routeDescription ?? '';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.article_outlined, color: primaryColor),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Histoire du trajet',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textDark)),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Racontez l\'histoire de votre itinéraire, les lieux traversés, les anecdotes…',
                hintStyle: TextStyle(color: textLight.withOpacity(0.7)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Annuler', style: TextStyle(color: primaryColor)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _routeDescription = _descController.text.trim().isEmpty
                        ? null : _descController.text.trim());
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Sauvegarder', style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }


  // ============================================
  // SAUVEGARDE DU TRAJET (NOUVEAU)
  // ============================================
  
  Future<void> _saveRoute() async {
    if (_routePoints.isEmpty || _startPoint == null || _endPoint == null) {
      _showError('Veuillez créer un trajet avant de sauvegarder');
      return;
    }

    try {
      // Préparer les données à renvoyer au HomeScreen
      final routeData = {
        'coordinates': _routePoints.map((point) => {
          'lat': point.latitude,
          'lng': point.longitude,
        }).toList(),
        'start_point': {
          'lat': _startPoint!.latitude,
          'lng': _startPoint!.longitude,
        },
        'end_point': {
          'lat': _endPoint!.latitude,
          'lng': _endPoint!.longitude,
        },
        'distance': _distance,
        'duration': _duration,
        'start_address': _startAddress,
        'end_address': _endAddress,
        // ✅ NOUVEAU
        'description': _routeDescription,
        'checkpoints': _checkpoints.map((cp) => cp.toJson()).toList(),
      };

      _showSnackbar('✅ Trajet prêt à être enregistré', isSuccess: true);
      
      // Retourner les données au HomeScreen
      Navigator.pop(context, routeData);
    } catch (e) {
      _showError('Erreur lors de la préparation: ${e.toString()}');
    }
  }

  // ============================================
  // TRACKING GPS
  // ============================================
  
  void _startTracking() {
    setState(() => _isTracking = true);
    
    OSMService.trackLocation().listen(
      (position) {
        if (!mounted) return;
        
        setState(() {
          _trackedPosition = LatLng(position.latitude, position.longitude);
        });
        
        // Centrer la carte sur la position actuelle
        _mapController.move(_trackedPosition!, _mapController.camera.zoom);
        
        // Vérifier si proche de la destination
        if (_endPoint != null) {
          final isNear = OSMService.isNearPoint(
            _trackedPosition!,
            _endPoint!,
            radiusInMeters: 50,
          );
          
          if (isNear && _isTracking) {
            _showSnackbar('🎉 Vous êtes arrivé !', isSuccess: true);
            _stopTracking();
          }
        }
      },
      onError: (error) {
        _showError('Erreur tracking: $error');
        _stopTracking();
      },
    );
    
    _showSnackbar('🧭 Tracking GPS activé', isSuccess: true);
  }

  void _stopTracking() {
    setState(() => _isTracking = false);
    _showSnackbar('⏸️ Tracking désactivé', isSuccess: true);
  }

  // ============================================
  // RESET
  // ============================================
  
  void _resetMap() {
    setState(() {
      _startPoint = null;
      _endPoint = null;
      _routePoints = [];
      _markers = [];
      _distance = 0;
      _duration = 0;
      _startAddress = null;
      _endAddress = null;
      _isTracking = false;
      _checkpoints.clear();
      _routeDescription = null;
      _highlightedCheckpointIndex = null;
    });
    _showSnackbar('🔄 Carte réinitialisée', isSuccess: true);
  }

  // ============================================
  // SNACKBAR HELPERS
  // ============================================
  
  void _showSnackbar(String message, {bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? successColor : Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.only(bottom: 100, left: 16, right: 16),
      ),
    );
  }

  // ============================================
  // BUILD UI
  // ============================================
  
 @override
  Widget build(BuildContext context) {
    final isView = widget.mode == 'view';
    final hasCheckpoints = _checkpoints.isNotEmpty;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          isView ? 'Itinéraire touristique' : 'Créer un trajet',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!isView) ...[
            IconButton(
              icon: Icon(Icons.article_outlined, color: _routeDescription != null ? Colors.amber : Colors.white),
              onPressed: _showDescriptionDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetMap,
            ),
          ],
          if (isView && hasCheckpoints)
            IconButton(
              icon: Icon(_showTimeline ? Icons.map : Icons.list_alt),
              onPressed: () => setState(() => _showTimeline = !_showTimeline),
            ),
        ],
      ),
      // Choix du corps de la page selon le mode
      body: isView ? _buildViewBody(hasCheckpoints) : _buildEditBody(),
    );
  }

  // ── MODE ÉDITION (GUIDE) ──────────────────────────────────────────
  Widget _buildEditBody() {
    return Stack(children: [
      _buildMap(),
      if (_isLoadingRoute) _buildLoader(),
      // Petit indicateur pour l'ajout de points
      if (_routePoints.isNotEmpty)
        Positioned(
          top: 12, left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.touch_app, color: Colors.white, size: 13),
              SizedBox(width: 4),
              Text('Appui long → ajouter un checkpoint', style: TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ),
        ),
      Positioned(bottom: 20, left: 20, right: 20, child: _buildInfoPanel()),
    ]);
  }

  // ── MODE VUE (TOURISTE) AVEC TIMELINE ──────────────────────────────
  Widget _buildViewBody(bool hasCheckpoints) {
    // Si l'utilisateur veut la carte en plein écran
    if (!hasCheckpoints || !_showTimeline) {
      return Stack(children: [
        _buildMap(),
        Positioned(bottom: 20, left: 20, right: 20, child: _buildInfoPanel()),
      ]);
    }

    // Vue partagée : Carte (60%) + Timeline (40%)
    return Column(children: [
      Expanded(
        flex: 6,
        child: Stack(children: [
          _buildMap(),
          // Badge flottant du nombre de points
          Positioned(
            top: 12, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(20)),
              child: Text('${_checkpoints.length} points d\'intérêt', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ]),
      ),
      Expanded(
        flex: 4,
        child: _buildTimeline(),
      ),
    ]);
  }

  // ── LA TIMELINE (LISTE DES POINTS) ────────────────────────────────
  Widget _buildTimeline() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Points d\'intérêt du trajet', style: TextStyle(fontWeight: FontWeight.bold, color: textDark)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _checkpoints.length,
              itemBuilder: (context, index) {
                final cp = _checkpoints[index];
                final isSelected = _highlightedCheckpointIndex == index;
                
                return ListTile(
                  selected: isSelected,
                  selectedTileColor: primaryColor.withOpacity(0.05),
                  leading: CircleAvatar(
                    backgroundColor: cp.type.color,
                    child: Icon(cp.type.icon, color: Colors.white, size: 20),
                  ),
                  title: Text(cp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(cp.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text('${cp.estimatedTime} min', style: const TextStyle(fontSize: 12, color: textLight)),
                  onTap: () {
                    setState(() => _highlightedCheckpointIndex = index);
                    _mapController.move(cp.position, 16.0); // Centre la carte sur le point
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── LA CARTE (CONSERVE VOTRE URLTEMPLATE) ─────────────────────────
  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentPosition ?? const LatLng(33.5731, -7.5898),
        initialZoom: 12.0,
        onTap: _onMapTap,
        onLongPress: _onMapLongPress,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.morchidhub.app',
        ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(points: _routePoints, color: primaryColor, strokeWidth: 5.0),
          ]),
        // Marqueurs des checkpoints
        MarkerLayer(
          markers: _checkpoints.asMap().entries.map((entry) {
            int idx = entry.key;
            Checkpoint cp = entry.value;
            return Marker(
              point: cp.position,
              child: GestureDetector(
                onTap: () => setState(() => _highlightedCheckpointIndex = idx),
                child: Icon(cp.type.icon, color: cp.type.color, size: 30),
              ),
            );
          }).toList(),
        ),
        // Marqueurs Départ/Arrivée (vos marqueurs actuels)
        if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
      ],
    );
  }
  Widget _buildLoader() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: primaryColor),
                SizedBox(height: 16),
                Text('Calcul du trajet...'),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildInfoPanel() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildInstructionText(),
            if (_startAddress != null || _endAddress != null) ...[
              const SizedBox(height: 12),
              _buildAddressInfo(),
            ],
            if (_endPoint != null || widget.mode == 'view') ...[
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }
  Widget _buildInstructionText() {
    String text;
    IconData icon;
    
    if (widget.mode == 'view') {
      text = '${OSMService.formatDistance(_distance * 1000)} — ${OSMService.formatDuration(_duration)}';
      icon = Icons.visibility;
    } else if (_startPoint == null) {
      text = 'Touche la carte pour définir le point de départ';
      icon = Icons.location_on_outlined;
    } else if (_endPoint == null) {
      text = 'Touche la carte pour définir la destination';
      icon = Icons.flag_outlined;
    } else {
      text = '${OSMService.formatDistance(_distance * 1000)} — ${OSMService.formatDuration(_duration)}';
      icon = Icons.check_circle;
    }

    return Row(children: [
      Icon(icon, color: primaryColor),
      const SizedBox(width: 12),
      Expanded(
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    ]);
  }
  Widget _buildAddressInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_startAddress != null) ...[
          const Row(children: [
            Icon(Icons.play_arrow, size: 16, color: Colors.green),
            SizedBox(width: 8),
            Text('Départ:', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(_startAddress!, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (_startAddress != null && _endAddress != null) const SizedBox(height: 8),
        if (_endAddress != null) ...[
          const Row(children: [
            Icon(Icons.flag, size: 16, color: errorColor),
            SizedBox(width: 8),
            Text('Arrivée:', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text(_endAddress!, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
  Widget _buildActionButtons() {
    if (widget.mode == 'view') {
      return Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.pause : Icons.navigation),
            label: Text(_isTracking ? 'Arrêter' : 'Démarrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? warningColor : primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]);
    }

    return Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saveRoute,
          icon: const Icon(Icons.save),
          label: Text(_checkpoints.isEmpty
              ? 'Enregistrer le trajet'
              : 'Enregistrer (${_checkpoints.length} points)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: successColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isTracking ? _stopTracking : _startTracking,
            icon: Icon(_isTracking ? Icons.pause : Icons.navigation),
            label: Text(_isTracking ? 'Arrêter' : 'Démarrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? warningColor : primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _resetMap,
            icon: const Icon(Icons.refresh),
            label: const Text('Nouveau'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: const BorderSide(color: primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ]),
    ]);
  }
}

// ============================================
// ENUMS
// ============================================

enum MarkerType { start, end }