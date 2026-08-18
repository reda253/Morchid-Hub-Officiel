import 'package:flutter/material.dart';

import '../models/user_models.dart';
import '../screens/agenda_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/guide_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/trips_screen.dart';
import '../theme/app_text_styles.dart';

/// Une destination de la barre de navigation basse.
///
/// [builder] reçoit `onNavigate` pour qu'une destination puisse *demander* un
/// changement d'onglet sans posséder l'index — `MainShell` en reste le seul
/// propriétaire.
class ShellDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Widget Function(UserProfileResponse profile, void Function(int) onNavigate) builder;

  const ShellDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.builder,
  });
}

Widget _placeholder(String name) =>
    Center(child: Text(name, style: AppTextStyles.titleMd));

final List<ShellDestination> _touristDestinations = [
  ShellDestination(
    icon: Icons.explore_outlined,
    activeIcon: Icons.explore,
    label: 'Explorer',
    builder: (profile, onNavigate) =>
        ExploreScreen(profile: profile, onNavigate: onNavigate),
  ),
  ShellDestination(
    icon: Icons.search_outlined,
    activeIcon: Icons.search,
    label: 'Recherche',
    builder: (profile, onNavigate) => _placeholder('Recherche'),
  ),
  ShellDestination(
    icon: Icons.luggage_outlined,
    activeIcon: Icons.luggage,
    label: 'Voyages',
    builder: (profile, onNavigate) => TripsScreen(onNavigate: onNavigate),
  ),
  ShellDestination(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profil',
    builder: (profile, onNavigate) =>
        ProfileScreen(profile: profile, onNavigate: onNavigate),
  ),
];

final List<ShellDestination> _guideDestinations = [
  ShellDestination(
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    label: 'Dashboard',
    builder: (profile, onNavigate) =>
        GuideDashboardScreen(profile: profile, onNavigate: onNavigate),
  ),
  ShellDestination(
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    label: 'Agenda',
    builder: (profile, onNavigate) =>
        AgendaScreen(profile: profile, onNavigate: onNavigate),
  ),
  ShellDestination(
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    label: 'Profil',
    builder: (profile, onNavigate) =>
        ProfileScreen(profile: profile, onNavigate: onNavigate),
  ),
];

/// Résout la liste d'onglets pour un rôle. Tout rôle inconnu retombe sur le
/// jeu touriste — un utilisateur ne doit jamais se retrouver sans navigation.
List<ShellDestination> destinationsForRole(String role) {
  switch (role) {
    case 'guide':
      return _guideDestinations;
    case 'tourist':
    default:
      return _touristDestinations;
  }
}
