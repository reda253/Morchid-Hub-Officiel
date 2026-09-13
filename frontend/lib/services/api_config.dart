import 'dart:io' as io;

/// Adresse de l'API backend, choisie au moment du build.
///
/// Build de démonstration :
///   flutter build apk --release --dart-define=API_BASE_URL=https://morchid-hub-api.onrender.com
///
/// Sans `--dart-define`, on garde le comportement de développement :
/// l'émulateur Android joint la machine hôte via 10.0.2.2, les autres
/// plateformes via 127.0.0.1.
class ApiConfig {
  ApiConfig._();

  static const String _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl =>
      resolveBaseUrl(override: _override, isAndroid: io.Platform.isAndroid);

  /// Fonction pure, testable sans plateforme. Retourne toujours une URL sans
  /// slash final : les écrans construisent `'$baseUrl/$chemin'`.
  static String resolveBaseUrl({
    required String override,
    required bool isAndroid,
  }) {
    final trimmed = override.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }
    return isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';
  }
}
