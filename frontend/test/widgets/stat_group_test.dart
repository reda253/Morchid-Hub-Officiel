import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/widgets/stat_tile.dart';

/// Le panneau groupé remplace une grille dont la hauteur dérivait d'un
/// `childAspectRatio` — donc de la largeur de l'écran. Ces tests fixent
/// l'inverse : la hauteur ne dépend plus de la largeur, et rien ne déborde
/// sur un petit écran.
void main() {
  const cells = [
    StatCell(label: 'Réservations', value: '12'),
    StatCell(label: 'Éco-score', value: '84'),
    StatCell(label: 'Note moyenne', value: '4.8', unit: '/5'),
    StatCell(label: 'Revenus', value: '320', unit: 'DH'),
  ];

  Future<void> pumpAt(WidgetTester tester, double width) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: const StatGroup(cells: cells),
          ),
        ),
      ),
    ));
  }

  testWidgets('affiche chaque label et chaque valeur', (tester) async {
    await pumpAt(tester, 360);

    for (final cell in cells) {
      expect(find.text(cell.label.toUpperCase()), findsOneWidget);
      expect(find.text(cell.value), findsOneWidget);
    }
    expect(find.text('/5'), findsOneWidget);
    expect(find.text('DH'), findsOneWidget);
  });

  testWidgets('tient sans débordement de 320 à 600 px', (tester) async {
    for (final width in <double>[320, 360, 420, 600]) {
      await pumpAt(tester, width);
      expect(tester.takeException(), isNull, reason: 'débordement à $width px');
    }
  });

  testWidgets('garde la même hauteur quelle que soit la largeur', (tester) async {
    await pumpAt(tester, 320);
    final narrow = tester.getSize(find.byType(StatGroup)).height;

    await pumpAt(tester, 600);
    final wide = tester.getSize(find.byType(StatGroup)).height;

    // C'était le défaut de la grille : à largeur double, tuiles deux fois plus
    // hautes, donc du vide sous chaque chiffre.
    expect(wide, narrow);
  });

  testWidgets('une seule carte, pas une bordure par cellule', (tester) async {
    await pumpAt(tester, 360);

    // Quatre cellules séparées par des filets : 1 horizontal + 2 verticaux.
    expect(find.byType(Divider), findsOneWidget);
    expect(find.byType(VerticalDivider), findsNWidgets(2));
  });

  testWidgets('remplit la dernière rangée quand le compte est impair', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StatGroup(cells: [
          StatCell(label: 'Un', value: '1'),
          StatCell(label: 'Deux', value: '2'),
          StatCell(label: 'Trois', value: '3'),
        ]),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('3'), findsOneWidget);
  });
}
