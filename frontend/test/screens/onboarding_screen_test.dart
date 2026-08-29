import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/routes/app_routes.dart';
import 'package:morchid_hub/screens/onboarding_screen.dart';
import 'package:morchid_hub/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ce qui compte ici n'est pas l'esthétique : c'est qu'aucune sortie du
/// parcours ne laisse l'indicateur à faux — sinon la présentation se rejoue à
/// chaque ouverture — et que les deux sorties mènent au bon écran.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Enveloppe minimale : les routes cibles sont de simples marqueurs, on ne
  /// teste pas les écrans d'authentification ici.
  Widget harness() => MaterialApp(
        home: const OnboardingScreen(),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => Scaffold(body: Text('route:${settings.name}')),
        ),
      );

  testWidgets('ouvre sur la promesse, pas sur un formulaire', (tester) async {
    await tester.pumpWidget(harness());

    expect(find.text('Morchid Hub'), findsOneWidget);
    expect(find.text('Le Maroc, guidé autrement'), findsOneWidget);
    expect(find.text('Suivant'), findsOneWidget);
    expect(find.text('Créer un compte'), findsNothing);
  });

  testWidgets('« Suivant » avance page par page jusqu\'à l\'appel à l\'action',
      (tester) async {
    await tester.pumpWidget(harness());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Suivant'), findsNothing);
    expect(find.text('Créer un compte'), findsOneWidget);
    expect(find.text('J\'ai déjà un compte'), findsOneWidget);
    // Plus rien à passer une fois au bout.
    expect(find.text('Passer'), findsNothing);
  });

  testWidgets('chaque page montre un fragment réel de l\'app', (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('VÉRIFIÉ'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('Des itinéraires tracés\nsur la carte'), findsOneWidget);

    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    expect(find.text('ÉCO-SCORE'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
  });

  testWidgets('« Passer » marque la présentation vue et va à la connexion',
      (tester) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text('Passer'));
    await tester.pumpAndSettle();

    expect(await StorageService.hasSeenOnboarding(), isTrue);
    expect(find.text('route:${AppRoutes.login}'), findsOneWidget);
  });

  testWidgets('« Créer un compte » marque la présentation vue et va à l\'inscription',
      (tester) async {
    await tester.pumpWidget(harness());

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Créer un compte'));
    await tester.pumpAndSettle();

    expect(await StorageService.hasSeenOnboarding(), isTrue);
    expect(find.text('route:${AppRoutes.signup}'), findsOneWidget);
  });

  testWidgets('tient sur un petit écran et à grande taille de texte',
      (tester) async {
    // Le paragraphe de la page 3 débordait de 10 px avant que le contenu ne
    // devienne défilable ; un petit téléphone ou un `textScaleFactor` relevé
    // coupait le bas du texte, soit exactement ce qu'il ne faut pas perdre.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: OnboardingScreen(),
      ),
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (_) => Scaffold(body: Text('route:${settings.name}')),
      ),
    ));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'débordement page $i');
    }
  });

  testWidgets('l\'indicateur survit à une déconnexion', (tester) async {
    // La présentation appartient à l'appareil, pas au compte : la rejouer
    // après chaque déconnexion serait une régression silencieuse.
    await StorageService.markOnboardingSeen();
    await StorageService.logout();

    expect(await StorageService.hasSeenOnboarding(), isTrue);
  });
}
