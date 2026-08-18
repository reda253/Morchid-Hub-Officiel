import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/premium_modal_widget.dart';
import '../widgets/stat_tile.dart';
import '../widgets/ui_kit.dart';
import '../routes/app_routes.dart';

/// Tableau de bord du guide.
///
/// Extrait de `_buildGuideDashboard` (home_screen.dart:816-1039),
/// `_buildGuideRatingBanner` (home_screen.dart:1042-1092), `_buildPremiumBanner`
/// et `_showPremiumModal` (home_screen.dart:1710-1830). `_buildStatCard`
/// (home_screen.dart:1448-1498) est du code mort (`unused_element`) et n'est
/// pas porté — le dashboard construisait déjà `StatTile` directement.
///
/// Les trois anciens `_buildActionButton` sont portés vers `ui_kit.ActionRow`
/// (et non `ui_kit.ActionButton`) afin de préserver le flag `enabled` d'origine
/// — notamment celui de "Demander la certification", qui encode le workflow
/// d'approbation des guides et ne doit pas devenir un bouton muet.
class GuideDashboardScreen extends StatefulWidget {
  final UserProfileResponse profile;
  final void Function(int) onNavigate;
  const GuideDashboardScreen({Key? key, required this.profile, required this.onNavigate})
      : super(key: key);

  @override
  State<GuideDashboardScreen> createState() => _GuideDashboardScreenState();
}

class _GuideDashboardScreenState extends State<GuideDashboardScreen> {
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

  Widget _buildPremiumBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.sand, AppColors.warning],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium, color: AppColors.onPrimary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Passez au Premium',
                        style: AppTextStyles.titleMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Trajets illimités · Badge Premium',
                        style: AppTextStyles.bodySm.copyWith(color: AppColors.onPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showPremiumModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onPrimary,
                foregroundColor: AppColors.warning,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Découvrir Premium', style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideRatingBanner(GuideProfile guide) {
    return GestureDetector(
      onTap: () => _openReviewScreen(
        guideId: guide.id,
        guideName: widget.profile.user.fullName,
        guidePhotoUrl: guide.profilePhotoUrl,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.sand),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.sand, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Votre note : ${guide.averageRating.toStringAsFixed(1)} / 5',
                      style: AppTextStyles.bodyLg.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('Basée sur ${guide.totalReviews} avis — Appuyez pour voir',
                      style: AppTextStyles.bodySm.copyWith(fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.profile.user;
    final guide = widget.profile.guideProfile;
    final stats = widget.profile.stats ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    DefaultAvatar(fullName: user.fullName, radius: 26, fontSize: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bonjour,', style: AppTextStyles.bodySm),
                          Row(
                            children: [
                              Flexible(
                                child: Text(user.fullName,
                                    style: AppTextStyles.headlineMd.copyWith(fontSize: 22),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                              if (guide?.isPremiumActive ?? false) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.workspace_premium, color: AppColors.sand, size: 20),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (guide != null && !guide.isPremiumActive)
              SliverToBoxAdapter(child: _buildPremiumBanner()),
            if (guide != null && !guide.isVerified)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.onPrimary, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Compte en attente de vérification',
                                style: AppTextStyles.bodyLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Votre profil est en cours de vérification par notre équipe.',
                                style: AppTextStyles.bodySm.copyWith(color: AppColors.onPrimary, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (guide != null && guide.totalReviews > 0)
              SliverToBoxAdapter(child: _buildGuideRatingBanner(guide)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.55,
                ),
                delegate: SliverChildListDelegate([
                  StatTile(
                    label: 'Réservations',
                    value: stats['total_bookings']?.toString() ?? '0',
                    icon: Icons.calendar_today_outlined,
                  ),
                  StatTile(
                    label: 'Éco-Score',
                    value: guide?.ecoScore.toString() ?? '0',
                    icon: Icons.eco_outlined,
                  ),
                  StatTile(
                    label: 'Note moyenne',
                    value: guide != null && guide.totalReviews > 0
                        ? guide.averageRating.toStringAsFixed(1)
                        : '—',
                    icon: Icons.star_outline,
                  ),
                  StatTile(
                    label: 'Revenus',
                    value: '${stats['total_revenue'] ?? 0} DH',
                    icon: Icons.payments_outlined,
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Actions Rapides', style: AppTextStyles.headlineMd.copyWith(fontSize: 20)),
                    const SizedBox(height: 16),
                    ActionRow(
                      icon: Icons.verified_user,
                      title: 'Demander la certification',
                      subtitle: 'Obtenez votre badge officiel',
                      enabled: guide?.isVerified == false,
                      onTap: () {
                        Navigator.pushNamed(context, AppRoutes.verifyGuide);
                      },
                    ),
                    const SizedBox(height: 16),
                    ActionRow(
                      icon: Icons.map,
                      title: 'Définir mon trajet',
                      subtitle: 'Créez un itinéraire pour vos clients',
                      enabled: true,
                      onTap: () async {
                        final result = await Navigator.pushNamed(
                          context, AppRoutes.map,
                          arguments: const MapArgs(mode: 'edit'),
                        );
                        if (result == null) return;
                        try {
                          await ApiService.saveGuideRoute(result as Map<String, dynamic>);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Trajet mis à jour !'), backgroundColor: AppColors.success),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('❌ Erreur : $e'), backgroundColor: AppColors.error),
                          );
                        }
                      },
                    ),
                    if (guide != null) ...[
                      const SizedBox(height: 16),
                      ActionRow(
                        icon: Icons.reviews_rounded,
                        title: 'Voir mes avis',
                        subtitle: guide.totalReviews > 0
                            ? '${guide.totalReviews} avis · ${guide.averageRating.toStringAsFixed(1)} ★'
                            : 'Aucun avis reçu pour l\'instant',
                        enabled: true,
                        onTap: () => _openReviewScreen(
                          guideId: guide.id,
                          guideName: user.fullName,
                          guidePhotoUrl: guide.profilePhotoUrl,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
