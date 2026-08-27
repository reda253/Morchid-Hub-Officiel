import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/utils/app_colors.dart';
import 'package:morchid_hub/widgets/ui_kit.dart';

/// La marque est peinte, pas chargée depuis un asset : ces tests vérifient
/// qu'elle se rend à toutes les tailles utilisées dans l'app et que le
/// bloc-marque suit l'échelle du symbole.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );

  testWidgets('rend le symbole seul sans bloc-marque', (tester) async {
    await pump(tester, const AppLogo(size: 92, showWordmark: false));

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.textContaining('Morchid'), findsNothing);
  });

  testWidgets('rend le bloc-marque en deux poids', (tester) async {
    await pump(tester, const AppLogo(size: 40));

    // Text.rich : « Morchid » puis « Hub » dans le même RichText.
    final text = tester.widget<RichText>(find.byType(RichText).first);
    expect(text.text.toPlainText(), 'Morchid Hub');
  });

  testWidgets('se peint aux tailles réellement utilisées', (tester) async {
    // 16 : sous le seuil de détail — étoile pleine.
    // 26 : valeur par défaut. 54 : en-tête auth. 92 : splash.
    for (final size in <double>[16, 26, 54, 92]) {
      await pump(tester, AppLogo(size: size, showWordmark: false));
      expect(tester.takeException(), isNull, reason: 'échec à $size px');
    }
  });

  testWidgets('la version monochrome accepte une couleur de réserve', (tester) async {
    await pump(
      tester,
      const AppLogo(
        size: 54,
        showWordmark: false,
        color: AppColors.onPrimary,
        monochrome: true,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
