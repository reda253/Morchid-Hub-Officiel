import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../widgets/ui_kit.dart';
import 'payment_screen.dart';

/// Écran « Grow Your Business » (design Stitch) — sélection de formule Premium.
/// Free / Pro (399) / Agency (999). Le choix d'un tier payant ouvre le paiement.
class PricingScreen extends StatelessWidget {
  const PricingScreen({Key? key}) : super(key: key);

  void _choose(BuildContext context, String plan, double amount) {
    if (amount <= 0) return; // Free : aucune action de paiement
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PaymentScreen(amount: amount, planName: plan)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Abonnements')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Développez votre activité de guide', style: AppTextStyles.headlineMd),
          const SizedBox(height: 8),
          Text(
            'Choisissez une formule à la hauteur de vos ambitions : plus de '
            'visibilité, plus d\'itinéraires, une hospitalité marocaine d\'exception.',
            style: AppTextStyles.bodyLg,
          ),
          const SizedBox(height: 24),
          PricingTierCard(
            name: 'Essentiel',
            price: 'Gratuit',
            features: const [
              'Jusqu\'à 3 trajets actifs / mois',
              'Visibilité standard',
              'Constructeur d\'itinéraire de base',
            ],
            ctaLabel: 'Formule actuelle',
            onTap: () => _choose(context, 'Essentiel', 0),
          ),
          const SizedBox(height: 16),
          PricingTierCard(
            name: 'Professionnel',
            price: '399',
            period: 'MAD / mois',
            highlighted: true,
            features: const [
              'Trajets actifs illimités',
              'Statut « En vedette » dans la recherche',
              'Analytics avancées',
              'Support prioritaire',
            ],
            ctaLabel: 'Passer au Pro',
            onTap: () => _choose(context, 'Professionnel', 399),
          ),
          const SizedBox(height: 16),
          PricingTierCard(
            name: 'Agence',
            price: '999',
            period: 'MAD / mois',
            features: const [
              'Toutes les fonctions Pro',
              'Plusieurs sous-comptes guides',
              'Rapports en marque blanche',
              'Account manager dédié',
            ],
            ctaLabel: 'Contacter les ventes',
            onTap: () => _choose(context, 'Agence', 999),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text('Tous les prix sont en dirham marocain (MAD).',
                style: AppTextStyles.bodySm),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
