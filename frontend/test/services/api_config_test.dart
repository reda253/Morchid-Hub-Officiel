import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/services/api_config.dart';

void main() {
  group('resolveBaseUrl', () {
    test('sans override, émulateur Android → 10.0.2.2', () {
      expect(
        ApiConfig.resolveBaseUrl(override: '', isAndroid: true),
        'http://10.0.2.2:8000',
      );
    });

    test('sans override, autre plateforme → 127.0.0.1', () {
      expect(
        ApiConfig.resolveBaseUrl(override: '', isAndroid: false),
        'http://127.0.0.1:8000',
      );
    });

    test('override prioritaire sur la plateforme', () {
      expect(
        ApiConfig.resolveBaseUrl(
          override: 'https://morchid-hub-api.onrender.com',
          isAndroid: true,
        ),
        'https://morchid-hub-api.onrender.com',
      );
    });

    test('slash final retiré (les écrans concatènent "\$baseUrl/\$chemin")', () {
      expect(
        ApiConfig.resolveBaseUrl(
          override: 'https://morchid-hub-api.onrender.com/',
          isAndroid: false,
        ),
        'https://morchid-hub-api.onrender.com',
      );
    });

    test('override fait uniquement d\'espaces → ignoré', () {
      expect(
        ApiConfig.resolveBaseUrl(override: '   ', isAndroid: false),
        'http://127.0.0.1:8000',
      );
    });
  });
}
