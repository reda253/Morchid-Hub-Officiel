import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/search_models.dart';
import '../utils/app_colors.dart';

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
    if (_results.isEmpty) return const Center(child: Text('Aucun guide trouvé'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final res = _results[index];
        return Card(
          child: ListTile(
            title: Text(res.fullName),
            subtitle: Text(res.guide.specialties.join(', ')),
            trailing: Text('${res.guide.averageRating} ★'),
          ),
        );
      },
    );
  }
}