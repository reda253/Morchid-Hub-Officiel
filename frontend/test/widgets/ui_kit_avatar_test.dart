import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/widgets/ui_kit.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('DefaultAvatar shows two initials for a two-part name', (tester) async {
    await tester.pumpWidget(wrap(const DefaultAvatar(fullName: 'Reda Arroud')));
    expect(find.text('RA'), findsOneWidget);
  });

  testWidgets('DefaultAvatar shows one initial for a single name', (tester) async {
    await tester.pumpWidget(wrap(const DefaultAvatar(fullName: 'Reda')));
    expect(find.text('R'), findsOneWidget);
  });

  testWidgets('DefaultAvatar falls back to ? for an empty name', (tester) async {
    await tester.pumpWidget(wrap(const DefaultAvatar(fullName: '')));
    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('ActionButton fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(wrap(ActionButton(
      icon: Icons.add,
      label: 'Créer',
      onTap: () => tapped = true,
    )));

    await tester.tap(find.text('Créer'));
    expect(tapped, isTrue);
  });
}
