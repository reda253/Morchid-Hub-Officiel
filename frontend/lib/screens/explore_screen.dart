import 'package:flutter/material.dart';

import '../models/search_models.dart';
import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/error_state.dart';
import '../widgets/ui_kit.dart';
import '../widgets/whatsapp_contact_button.dart';
import 'guide_profile_screen.dart';
import 'review_screen.dart';
import 'search_screen.dart';

/// Onglet « Explorer » du touriste.
///
/// Extrait de `_buildTouristDashboard` et des sections qui la composent
/// (home_screen.dart:495-811), plus `_loadExplore`/`_loadLastGuide`
/// (home_screen.dart:66-88). `_trendingCard`/`_expertCard` (home_screen.dart
/// :619-638, :662-680) sont supprimées : elles ne faisaient déjà que
/// construire `ui_kit.ExperienceCard`/`ui_kit.ExpertCard` — leurs appels sont
/// désormais directs.
class ExploreScreen extends StatefulWidget {
  final UserProfileResponse profile;
  final void Function(int) onNavigate;
  const ExploreScreen({Key? key, required this.profile, required this.onNavigate})
      : super(key: key);

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  List<dynamic> _trending = [];
  List<SearchGuideResult> _experts = [];
  final List<String> _regions = ['Sahara', 'Atlas', 'Villes impériales', 'Souks'];

  Map<String, dynamic>? _lastGuide;
  String? _lastGuidePhone;

  bool _isLoading = true;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _loadExplore();
    _loadLastGuide();
  }

  Future<void> _loadLastGuide() async {
    final guide = await StorageService.getLastGuide();
    if (!mounted || guide == null) return;
    setState(() {
      _lastGuide = guide;
      _lastGuidePhone = guide['phone'] as String?;
    });
  }

  Future<void> _loadExplore() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final trending = await ApiService.fetchAllRoutes(limit: 6);
      final experts = await ApiService.searchGuides(verifiedOnly: true, limit: 6);
      if (!mounted) return;
      setState(() {
        _trending = trending;
        _experts = experts;
        _isLoading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _openReviewScreen({
    required String guideId,
    required String guideName,
    String? guidePhotoUrl,
  }) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          guideId: guideId,
          guideName: guideName,
          guidePhotoUrl: guidePhotoUrl,
        ),
      ),
    );
  }

  Widget _buildTouristDashboard() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Découvrez l\'âme du Maroc',
                      style: AppTextStyles.headlineMd.copyWith(fontSize: 26)),
                  const SizedBox(height: 6),
                  Text('Des voyages sur mesure par des experts locaux vérifiés.',
                      style: AppTextStyles.bodyLg.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textLight, size: 20),
                          const SizedBox(width: 10),
                          Text('Rechercher une destination…',
                              style: AppTextStyles.bodyLg.copyWith(color: AppColors.textLight)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _exploreRegions(),
                  const SizedBox(height: 24),
                  _trendingSection(),
                  const SizedBox(height: 24),
                  _expertsSection(),
                  const SizedBox(height: 16),
                  _buildLeaveReviewSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exploreRegions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Explorer par région'),
        FilterChipBar(
          options: _regions,
          onSelected: (_) => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const SearchScreen()),
          ),
        ),
      ],
    );
  }

  Widget _trendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Trajets tendance',
          actionLabel: 'Voir tout',
          onAction: () => Navigator.pushNamed(context, '/available_routes_screen'),
        ),
        if (_trending.isEmpty)
          Text('Aucun trajet disponible pour le moment.', style: AppTextStyles.bodySm)
        else
          Column(
            children: _trending.take(4).map((item) {
              final map = item as Map<String, dynamic>;
              final route = (map['route'] ?? {}) as Map<String, dynamic>;
              final name = (map['guide_name'] ?? 'Guide') as String;
              final start = (route['start_address'] ?? '') as String;
              final end = (route['end_address'] ?? '') as String;
              final price = route['price'];
              final rating = (map['guide_rating'] ?? 0).toDouble();
              final photo = map['guide_photo_url'] as String?;
              final imageUrl = (photo != null && photo.isNotEmpty)
                  ? (photo.startsWith('http') ? photo : '${ApiService.baseUrl}/$photo')
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExperienceCard(
                  title: (start.isEmpty && end.isEmpty) ? 'Itinéraire guidé' : '$start → $end',
                  imageUrl: imageUrl,
                  priceLabel: price != null ? '${(price as num).toStringAsFixed(0)} DH' : null,
                  byline: 'par $name',
                  rating: rating > 0 ? rating : null,
                  onTap: () => Navigator.pushNamed(context, '/available_routes_screen'),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _expertsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Rencontrez des experts locaux'),
        if (_experts.isEmpty)
          Text('Bientôt de nouveaux guides vérifiés.', style: AppTextStyles.bodySm)
        else
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _experts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final r = _experts[i];
                final g = r.guide;
                final photo = g.profilePhotoUrl;
                final avatarUrl = (photo != null && photo.isNotEmpty)
                    ? (photo.startsWith('http') ? photo : '${ApiService.baseUrl}/$photo')
                    : null;
                return ExpertCard(
                  name: r.fullName,
                  region: g.citiesCovered.join(', '),
                  avatarUrl: avatarUrl,
                  verified: g.isVerified,
                  rating: g.totalReviews > 0 ? g.averageRating : null,
                  reviews: g.totalReviews,
                  quote: g.bio,
                  onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => GuideProfileScreen(guide: r)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildLeaveReviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.rate_review_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Votre avis compte !', style: AppTextStyles.titleMd.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text('Notez un guide ou un trajet que vous avez vécu',
                        style: AppTextStyles.bodySm.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              icon: const Icon(Icons.star_rounded, size: 18),
              label: const Text('Rechercher un guide à noter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          if (_lastGuide != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openReviewScreen(
                      guideId: _lastGuide!['id'],
                      guideName: _lastGuide!['name'],
                      guidePhotoUrl: _lastGuide!['photo'],
                    ),
                    icon: const Icon(Icons.history, size: 18, color: AppColors.primary),
                    label: Text(
                      'Noter ${_lastGuide!['name']}',
                      style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w500, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_lastGuidePhone != null && _lastGuidePhone!.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  WhatsAppContactButton(
                    phone: _lastGuidePhone!,
                    guideName: _lastGuide!['name'] ?? 'le guide',
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Scaffold(
      appBar: AppBar(title: const Text('Explorer')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? ErrorState.fromApiError(error, onRetry: _loadExplore)
              : _buildTouristDashboard(),
    );
  }
}
