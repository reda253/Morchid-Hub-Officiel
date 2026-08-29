import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/ui_kit.dart';
import '../widgets/whatsapp_contact_button.dart';
import '../routes/app_routes.dart';

/// Onglet « Profil » — partagé touriste et guide.
///
/// Extrait de `_buildProfile` (home_screen.dart:1210-1447), `_handleLogout`
/// (home_screen.dart:116-151) et `_buildProfileAvatarWithFallback`
/// (home_screen.dart:283-319). `_buildProfileAvatar` (home_screen.dart:237-282)
/// n'a plus aucun appelant et n'est pas porté.
class ProfileScreen extends StatefulWidget {
  final UserProfileResponse profile;
  final void Function(int) onNavigate;
  const ProfileScreen({Key? key, required this.profile, required this.onNavigate})
      : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await StorageService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }
  }

  Widget _buildProfileAvatarWithFallback({
    required String fullName,
    String? photoUrl,
    required double radius,
    double fontSize = 24,
  }) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return DefaultAvatar(fullName: fullName, radius: radius, fontSize: fontSize);
    }

    String imageUrl = photoUrl;
    if (!photoUrl.startsWith('http')) {
      imageUrl = '${ApiService.baseUrl}/$photoUrl';
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return DefaultAvatar(fullName: fullName, radius: radius, fontSize: fontSize);
          },
          errorBuilder: (context, error, stackTrace) {
            return DefaultAvatar(fullName: fullName, radius: radius, fontSize: fontSize);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.profile.user;
    final guide = widget.profile.guideProfile;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          // Accès admin. Le shell n'a que deux jeux d'onglets (touriste, guide),
          // donc la route /admin n'était atteignable depuis aucun écran depuis
          // que home_screen.dart a été remplacé par MainShell.
          //
          // `isAdmin` n'est qu'un cache d'affichage rafraîchi à la connexion
          // depuis la liste blanche ADMIN_EMAILS : il décide seulement si le
          // bouton est visible. L'autorisation réelle reste `require_admin`
          // côté serveur, qui ne lit jamais cette colonne.
          if (user.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Administration',
              onPressed: () => Navigator.pushNamed(context, AppRoutes.admin),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              _buildProfileAvatarWithFallback(
                fullName: user.fullName,
                photoUrl: guide?.profilePhotoUrl,
                radius: 60,
                fontSize: 48,
              ),
              const SizedBox(height: 24),
              Text(
                user.fullName,
                style: AppTextStyles.headlineLg.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: (user.role == 'guide' ? AppColors.primary : AppColors.accent)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      user.role == 'guide' ? Icons.tour : Icons.flight_takeoff,
                      size: 18,
                      color: user.role == 'guide' ? AppColors.primary : AppColors.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.role == 'guide' ? 'Guide Touristique' : 'Touriste',
                      style: AppTextStyles.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: user.role == 'guide' ? AppColors.primary : AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              InfoCard(
                title: 'Informations personnelles',
                children: [
                  InfoRow(icon: Icons.email, label: 'Email', value: user.email),
                  InfoRow(icon: Icons.phone, label: 'Téléphone', value: user.phone),
                  if (user.role == 'guide' && user.phone.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          const SizedBox(width: 32),
                          const SizedBox(width: 12),
                          WhatsAppContactButton(phone: user.phone, guideName: user.fullName),
                          const SizedBox(width: 12),
                          Text(
                            'Contacter via WhatsApp',
                            style: AppTextStyles.bodySm.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  InfoRow(
                    icon: Icons.verified_user,
                    label: 'Email vérifié',
                    value: user.isEmailVerified ? 'Oui' : 'Non',
                    valueColor: user.isEmailVerified ? AppColors.success : AppColors.warning,
                  ),
                  InfoRow(
                    icon: Icons.calendar_today,
                    label: 'Membre depuis',
                    value: _formatDate(user.createdAt),
                  ),
                ],
              ),
              if (guide != null) ...[
                const SizedBox(height: 16),
                InfoCard(
                  title: 'Profil Guide',
                  children: [
                    InfoRow(icon: Icons.eco, label: 'Éco-Score', value: '${guide.ecoScore}/100'),
                    InfoRow(
                      icon: Icons.verified,
                      label: 'Statut',
                      value: guide.isVerified ? 'Vérifié' : 'En attente',
                      valueColor: guide.isVerified ? AppColors.success : AppColors.warning,
                    ),
                    InfoRow(icon: Icons.work, label: 'Expérience', value: '${guide.yearsOfExperience} ans'),
                    InfoRow(icon: Icons.language, label: 'Langues', value: guide.languages.join(', ')),
                    InfoRow(
                      icon: Icons.star_rounded,
                      label: 'Note moyenne',
                      value: guide.totalReviews > 0
                          ? '${guide.averageRating.toStringAsFixed(1)} / 5 (${guide.totalReviews} avis)'
                          : 'Aucun avis',
                      valueColor: guide.totalReviews > 0 ? AppColors.sand : AppColors.textLight,
                    ),
                  ],
                ),
              ],
              // Les deux boutons d'avis qui se trouvaient ici — « Voir les N
              // avis » côté guide, « Laisser un avis sur un guide » côté
              // touriste — ont été retirés. Le profil décrit *qui l'on est* ;
              // ces boutons y greffaient une action appartenant à un autre
              // parcours, et le second n'ouvrait même pas un avis mais la
              // recherche. Les deux chemins existent déjà à leur place :
              // le guide passe par « Voir mes avis » sur son tableau de bord,
              // le touriste par la fiche d'un guide.
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
