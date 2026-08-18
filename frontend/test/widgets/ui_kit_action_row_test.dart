import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/widgets/ui_kit.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders title and subtitle', (tester) async {
    await tester.pumpWidget(wrap(ActionRow(
      icon: Icons.verified_outlined,
      title: 'Demander la certification',
      subtitle: 'Obtenez votre badge officiel',
      onTap: () {},
    )));

    expect(find.text('Demander la certification'), findsOneWidget);
    expect(find.text('Obtenez votre badge officiel'), findsOneWidget);
    expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
  });

  testWidgets('fires onTap when enabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(ActionRow(
      icon: Icons.route,
      title: 'Définir mon trajet',
      subtitle: 'Créez un itinéraire',
      onTap: () => tapped = true,
    )));

    await tester.tap(find.text('Définir mon trajet'));
    expect(tapped, isTrue);
  });

  testWidgets('does not fire onTap when disabled', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(ActionRow(
      icon: Icons.route,
      title: 'Définir mon trajet',
      subtitle: 'Créez un itinéraire',
      enabled: false,
      onTap: () => tapped = true,
    )));

    await tester.tap(find.text('Définir mon trajet'));
    expect(tapped, isFalse);
  });

  testWidgets('dims itself when disabled', (tester) async {
    await tester.pumpWidget(wrap(ActionRow(
      icon: Icons.route,
      title: 'Définir mon trajet',
      subtitle: 'Créez un itinéraire',
      enabled: false,
      onTap: () {},
    )));

    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, lessThan(1.0));
  });
}
