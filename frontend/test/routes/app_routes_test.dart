import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/routes/app_routes.dart';

void main() {
  test('route names are unique', () {
    const names = [
      AppRoutes.login,
      AppRoutes.signup,
      AppRoutes.forgotPassword,
      AppRoutes.emailVerification,
      AppRoutes.shell,
      AppRoutes.guideProfile,
      AppRoutes.review,
      AppRoutes.payment,
      AppRoutes.pricing,
      AppRoutes.map,
      AppRoutes.verifyGuide,
      AppRoutes.availableRoutes,
      AppRoutes.admin,
      AppRoutes.adminAnalytics,
      AppRoutes.search,
    ];
    expect(names.toSet().length, names.length);
  });

  test('every route name starts with a slash', () {
    expect(AppRoutes.shell.startsWith('/'), isTrue);
    expect(AppRoutes.guideProfile.startsWith('/'), isTrue);
  });

  test('MapArgs defaults to edit mode', () {
    expect(const MapArgs().mode, 'edit');
  });
}
