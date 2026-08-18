import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../services/api_service.dart';
import '../utils/app_colors.dart';
import '../widgets/error_state.dart';
import '../routes/app_routes.dart';
import 'shell_destinations.dart';

/// Coquille applicative : propriétaire unique du profil utilisateur et de
/// l'onglet sélectionné.
///
/// Ne construit aucune carte, aucun avatar, aucune AppBar — chaque destination
/// fournit la sienne.
///
/// [initialProfile] n'existe que pour les tests : il court-circuite l'appel
/// réseau au montage.
class MainShell extends StatefulWidget {
  final UserProfileResponse? initialProfile;
  const MainShell({Key? key, this.initialProfile}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  UserProfileResponse? _profile;
  ApiError? _error;
  bool _isLoading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await ApiService.getUserProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  void _navigateTo(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final error = _error;
    if (error != null) {
      return Scaffold(
        body: ErrorState.fromApiError(
          error,
          onRetry: _loadProfile,
          onReauth: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false),
        ),
      );
    }

    final profile = _profile!;
    final destinations = destinationsForRole(profile.user.role);
    final index = _currentIndex.clamp(0, destinations.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (final d in destinations) d.builder(profile, _navigateTo),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: _navigateTo,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textLight,
        items: [
          for (final d in destinations)
            BottomNavigationBarItem(
              icon: Icon(d.icon),
              activeIcon: Icon(d.activeIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
