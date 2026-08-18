import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:morchid_hub/widgets/auth_guard.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('denied user sees an error state, not an endless spinner',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'user_data':
          '{"id":"u1","full_name":"T","email":"t@e.co","phone":"0612345678",'
          '"role":"tourist","is_active":true,"is_admin":false,'
          '"is_email_verified":true,"created_at":"2025-01-01T00:00:00.000"}',
    });

    await tester.pumpWidget(const MaterialApp(
      home: AuthGuard(allowedRoles: ['admin'], child: Text('secret')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('secret'), findsNothing);
    expect(find.text('Accès refusé'), findsOneWidget);
  });

  testWidgets('authorized user sees the child', (tester) async {
    SharedPreferences.setMockInitialValues({
      'is_logged_in': true,
      'user_data':
          '{"id":"u2","full_name":"A","email":"a@e.co","phone":"0612345678",'
          '"role":"admin","is_active":true,"is_admin":true,'
          '"is_email_verified":true,"created_at":"2025-01-01T00:00:00.000"}',
    });

    await tester.pumpWidget(const MaterialApp(
      home: AuthGuard(allowedRoles: ['admin'], child: Text('secret')),
    ));
    await tester.pumpAndSettle();

    expect(find.text('secret'), findsOneWidget);
  });
}
