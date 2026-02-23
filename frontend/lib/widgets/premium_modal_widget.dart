import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../services/api_service.dart';

/// Modal élégant pour promouvoir l'abonnement Premium
class PremiumModal extends StatelessWidget {
  final bool isCurrentlyPremium;
  final int? daysRemaining;
  
  const PremiumModal({
    Key? key,
    this.isCurrentlyPremium = false,
    this.daysRemaining,
  }) : super(key: key);

  static void show(BuildContext context, {bool isPremium = false, int? days}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PremiumModal(
        isCurrentlyPremium: isPremium,
        daysRemaining: days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // ── Handle ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Icône Premium ───────────────────────────────────────
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Titre ───────────────────────────────────────────────
                  if (isCurrentlyPremium) ...[
                    const Text(
                      '👑 Vous êtes Premium',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      daysRemaining != null
                          ? '$daysRemaining jours restants'
                          : 'Abonnement actif',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Passez au Premium',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Libérez tout le potentiel de Morchid Hub',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Prix ────────────────────────────────────────────────
                  if (!isCurrentlyPremium)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.shade300,
                          width: 2,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '100',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFFA500),
                              height: 1,
                            ),
                          ),
                          SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DH',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFFA500),
                                ),
                              ),
                              Text(
                                '/ mois',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // ── Avantages ───────────────────────────────────────────
                  _buildBenefit(
                    icon: Icons.all_inclusive,
                    title: 'Trajets illimités',
                    subtitle: 'Créez autant de circuits que vous voulez',
                  ),
                  const SizedBox(height: 16),
                  _buildBenefit(
                    icon: Icons.visibility,
                    title: 'Meilleure visibilité',
                    subtitle: 'Apparaissez en priorité dans les recherches',
                  ),
                  const SizedBox(height: 16),
                  _buildBenefit(
                    icon: Icons.support_agent,
                    title: 'Support prioritaire',
                    subtitle: 'Assistance dédiée 7j/7',
                  ),
                  const SizedBox(height: 16),
                  _buildBenefit(
                    icon: Icons.workspace_premium,
                    title: 'Badge Premium',
                    subtitle: 'Démarquez-vous avec le badge doré',
                  ),

                  const SizedBox(height: 32),

                  // ── Bouton CTA ──────────────────────────────────────────
                  if (!isCurrentlyPremium)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () => _upgradeToPremium(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFA500),
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: Colors.amber.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium, size: 24),
                            SizedBox(width: 12),
                            Text(
                              'S\'abonner maintenant',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Peut-être plus tard',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFFFA500), size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _upgradeToPremium(BuildContext context) async {
    // Afficher loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      ),
    );

    try {
      final response = await ApiService.upgradeToPremium();
      
      // Fermer loader
      Navigator.pop(context);
      
      // Fermer modal
      Navigator.pop(context, true); // Retourne true pour refresh

      // Afficher succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // Fermer loader
      Navigator.pop(context);
      
      // Afficher erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}