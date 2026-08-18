import 'package:flutter/material.dart';
import '../services/storage_service.dart'; // Requires your storage service
import '../routes/app_routes.dart';
import 'error_state.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  final List<String>? allowedRoles;

  const AuthGuard({
    Key? key,
    required this.child,
    this.allowedRoles,
  }) : super(key: key);

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;

    if (!isLoggedIn) {
      _redirectToLogin();
      return;
    }

    final userData = await StorageService.getUserData();
    if (!mounted) return;

    final roles = widget.allowedRoles;
    final authorized = roles == null ||
        (userData != null &&
            (roles.contains(userData.role) || userData.isAdmin == true));

    setState(() {
      _isAuthorized = authorized;
      _isLoading = false;
    });
  }

  void _redirectToLogin() {
    // Le SnackBar doit partir AVANT la navigation : pushNamedAndRemoveUntil
    // démonte ce contexte, et ScaffoldMessenger.of(context) échouerait après.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez vous connecter')),
    );
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_isAuthorized) return widget.child;

    return Scaffold(
      body: ErrorState(
        icon: Icons.block,
        title: 'Accès refusé',
        message: 'Vous n\'avez pas les droits nécessaires pour cette page.',
        onRetry: () => Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.shell, (route) => false),
        retryLabel: 'Retour à l\'accueil',
      ),
    );
  }
}
