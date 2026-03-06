import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/search_models.dart';
import '../services/api_service.dart';
import '../widgets/whatsapp_contact_button.dart';
import 'review_screen.dart';

// ═══════════════════════════════════════════════════════════════
//  GuideProfileScreen
//  Affiche le profil complet d'un guide sélectionné depuis la
//  SearchScreen. Le touriste peut :
//    - Voir toutes les infos du guide
//    - Le contacter via WhatsApp
//    - Laisser un avis
// ═══════════════════════════════════════════════════════════════

class GuideProfileScreen extends StatefulWidget {
  final SearchGuideResult guide;

  const GuideProfileScreen({Key? key, required this.guide}) : super(key: key);

  @override
  State<GuideProfileScreen> createState() => _GuideProfileScreenState();
}

class _GuideProfileScreenState extends State<GuideProfileScreen> {
  // Retourne true à la SearchScreen si un avis a été soumis
  bool _reviewSubmitted = false;

  // ── Couleurs ──────────────────────────────────────────────────
  static const Color primaryColor   = Color(0xFF2D6A4F);
  static const Color secondaryColor = Color(0xFF1B4332);
  static const Color textDark       = Color(0xFF2B2D42);
  static const Color textLight      = Color(0xFF8D99AE);
  static const Color starColor      = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    final res   = widget.guide;
    final guide = res.guide;

    return WillPopScope(
      // Retourner _reviewSubmitted pour rafraîchir la liste si un avis a été posté
      onWillPop: () async {
        Navigator.pop(context, _reviewSubmitted);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        body: CustomScrollView(
          slivers: [
            // ── AppBar avec photo de couverture ──────────────────
            _buildSliverAppBar(res, guide),

            // ── Contenu ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges + note
                    _buildBadgesRow(guide),
                    const SizedBox(height: 20),

                    // Bio
                    if (guide.bio.isNotEmpty) ...[
                      _buildSectionTitle('À propos'),
                      const SizedBox(height: 8),
                      Text(
                        guide.bio,
                        style: const TextStyle(
                            fontSize: 14, color: textLight, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Infos détaillées
                    _buildInfoCard(guide),
                    const SizedBox(height: 20),

                    // Langues
                    _buildTagsSection('Langues parlées', guide.languages,
                        Icons.language_rounded, primaryColor),
                    const SizedBox(height: 16),

                    // Spécialités
                    _buildTagsSection('Spécialités', guide.specialties,
                        Icons.category_rounded, Colors.blue.shade600),
                    const SizedBox(height: 16),

                    // Villes couvertes
                    _buildTagsSection('Villes couvertes', guide.citiesCovered,
                        Icons.location_on_rounded, Colors.orange.shade600),
                    const SizedBox(height: 28),

                    // ── Boutons d'action ─────────────────────────
                    _buildActionButtons(res, guide),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SliverAppBar avec dégradé et avatar ──────────────────────
  Widget _buildSliverAppBar(SearchGuideResult res, dynamic guide) {
    return SliverAppBar(
      expandedHeight: 220,
      pinned: true,
      backgroundColor: primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context, _reviewSubmitted),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Fond dégradé
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Cercles décoratifs
            Positioned(top: -40, right: -30,
              child: _decorCircle(160, 0.08)),
            Positioned(bottom: -60, left: -20,
              child: _decorCircle(200, 0.06)),
            // Avatar centré
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  _buildAvatar(res.fullName, guide.profilePhotoUrl, radius: 46),
                  const SizedBox(height: 12),
                  Text(
                    res.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Guide Touristique Certifié',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Badges : Premium, Certifié, Note ─────────────────────────
  Widget _buildBadgesRow(dynamic guide) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        // Note étoiles
        if (guide.totalReviews > 0)
          _chip(
            icon: Icons.star_rounded,
            label:
                '${guide.averageRating.toStringAsFixed(1)} (${guide.totalReviews} avis)',
            bgColor: starColor.withOpacity(0.12),
            textColor: const Color(0xFF9A7B00),
            iconColor: starColor,
          ),

        // Certifié
        if (guide.isVerified)
          _chip(
            icon: Icons.verified_rounded,
            label: 'Guide Certifié',
            bgColor: primaryColor.withOpacity(0.1),
            textColor: primaryColor,
            iconColor: primaryColor,
          ),

        // Premium
        if (guide.isPremium)
          _chip(
            icon: Icons.workspace_premium,
            label: 'Premium',
            bgColor: const Color(0xFFFFF3CC),
            textColor: const Color(0xFF9A6F00),
            iconColor: const Color(0xFFFFAA00),
          ),

        // Éco-score
        _chip(
          icon: Icons.eco_rounded,
          label: 'Éco-Score ${guide.ecoScore}/100',
          bgColor: Colors.green.shade50,
          textColor: Colors.green.shade700,
          iconColor: Colors.green.shade600,
        ),
      ],
    );
  }

  // ── Carte infos détaillées ────────────────────────────────────
  Widget _buildInfoCard(dynamic guide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _infoRow(Icons.work_rounded, 'Expérience',
              '${guide.yearsOfExperience} ans'),
          _divider(),
          _infoRow(Icons.eco_rounded, 'Éco-Score',
              '${guide.ecoScore} / 100'),
          _divider(),
          _infoRow(
            Icons.verified_rounded,
            'Statut',
            guide.isVerified ? 'Vérifié ✓' : 'En attente de vérification',
            valueColor: guide.isVerified ? Colors.green : Colors.orange,
          ),
          if (guide.totalReviews > 0) ...[
            _divider(),
            _infoRow(
              Icons.star_rounded,
              'Note moyenne',
              '${guide.averageRating.toStringAsFixed(1)} / 5  (${guide.totalReviews} avis)',
              valueColor: starColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 16, thickness: 0.5);

  Widget _infoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: textLight)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? textDark)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Section avec tags (langues, spécialités, villes) ─────────
  Widget _buildTagsSection(
      String title, List<String> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title, icon: icon, color: color),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: color.withOpacity(0.25)),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                          fontSize: 13,
                          color: color,
                          fontWeight: FontWeight.w500),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ── Boutons Contacter + Laisser un avis ──────────────────────
  Widget _buildActionButtons(SearchGuideResult res, dynamic guide) {
    return Column(
      children: [
        // Bouton WhatsApp (pleine largeur)
        if (res.phone != null && res.phone!.isNotEmpty)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                // Déléguer au widget WhatsAppContactButton via son tap interne
                // On crée une instance temporaire et on appelle _openWhatsApp
                _launchWhatsApp(res.phone!, res.fullName);
              },
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: Text(
                'Contacter ${res.fullName.split(' ').first} via WhatsApp',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 3,
                shadowColor:
                    const Color(0xFF25D366).withOpacity(0.35),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Bouton Laisser un avis
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () => _openReviewScreen(guide, res.fullName),
            icon: const Icon(Icons.star_rounded, size: 20,
                color: primaryColor),
            label: Text(
              guide.totalReviews > 0
                  ? 'Laisser un avis (${guide.totalReviews} existants)'
                  : 'Soyez le premier à laisser un avis',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryColor, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Ouvrir ReviewScreen ───────────────────────────────────────
  Future<void> _openReviewScreen(dynamic guide, String guideName) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewScreen(
          guideId:       guide.id,
          guideName:     guideName,
          guidePhotoUrl: guide.profilePhotoUrl,
        ),
      ),
    );
    if (result == true) {
      setState(() => _reviewSubmitted = true);
    }
  }

  // ── Lancer WhatsApp directement ───────────────────────────────
  Future<void> _launchWhatsApp(String phone, String guideName) async {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final message = Uri.encodeComponent(
      'Bonjour $guideName ! Je viens de voir votre profil sur Morchid Hub. '
      'Pouvons-nous convenir des détails pour un circuit ?',
    );
    final uri = Uri.parse('https://wa.me/$cleaned?text=$message');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback WhatsApp Web
      final webUri = Uri.parse('https://web.whatsapp.com/send?phone=$cleaned');
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Impossible d'ouvrir WhatsApp"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Helpers UI ────────────────────────────────────────────────
  Widget _buildSectionTitle(String title,
      {IconData? icon, Color? color}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: color ?? primaryColor),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark),
        ),
      ],
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAvatar(String fullName, String? photoUrl,
      {double radius = 30}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      final url = photoUrl.startsWith('http')
          ? photoUrl
          : '${ApiService.baseUrl}/$photoUrl';
      return CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor,
        child: ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials(fullName, radius),
          ),
        ),
      );
    }
    return _initials(fullName, radius);
  }

  Widget _initials(String fullName, double radius) => CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor,
        child: Text(
          fullName[0].toUpperCase(),
          style: TextStyle(
              color: Colors.white,
              fontSize: radius * 0.7,
              fontWeight: FontWeight.bold),
        ),
      );

  Widget _decorCircle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(opacity),
        ),
      );
}