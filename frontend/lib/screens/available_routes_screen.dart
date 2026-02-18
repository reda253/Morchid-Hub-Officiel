import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/route_models.dart';
import '../utils/app_colors.dart';
import 'map_screen.dart';

/// Écran d'exploration des trajets disponibles
/// Affiche tous les circuits touristiques avec recherche par ville
class AvailableRoutesScreen extends StatefulWidget {
  const AvailableRoutesScreen({Key? key}) : super(key: key);

  @override
  State<AvailableRoutesScreen> createState() => _AvailableRoutesScreenState();
}

class _AvailableRoutesScreenState extends State<AvailableRoutesScreen> {
  // ── État ──────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  List<RouteWithGuideInfo> _allRoutes = [];
  List<RouteWithGuideInfo> _filteredRoutes = [];
  String _errorMessage = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHARGEMENT DES DONNÉES
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final data = await ApiService.fetchAllRoutes(limit: 100);
      final routes = data.map((json) => RouteWithGuideInfo.fromJson(json)).toList();

      setState(() {
        _allRoutes = routes;
        _filteredRoutes = routes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Filtrage par recherche ───────────────────────────────────────────────
  void _filterRoutes(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredRoutes = _allRoutes;
      } else {
        _filteredRoutes = _allRoutes.where((r) {
          final startAddr = (r.route.startAddress ?? '').toLowerCase();
          final endAddr = (r.route.endAddress ?? '').toLowerCase();
          final guideName = r.guideName.toLowerCase();
          return startAddr.contains(_searchQuery) ||
              endAddr.contains(_searchQuery) ||
              guideName.contains(_searchQuery);
        }).toList();
      }
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UI
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Découvrir les circuits',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Barre de recherche ─────────────────────────────────────────
          _buildSearchBar(),

          // ── Contenu principal ──────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? _buildLoader()
                : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _filteredRoutes.isEmpty
                        ? _buildEmptyState()
                        : _buildRoutesList(),
          ),
        ],
      ),
    );
  }

  // ── Barre de recherche ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filterRoutes,
        decoration: InputDecoration(
          hintText: 'Rechercher par ville, quartier, guide...',
          hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.7)),
          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textLight),
                  onPressed: () {
                    _searchController.clear();
                    _filterRoutes('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Liste des trajets ─────────────────────────────────────────────────────
  Widget _buildRoutesList() {
    return RefreshIndicator(
      onRefresh: _loadRoutes,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRoutes.length,
        itemBuilder: (context, index) => _buildRouteCard(_filteredRoutes[index]),
      ),
    );
  }

  // ── Carte de trajet ───────────────────────────────────────────────────────
  Widget _buildRouteCard(RouteWithGuideInfo routeInfo) {
    final route = routeInfo.route;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _openRouteOnMap(routeInfo),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header : Guide info ─────────────────────────────────────
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: routeInfo.guidePhotoUrl != null
                        ? NetworkImage('${ApiService.baseUrl}${routeInfo.guidePhotoUrl}')
                        : null,
                    child: routeInfo.guidePhotoUrl == null
                        ? Text(
                            routeInfo.guideName[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Nom + rating
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeInfo.guideName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              routeInfo.ratingDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textLight,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Badge checkpoints
                  if (route.checkpoints.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 12, color: AppColors.primary),
                          const SizedBox(width: 3),
                          Text(
                            '${route.checkpoints.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // ── Trajet : départ → arrivée ──────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icônes timeline
                  Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.green, size: 16),
                      ),
                      Container(
                        width: 2,
                        height: 36,
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag, color: AppColors.error, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),

                  // Adresses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Départ
                        Text(
                          route.startAddress ?? 'Point de départ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 32),

                        // Arrivée
                        Text(
                          route.endAddress ?? 'Point d\'arrivée',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Footer : distance + durée ──────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Distance
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.straighten, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          '${route.distance.toStringAsFixed(1)} km',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    // Séparateur
                    Container(width: 1, height: 20, color: AppColors.textLight.withOpacity(0.3)),
                    // Durée
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _formatDuration(route.duration),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Description si présente ────────────────────────────────
              if (route.description != null && route.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  route.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── États : Loading, Error, Empty ─────────────────────────────────────────
  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.primary),
          SizedBox(height: 16),
          Text('Chargement des circuits...', style: TextStyle(color: AppColors.textLight)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger les circuits',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadRoutes,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Réessayer', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, color: AppColors.textLight.withOpacity(0.5), size: 80),
            const SizedBox(height: 16),
            const Text(
              'Aucun circuit disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isEmpty
                  ? 'Aucun guide n\'a encore créé de circuit.\nRevenez plus tard !'
                  : 'Aucun circuit ne correspond à votre recherche.',
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _filterRoutes('');
                },
                child: const Text('Effacer la recherche'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NAVIGATION
  // ══════════════════════════════════════════════════════════════════════════

  void _openRouteOnMap(RouteWithGuideInfo routeInfo) {
    // Convertir GuideRoute en Map compatible avec MapScreen
    final routeData = routeInfo.route.toJson();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          mode: 'view',
          savedRoute: routeData,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITAIRES
  // ══════════════════════════════════════════════════════════════════════════

  String _formatDuration(double durationInMinutes) {
    if (durationInMinutes < 60) {
      return '${durationInMinutes.toStringAsFixed(0)} min';
    }
    final hours = (durationInMinutes / 60).floor();
    final minutes = (durationInMinutes % 60).toStringAsFixed(0);
    return '${hours}h ${minutes}min';
  }
}