import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/motion.dart';
import '../widgets/premium_modal_widget.dart';
import '../widgets/stat_tile.dart';
import '../widgets/ui_kit.dart';
import '../routes/app_routes.dart';

/// Tableau de bord du guide.
///
/// L'ordre des blocs encode une priorité, il n'est pas arbitraire :
///
///   1. l'en-tête (qui suis-je, suis-je Premium) ;
///   2. l'avis de vérification, **s'il y a lieu** — tant que le compte n'est
///      pas approuvé le guide n'apparaît dans aucune recherche, c'est donc
///      l'information la plus urgente de l'écran ;
///   3. les chiffres — ce pour quoi on ouvre un tableau de bord ;
///   4. les actions ;
///   5. la promotion Premium, **en dernier**. Elle ouvrait l'écran auparavant :
///      un guide était accueilli par une publicité avant ses propres données.
///
/// Une gouttière unique de 20 px : la version précédente en alternait six
/// (16 / 20 / 16 / 16 / 16 / 24), ce qui suffit à faire paraître un écran
/// « pas fini » sans qu'on sache dire pourquoi.
class GuideDashboardScreen extends StatefulWidget {
  final UserProfileResponse profile;
  final void Function(int) onNavigate;
  const GuideDashboardScreen({Key? key, required this.profile, required this.onNavigate})
      : super(key: key);

  @override
  State<GuideDashboardScreen> createState() => _GuideDashboardScreenState();
}

class _GuideDashboardScreenState extends State<GuideDashboardScreen> {
  static const double _gutter = 20;

  Future<void> _openReviewScreen({
    required String guideId,
    required String guideName,
    String? guidePhotoUrl,
  }) async {
    await Navigator.pushNamed<bool>(
      context,
      AppRoutes.review,
      arguments: ReviewArgs(
        guideId: guideId,
        guideName: guideName,
        guidePhotoUrl: guidePhotoUrl,
      ),
    );
  }

  Future<void> _showPremiumModal() async {
    if (widget.profile.guideProfile == null) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PremiumModal(),
    );

    if (result == true && mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.payment,
        arguments: const PaymentArgs(
          amount: 10.0,
          planName: 'Abonnement Mensuel Guide',
        ),
      );
    }
  }

  // ── En-tête ───────────────────────────────────────────────────────────────

  /// Remplace le couple `AppBar('Dashboard')` + rangée de salutation : deux
  /// en-têtes empilés dont l'un portait un titre anglais dans une app
  /// française, et n'apprenait rien que la barre d'onglets ne dise déjà.
  Widget _buildHeader(UserData user, GuideProfile? guide) {
    return Container(
      padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(
        children: [
          DefaultAvatar(fullName: user.fullName, radius: 24, fontSize: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BONJOUR', style: AppTextStyles.labelCaps.copyWith(fontSize: 11)),
                const SizedBox(height: 3),
                Text(
                  user.fullName,
                  style: AppTextStyles.headlineMd.copyWith(fontSize: 21),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Pastille plutôt qu'icône flottante : le statut Premium est une
          // information, elle se lit mieux nommée qu'illustrée.
          if (guide?.isPremiumActive ?? false) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.sand.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.sand),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.workspace_premium, size: 13, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    'PREMIUM',
                    style: AppTextStyles.labelCaps
                        .copyWith(fontSize: 10, color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Avis de vérification ──────────────────────────────────────────────────

  /// Aplat orange plein remplacé par une carte teintée — même motif que
  /// [StatusBadge] (fond à 8 %, bordure à 35 %). Un compte en attente est un
  /// *statut*, pas une alarme ; le bloc plein criait plus fort que les données.
  ///
  /// Le texte dit désormais la conséquence réelle (invisible dans les
  /// recherches) au lieu de « en cours de vérification », qui n'apprend rien.
  Widget _buildVerificationNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, size: 20, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profil en cours de vérification', style: AppTextStyles.titleSm),
                const SizedBox(height: 3),
                Text(
                  "Vous n'apparaîtrez pas dans les recherches tant que notre "
                  "équipe n'a pas validé vos documents.",
                  style: AppTextStyles.bodyXs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Promotion Premium ─────────────────────────────────────────────────────

  /// Le dégradé sable → orange est remplacé par un aplat Deep Atlantic.
  /// Un dégradé diagonal à deux teintes chaudes est le réflexe décoratif par
  /// défaut ; ici il entrait en plus en collision avec l'avis de vérification,
  /// qui est orange lui aussi. L'aplat sombre reprend l'écran de démarrage,
  /// donc la promotion se lit comme la marque et non comme une bannière.
  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, size: 17, color: AppColors.sand),
              const SizedBox(width: 8),
              Text(
                'PREMIUM',
                style: AppTextStyles.labelCaps.copyWith(color: AppColors.sand, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Publiez autant de trajets que vous voulez',
            style: AppTextStyles.headlineMd
                .copyWith(color: AppColors.onPrimary, fontSize: 20),
          ),
          const SizedBox(height: 6),
          // Chiffre concret plutôt que « trajets illimités » : la limite du
          // forfait gratuit est de 2 trajets actifs, la dire rend l'offre
          // vérifiable.
          Text(
            'Le forfait gratuit s\'arrête à 2 trajets actifs. Le badge Premium '
            'apparaît aussi sur votre profil public.',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.onPrimary.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showPremiumModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sand,
                foregroundColor: AppColors.secondary,
              ),
              child: const Text('Découvrir Premium'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sauvegarde de trajet ──────────────────────────────────────────────────

  Future<void> _saveRoute() async {
    final result = await Navigator.pushNamed(
      context, AppRoutes.map,
      arguments: const MapArgs(mode: 'edit'),
    );
    if (result == null) return;
    try {
      await ApiService.saveGuideRoute(result as Map<String, dynamic>);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trajet mis à jour'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      // Le texte de l'exception n'est jamais affiché : il peut porter l'hôte
      // et le nom de la base. Message constant, action de reprise.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Le trajet n'a pas pu être enregistré."),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: AppColors.onPrimary,
            onPressed: _saveRoute,
          ),
        ),
      );
    }
  }

  // ── Écran ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = widget.profile.user;
    final guide = widget.profile.guideProfile;
    final stats = widget.profile.stats ?? {};
    final hasReviews = guide != null && guide.totalReviews > 0;

    // Un compteur partagé : chaque bloc réellement affiché avance la cascade,
    // sinon un bloc masqué laisserait un trou dans le rythme d'entrée.
    var step = 0;
    Widget staged(Widget child) => FadeSlideIn(index: step++, child: child);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(user, guide)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_gutter, 20, _gutter, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (guide != null && !guide.isVerified) ...[
                    staged(_buildVerificationNotice()),
                    const SizedBox(height: 20),
                  ],

                  // Panneau unique au lieu de quatre cartes en grille : la
                  // grille en 2 × 2 avec `childAspectRatio: 1.55` laissait
                  // ~23 px de vide sous chaque chiffre, d'où des tuiles qui
                  // paraissaient trop grandes pour ce qu'elles contenaient.
                  staged(StatGroup(cells: [
                    StatCell(
                      label: 'Réservations',
                      value: stats['total_bookings']?.toString() ?? '0',
                    ),
                    StatCell(
                      label: 'Éco-score',
                      value: guide?.ecoScore.toString() ?? '0',
                    ),
                    StatCell(
                      label: 'Note moyenne',
                      value: hasReviews ? guide.averageRating.toStringAsFixed(1) : '—',
                      unit: hasReviews ? '/5' : null,
                    ),
                    StatCell(
                      label: 'Revenus',
                      value: '${stats['total_revenue'] ?? 0}',
                      unit: 'DH',
                    ),
                  ])),
                  const SizedBox(height: 28),

                  staged(const SectionHeader(title: 'Actions rapides')),

                  // Masquée dès que le guide est certifié : une fois le badge
                  // obtenu, demander la certification n'a plus d'objet.
                  if (guide != null && !guide.isVerified) ...[
                    staged(ActionRow(
                      icon: Icons.verified_user_rounded,
                      title: 'Demander la certification',
                      subtitle: 'Obtenez votre badge officiel',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.verifyGuide),
                    )),
                    const SizedBox(height: 12),
                  ],

                  staged(ActionRow(
                    icon: Icons.route_rounded,
                    title: 'Définir mon trajet',
                    subtitle: 'Créez un itinéraire pour vos clients',
                    onTap: _saveRoute,
                  )),

                  if (guide != null) ...[
                    const SizedBox(height: 12),
                    // Cette rangée remplace aussi l'ancien bandeau de note :
                    // la note apparaissait trois fois sur l'écran (bandeau,
                    // tuile KPI, sous-titre ici) et menait deux fois au même
                    // endroit.
                    staged(ActionRow(
                      icon: Icons.reviews_rounded,
                      title: 'Voir mes avis',
                      subtitle: hasReviews
                          ? '${guide.totalReviews} avis · ${guide.averageRating.toStringAsFixed(1)} ★'
                          : 'Aucun avis reçu pour l\'instant',
                      onTap: () => _openReviewScreen(
                        guideId: guide.id,
                        guideName: user.fullName,
                        guidePhotoUrl: guide.profilePhotoUrl,
                      ),
                    )),
                  ],

                  if (guide != null && !guide.isPremiumActive) ...[
                    const SizedBox(height: 28),
                    staged(_buildPremiumBanner()),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
