/// Noms de routes et arguments typés.
///
/// Règle unique : toute transition d'écran passe par une route nommée. Les
/// arguments passent par ces classes, jamais par `Map<String, dynamic>`.
///
/// Note : les valeurs des constantes reprennent les chaînes déjà en
/// production dans `main.dart` (`onGenerateRoute`) — aucune n'est renommée
/// ici, pour éviter qu'un site d'appel oublié échoue silencieusement à
/// résoudre sa route (repli sur `default:` → `LoginScreen`).
class AppRoutes {
  AppRoutes._();

  /// Route initiale de l'application. `SplashScreen` la consomme pour décider
  /// entre [login] et [shell] selon la session enregistrée.
  static const String splash = '/';

  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';
  static const String shell = '/shell';
  static const String guideProfile = '/guide-profile';
  static const String review = '/review';
  static const String payment = '/payment';
  static const String pricing = '/pricing';
  static const String map = '/map';
  static const String verifyGuide = '/verify-guide';
  // Valeur inchangée : la route vivante est '/available_routes_screen', pas
  // '/available-routes'. Voir la note ci-dessus.
  static const String availableRoutes = '/available_routes_screen';
  static const String admin = '/admin';
  static const String adminAnalytics = '/admin/analytics';

  // Route additionnelle, absente de la liste du plan initial mais requise
  // pour que chaque transition d'écran (y compris vers SearchScreen) passe
  // par une route nommée — voir le rapport de la tâche 16.
  static const String search = '/search';
}

class GuideProfileArgs {
  final dynamic guide;
  const GuideProfileArgs({required this.guide});
}

class ReviewArgs {
  final String guideId;
  final String guideName;
  final String? guidePhotoUrl;
  const ReviewArgs({
    required this.guideId,
    required this.guideName,
    this.guidePhotoUrl,
  });
}

class PaymentArgs {
  final double amount;
  final String planName;
  const PaymentArgs({required this.amount, required this.planName});
}

class MapArgs {
  final String mode;
  final dynamic savedRoute;
  const MapArgs({this.mode = 'edit', this.savedRoute});
}

class EmailVerificationArgs {
  final String email;
  final String fullName;
  const EmailVerificationArgs({required this.email, required this.fullName});
}
