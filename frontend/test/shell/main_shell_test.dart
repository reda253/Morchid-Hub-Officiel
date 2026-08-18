import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/models/user_models.dart';
import 'package:morchid_hub/shell/main_shell.dart';

UserProfileResponse _profile(String role) => UserProfileResponse(
      user: UserData(
        id: 'u1',
        fullName: 'Reda Arroud',
        email: 'r@example.com',
        phone: '0612345678',
        role: role,
        isAdmin: false,
        isActive: true,
        isEmailVerified: true,
        createdAt: DateTime(2025, 1, 1),
      ),
    );

/// Cherche un libellé d'onglet **dans la barre de navigation** uniquement.
///
/// `find.text` seul ne suffit pas : `MainShell` utilise un `IndexedStack`, qui
/// construit toutes les destinations en même temps (c'est ce qui préserve leur
/// état hors écran). Le corps d'une destination peut donc afficher le même mot
/// que son onglet — c'est le cas des placeholders de la Tâche 8, et ce sera le
/// cas des vrais écrans. Restreindre la recherche à la barre exprime ce que le
/// test veut vraiment dire : « cet onglet est proposé ».
Finder tab(String label) => find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    );

void main() {
  testWidgets('tourist shell shows four tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(initialProfile: _profile('tourist')),
    ));
    await tester.pump();

    expect(tab('Explorer'), findsOneWidget);
    expect(tab('Recherche'), findsOneWidget);
    expect(tab('Voyages'), findsOneWidget);
    expect(tab('Profil'), findsOneWidget);
  });

  testWidgets('guide shell shows three tabs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(initialProfile: _profile('guide')),
    ));
    await tester.pump();

    expect(tab('Dashboard'), findsOneWidget);
    expect(tab('Agenda'), findsOneWidget);
    expect(tab('Profil'), findsOneWidget);
    expect(tab('Recherche'), findsNothing);
  });

  testWidgets('tapping a tab changes the selected index', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: MainShell(initialProfile: _profile('tourist')),
    ));
    await tester.pump();

    final bar = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(bar.currentIndex, 0);

    await tester.tap(tab('Voyages'));
    await tester.pump();

    final after = tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar));
    expect(after.currentIndex, 2);
  });
}
