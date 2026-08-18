import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Onglet « Agenda » du guide.
///
/// Extrait de `_buildGuideAgenda` (home_screen.dart:1162-1205) — état vide
/// statique, aucune donnée de réservation à charger (même constat que
/// TripsScreen côté touriste).
class AgendaScreen extends StatelessWidget {
  final UserProfileResponse profile;
  final void Function(int) onNavigate;
  const AgendaScreen({Key? key, required this.profile, required this.onNavigate})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.event_available_outlined,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Agenda vide',
                  style: AppTextStyles.headlineMd.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Vous n\'avez aucune réservation planifiée.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLg.copyWith(color: AppColors.textLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
