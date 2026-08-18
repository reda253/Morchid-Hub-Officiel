import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Présentation plein écran d'un échec de chargement.
///
/// Un état d'erreur sans action est un cul-de-sac : fournir [onRetry] dès que
/// l'opération est rejouable. `NOT_FOUND` est délibérément rendu comme un état
/// vide, pas comme une erreur — « aucun résultat » n'est pas un échec.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final String retryLabel;

  const ErrorState({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.onRetry,
    this.retryLabel = 'Réessayer',
  }) : super(key: key);

  factory ErrorState.fromApiError(
    ApiError error, {
    VoidCallback? onRetry,
    VoidCallback? onReauth,
  }) {
    switch (error.errorCode) {
      case 'NOT_FOUND':
        return ErrorState(
          icon: Icons.search_off,
          title: 'Aucun résultat',
          message: error.message,
        );
      case 'UNAUTHORIZED':
        return ErrorState(
          icon: Icons.lock_outline,
          title: 'Session expirée',
          message: error.message,
          onRetry: onReauth,
          retryLabel: 'Se reconnecter',
        );
      case 'FORBIDDEN':
        return ErrorState(
          icon: Icons.block,
          title: 'Accès refusé',
          message: error.message,
        );
      case 'SERVICE_UNAVAILABLE':
      case 'NETWORK_ERROR':
        return ErrorState(
          icon: Icons.wifi_off,
          title: 'Connexion perdue',
          message: error.message,
          onRetry: onRetry,
        );
      default:
        return ErrorState(
          icon: Icons.error_outline,
          title: 'Une erreur est survenue',
          message: error.message,
          onRetry: onRetry,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTextStyles.headlineMd, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodySm,
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
