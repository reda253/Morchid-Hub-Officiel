import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/utils/app_colors.dart';
import 'package:morchid_hub/widgets/ui_kit.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('InfoCard renders its title and children', (tester) async {
    await tester.pumpWidget(wrap(const InfoCard(
      title: 'Informations personnelles',
      children: [Text('contenu')],
    )));

    expect(find.text('Informations personnelles'), findsOneWidget);
    expect(find.text('contenu'), findsOneWidget);
  });

  testWidgets('InfoRow renders icon, label and value', (tester) async {
    await tester.pumpWidget(wrap(const InfoRow(
      icon: Icons.email_outlined,
      label: 'Email',
      value: 'reda@example.com',
    )));

    expect(find.byIcon(Icons.email_outlined), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('reda@example.com'), findsOneWidget);
  });

  testWidgets('InfoRow honours valueColor', (tester) async {
    await tester.pumpWidget(wrap(const InfoRow(
      icon: Icons.verified,
      label: 'Statut',
      value: 'Vérifié',
      valueColor: AppColors.success,
    )));

    final text = tester.widget<Text>(find.text('Vérifié'));
    expect(text.style?.color, AppColors.success);
  });
}
