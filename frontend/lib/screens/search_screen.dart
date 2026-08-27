import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/search_models.dart';
import '../models/user_models.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/error_state.dart';
import '../widgets/ui_kit.dart';
import '../services/storage_service.dart';
import '../widgets/whatsapp_contact_button.dart';
import '../routes/app_routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchGuideResult> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  ApiError? _searchError;

  String? _selectedCity;
  String? _selectedSpecialty;
  double? _minRating;
  int? _minEcoScore;

  final List<String> _specialties = ['nature', 'culture', 'aventure', 'gastronomie', 'histoire'];
  final List<String> _cities = ['Marrakech', 'Casablanca', 'Fès', 'Agadir', 'Tanger'];

  void _performSearch() async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await ApiService.searchGuides(
        query: _searchController.text.isEmpty ? null : _searchController.text,
        city: _selectedCity,
        specialty: _selectedSpecialty,
        minRating: _minRating,
        minEcoScore: _minEcoScore,
      );
      setState(() {
        _results = results;
        _isSearching = false;
        _hasSearched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        // ApiService.searchGuides always throws models/user_models.dart's
        // ApiError (it wraps every failure before rethrowing).
        _searchError = e as ApiError;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trouver un guide')),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildResultsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onSubmitted: (_) => _performSearch(),
            decoration: InputDecoration(
              hintText: 'Nom, ville ou mot-clé…',
              prefixIcon: const Icon(Icons.search, color: AppColors.textLight),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward, color: AppColors.primary),
                onPressed: _performSearch,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Ville', isDense: true),
                  value: _selectedCity,
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCity = val),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Éco-score min', isDense: true),
                  value: _minEcoScore,
                  items: [0, 30, 50, 70, 90]
                      .map((s) => DropdownMenuItem(value: s, child: Text('$s+')))
                      .toList(),
                  onChanged: (val) => setState(() => _minEcoScore = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilterChipBar(
            options: _specialties,
            selected: _selectedSpecialty,
            onSelected: (s) => setState(() {
              _selectedSpecialty = _selectedSpecialty == s ? null : s;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_searchError != null) {
      return ErrorState.fromApiError(_searchError!, onRetry: _performSearch);
    }
    if (!_hasSearched) {
      return _emptyState(Icons.travel_explore, 'Recherchez un guide', 'Filtrez par ville, spécialité ou éco-score.');
    }
    if (_results.isEmpty) {
      return _emptyState(Icons.search_off_rounded, 'Aucun guide trouvé', "Essayez d'autres filtres.");
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildGuideCard(_results[index]),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: AppColors.outline),
          const SizedBox(height: 14),
          Text(title, style: AppTextStyles.titleMd),
          const SizedBox(height: 6),
          Text(subtitle, style: AppTextStyles.bodySm),
        ],
      ),
    );
  }

  Widget _buildGuideCard(SearchGuideResult res) {
    final guide = res.guide;
    return AppCard(
      onTap: () => _openGuideProfile(res),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(res.fullName, guide.profilePhotoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Le badge Premium a disparu : PublicGuideCard n'expose
                    // plus is_premium, qui relève de la facturation du guide
                    // et non de la fiche publique.
                    Text(res.fullName,
                        style: AppTextStyles.titleMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(guide.specialties.join(' · '),
                        style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.star, size: 16),
                        const SizedBox(width: 3),
                        Text(
                          guide.totalReviews > 0
                              ? '${guide.averageRating.toStringAsFixed(1)} (${guide.totalReviews})'
                              : 'Nouveau',
                          style: AppTextStyles.bodySm.copyWith(fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        const SizedBox(width: 12),
                        if (guide.isVerified) const VerifiedBadge(label: 'CERTIFIÉ'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 15, color: AppColors.textLight),
              const SizedBox(width: 4),
              Expanded(
                child: Text(guide.citiesCovered.join(', '),
                    style: AppTextStyles.bodySm, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mint.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, size: 12, color: AppColors.mint),
                    const SizedBox(width: 3),
                    Text('Éco ${guide.ecoScore}',
                        style: AppTextStyles.labelCaps.copyWith(color: AppColors.mint, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGuideProfile(res),
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('Voir le profil'),
                ),
              ),
              const SizedBox(width: 10),
              // Le numéro n'est plus dans la réponse de recherche (endpoint
              // anonyme) : il est récupéré à la demande, session requise.
              FutureBuilder<String?>(
                future: ApiService.fetchGuidePhone(res.guide.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final phone = snapshot.data;
                  if (phone == null || phone.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return WhatsAppContactButton(phone: phone, guideName: res.fullName);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String fullName, String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final imageUrl = photoUrl.startsWith('http') ? photoUrl : '${ApiService.baseUrl}/$photoUrl';
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.primary,
        child: ClipOval(
          child: Image.network(
            imageUrl,
            width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => DefaultAvatar(fullName: fullName, radius: 28),
          ),
        ),
      );
    }
    return DefaultAvatar(fullName: fullName, radius: 28);
  }

  Future<void> _openGuideProfile(SearchGuideResult res) async {
    await StorageService.saveLastGuide({
      'id': res.guide.id,
      'name': res.fullName,
      'photo': res.guide.profilePhotoUrl,
    });

    if (!mounted) return;

    final result = await Navigator.pushNamed<bool>(
      context,
      AppRoutes.guideProfile,
      arguments: GuideProfileArgs(guide: res),
    );

    if (result == true && mounted) {
      _performSearch();
    }
  }
}
