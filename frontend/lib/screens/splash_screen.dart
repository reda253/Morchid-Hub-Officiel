import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/storage_service.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';
import '../widgets/ui_kit.dart';

/// Écran de démarrage : décide de la destination initiale selon la session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  /// La présentation passe avant la session : quelqu'un qui n'a jamais vu
  /// l'application ne doit pas atterrir sur un formulaire de connexion sans
  /// savoir à quoi il se connecte. Une fois vue, elle ne revient jamais — pas
  /// même après une déconnexion, l'indicateur n'étant pas lié au compte.
  Future<void> _decide() async {
    if (!await StorageService.hasSeenOnboarding()) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }

    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      loggedIn ? AppRoutes.shell : AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fond Atlantic Blue : le premier écran de l'app est la couleur de la
      // marque, pas une page blanche. La marque y passe en réserve blanche.
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // `Hero` avec le même tag que l'en-tête d'authentification : le
            // symbole se déplace du splash vers l'écran de connexion au lieu
            // de disparaître puis réapparaître.
            const Hero(
              tag: 'app_logo',
              child: AppLogo(
                size: 92,
                showWordmark: false,
                color: AppColors.onPrimary,
                monochrome: true,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Morchid Hub',
              style: AppTextStyles.displayMd.copyWith(
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Le Maroc, guidé autrement',
              style: AppTextStyles.bodySm.copyWith(color: AppColors.sand),
            ),
          ],
        ),
      ),
    );
  }
}
