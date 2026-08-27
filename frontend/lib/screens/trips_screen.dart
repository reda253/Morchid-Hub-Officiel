import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Onglet « Voyages » du touriste.
///
/// Extrait de `_buildReservations` (home_screen.dart:1096-1161). Aucun
/// endpoint de réservation côté backend — cet écran affiche un état vide
/// honnête ; il ne fabrique pas de fausses réservations.
class TripsScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const TripsScreen({Key? key, required this.onNavigate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes voyages')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  size: 64,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text('Aucune réservation', style: AppTextStyles.headlineMd),
              const SizedBox(height: 12),
              Text(
                'Vous n\'avez aucune réservation en cours.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySm,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => onNavigate(0),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Découvrir les guides'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
