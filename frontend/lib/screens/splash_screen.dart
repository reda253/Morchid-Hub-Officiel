import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import '../services/storage_service.dart';
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

  Future<void> _decide() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      loggedIn ? AppRoutes.shell : AppRoutes.login,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: AppLogo(size: 48)),
    );
  }
}
