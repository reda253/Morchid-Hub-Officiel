import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/osm_service.dart';

/// Écran de carte interactif avec routing et tracking GPS
/// Intégré au design system Morchid Hub
/// 
/// Mode 'edit': Permet de créer et modifier un trajet
/// Mode 'view': Affiche un trajet existant en lecture seule
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

  // Couleurs du design system Morchid Hub
  static const Color primaryColor = Color(0xFF2D6A4F);
  static const Color secondaryColor = Color(0xFF1B4332);
  static const Color backgroundColor = Color(0xFFF8F9FA);
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

      // Convertir les coordonnées en LatLng
      final routePoints = coordinates.map((coord) {
        return LatLng(
          (coord['lat'] as num).toDouble(),
          (coord['lng'] as num).toDouble(),
        );
      }).toList();

      setState(() {
        _routePoints = routePoints;
        _startPoint = routePoints.first;
        _endPoint = routePoints.last;
        _distance = distance;
        _duration = duration;
        _startAddress = startAddress;
        _endAddress = endAddress;

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
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.mode == 'view' ? 'Visualiser le trajet' : 'Créer un trajet',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Bouton de réinitialisation (seulement en mode 'edit')
          if (widget.mode == 'edit')
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetMap,
              tooltip: 'Réinitialiser',
            ),
        ],
      ),
      body: Stack(
        children: [
          // ============================================
          // CARTE OPENSTREETMAP
          // ============================================
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(33.5731, -7.5898),
              initialZoom: 12.0,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Tuiles OpenStreetMap
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.morchidhub.app',
              ),
              
              // Ligne du trajet
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: primaryColor,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              
              // Marqueurs (départ/arrivée)
              if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
              
              // Position actuelle trackée (cercle bleu)
              if (_trackedPosition != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _trackedPosition!,
                      color: Colors.blue.withOpacity(0.3),
                      borderColor: Colors.blue,
                      borderStrokeWidth: 3,
                      radius: 15,
                    ),
                  ],
                ),
            ],
          ),
          
          // ============================================
          // LOADER PENDANT CALCUL
          // ============================================
          if (_isLoadingRoute)
            Container(
              color: Colors.black26,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Calcul du trajet...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // ============================================
          // PANNEAU D'INFORMATION
          // ============================================
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Texte d'instruction
                    _buildInstructionText(),
                    
                    // Adresses (si disponibles)
                    if (_startAddress != null || _endAddress != null) ...[
                      const SizedBox(height: 12),
                      _buildAddressInfo(),
                    ],
                    
                    // Boutons d'action
                    if (_endPoint != null) ...[
                      const SizedBox(height: 12),
                      _buildActionButtons(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // WIDGETS AUXILIAIRES
  // ============================================
  
  Widget _buildInstructionText() {
    String text;
    IconData icon;
    
    if (widget.mode == 'view') {
      // Mode visualisation
      text = '${OSMService.formatDistance(_distance * 1000)} - ${OSMService.formatDuration(_duration)}';
      icon = Icons.visibility;
    } else if (_startPoint == null) {
      text = 'Touche la carte pour définir le point de départ';
      icon = Icons.location_on_outlined;
    } else if (_endPoint == null) {
      text = 'Touche la carte pour définir la destination';
      icon = Icons.flag_outlined;
    } else {
      text = '${OSMService.formatDistance(_distance * 1000)} - ${OSMService.formatDuration(_duration)}';
      icon = Icons.check_circle;
    }
    
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_startAddress != null) ...[
            const Row(
              children: [
                Icon(Icons.play_arrow, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text('Départ:', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _startAddress!,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (_startAddress != null && _endAddress != null)
            const SizedBox(height: 8),
          if (_endAddress != null) ...[
            Row(
              children: [
                Icon(Icons.flag, size: 16, color: errorColor),
                const SizedBox(width: 8),
                const Text('Arrivée:', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _endAddress!,
              style: const TextStyle(fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Mode visualisation : boutons de tracking uniquement
    if (widget.mode == 'view') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isTracking ? _stopTracking : _startTracking,
              icon: Icon(_isTracking ? Icons.pause : Icons.navigation),
              label: Text(_isTracking ? 'Arrêter' : 'Démarrer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isTracking ? warningColor : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Mode édition : boutons de sauvegarde + tracking
    return Column(
      children: [
        // Bouton Enregistrer le trajet
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _saveRoute,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer le trajet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: successColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Boutons Tracking + Nouveau
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isTracking ? _stopTracking : _startTracking,
                icon: Icon(_isTracking ? Icons.pause : Icons.navigation),
                label: Text(_isTracking ? 'Arrêter' : 'Démarrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? warningColor : primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
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
                  side: BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================
// ENUMS
// ============================================

enum MarkerType { start, end }