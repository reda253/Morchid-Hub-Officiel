import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/search_models.dart';
import '../utils/app_colors.dart';
import 'review_screen.dart';
import 'guide_profile_screen.dart'; // ✅ Nouveau : profil du guide
import '../services/storage_service.dart';
import '../widgets/whatsapp_contact_button.dart'; // ✅ Nouveau : bouton WhatsApp

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // 1. DEFINITION OF VARIABLES (The missing getters)
  final TextEditingController _searchController = TextEditingController();
  List<SearchGuideResult> _results = [];
  bool _isSearching = false;
  
  String? _selectedCity;
  String? _selectedSpecialty;
  double? _minRating;
  int? _minEcoScore;

  final List<String> _specialties = ['nature', 'culture', 'aventure', 'gastronomie', 'histoire'];
  final List<String> _cities = ['Marrakech', 'Casablanca', 'Fès', 'Agadir', 'Tanger'];

  // 2. THE SEARCH FUNCTION (Inside the State class)
  void _performSearch() async {
    setState(() => _isSearching = true);
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
      });
    } catch (e) {
      setState(() => _isSearching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trouver un Guide'),
        backgroundColor: const Color(0xFF2D6A4F),
      ),
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
      color: Colors.white,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nom ou mot-clé...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _performSearch,
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Ville'),
                  value: _selectedCity,
                  items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCity = val),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Eco-Score min'),
                  value: _minEcoScore,
                  items: [0, 30, 50, 70, 90].map((s) => DropdownMenuItem(value: s, child: Text('$s+'))).toList(),
                  onChanged: (val) => setState(() => _minEcoScore = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _specialties.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(s),
                  selected: _selectedSpecialty == s,
                  onSelected: (val) => setState(() => _selectedSpecialty = val ? s : null),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Aucun guide trouvé',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text("Essayez d'autres filtres",
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildGuideCard(_results[index]),
    );
  }

  // ── Carte guide enrichie ──────────────────────────────────────────────────
  Widget _buildGuideCard(SearchGuideResult res) {
    final guide = res.guide;
    const primaryColor = Color(0xFF2D6A4F);
    const starColor = Color(0xFFFFC107);

    return GestureDetector(
      onTap: () => _openGuideProfile(res),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header : avatar + nom + badges ─────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildAvatar(res.fullName, guide.profilePhotoUrl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + badge Premium
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                res.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2B2D42),
                                ),
                              ),
                            ),
                            if (guide.isPremium)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.workspace_premium,
                                        color: Colors.white, size: 12),
                                    SizedBox(width: 3),
                                    Text('Premium',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Spécialités
                        Text(
                          guide.specialties.join(' · '),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF8D99AE)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Note + certifié
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: starColor, size: 16),
                            const SizedBox(width: 3),
                            Text(
                              guide.totalReviews > 0
                                  ? '${guide.averageRating.toStringAsFixed(1)} (${guide.totalReviews})'
                                  : 'Nouveau',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2B2D42)),
                            ),
                            const SizedBox(width: 10),
                            if (guide.isVerified)
                              const Row(children: [
                                Icon(Icons.verified_rounded,
                                    color: primaryColor, size: 15),
                                SizedBox(width: 3),
                                Text('Certifié',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: primaryColor,
                                        fontWeight: FontWeight.w500)),
                              ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Villes + Éco-score ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: Color(0xFF8D99AE)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      guide.citiesCovered.join(', '),
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF8D99AE)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.eco_rounded,
                            size: 12, color: Colors.green.shade600),
                        const SizedBox(width: 3),
                        Text(
                          'Éco ${guide.ecoScore}',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Actions : Voir profil + WhatsApp ───────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openGuideProfile(res),
                      icon: const Icon(Icons.person_rounded,
                          size: 16, color: primaryColor),
                      label: const Text(
                        'Voir le profil',
                        style: TextStyle(
                            fontSize: 13,
                            color: primaryColor,
                            fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: const BorderSide(color: primaryColor, width: 1.2),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ✅ Bouton WhatsApp
                  WhatsAppContactButton(
                    phone: res.phone ?? '',
                    guideName: res.fullName,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar photo ou initiale ──────────────────────────────────────────────
  Widget _buildAvatar(String fullName, String? photoUrl) {
    const primaryColor = Color(0xFF2D6A4F);
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final imageUrl = photoUrl.startsWith('http')
          ? photoUrl
          : '${ApiService.baseUrl}/$photoUrl';
      return CircleAvatar(
        radius: 30,
        backgroundColor: primaryColor,
        child: ClipOval(
          child: Image.network(
            imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initialAvatar(fullName),
          ),
        ),
      );
    }
    return _initialAvatar(fullName);
  }

  Widget _initialAvatar(String fullName) => CircleAvatar(
        radius: 30,
        backgroundColor: const Color(0xFF2D6A4F),
        child: Text(
          fullName[0].toUpperCase(),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
      );

  // ── Navigation vers le profil guide ──────────────────────────────────────
  Future<void> _openGuideProfile(SearchGuideResult res) async {
    // Sauvegarder dans l'historique avec le numéro pour le bouton WhatsApp
    await StorageService.saveLastGuide({
      'id':    res.guide.id,
      'name':  res.fullName,
      'photo': res.guide.profilePhotoUrl,
      'phone': res.phone ?? '', // ✅ Requis pour WhatsAppContactButton dans HomeScreen
    });

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => GuideProfileScreen(guide: res),
      ),
    );

    // Rafraîchir si un avis a été soumis depuis le profil
    if (result == true && mounted) {
      _performSearch();
    }
  }
}