import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/widgets/motion.dart';

/// Deux invariants comptent ici, et aucun n'est esthétique :
///
///   • un élément désactivé ne doit ni réagir au doigt ni s'animer ;
///   • « Réduire les animations » du système doit être respecté.
void main() {
  Widget wrap(Widget child, {bool disableAnimations = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  group('Pressable', () {
    testWidgets('déclenche onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(wrap(Pressable(
        onTap: () => tapped = true,
        child: const SizedBox(width: 120, height: 48),
      )));

      await tester.tap(find.byType(Pressable));
      expect(tapped, isTrue);
    });

    testWidgets('s\'enfonce pendant l\'appui puis revient', (tester) async {
      await tester.pumpWidget(wrap(Pressable(
        onTap: () {},
        child: const SizedBox(width: 120, height: 48),
      )));

      double scale() => tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(scale(), lessThan(1.0));

      await gesture.up();
      await tester.pumpAndSettle();
      expect(scale(), 1.0);
    });

    testWidgets('reste inerte sans onTap', (tester) async {
      await tester.pumpWidget(wrap(const Pressable(
        child: SizedBox(width: 120, height: 48),
      )));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
      await gesture.up();
    });

    testWidgets('ne s\'enfonce pas si les animations sont réduites', (tester) async {
      await tester.pumpWidget(wrap(
        Pressable(onTap: () {}, child: const SizedBox(width: 120, height: 48)),
        disableAnimations: true,
      ));

      final gesture = await tester.startGesture(tester.getCenter(find.byType(Pressable)));
      await tester.pump();
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1.0);
      await gesture.up();
    });
  });

  group('FadeSlideIn', () {
    testWidgets('finit pleinement visible', (tester) async {
      await tester.pumpWidget(wrap(const FadeSlideIn(index: 2, child: Text('Bonjour'))));
      await tester.pumpAndSettle();

      final opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1.0);
      expect(find.text('Bonjour'), findsOneWidget);
    });

    testWidgets('n\'anime rien si les animations sont réduites', (tester) async {
      await tester.pumpWidget(wrap(
        const FadeSlideIn(index: 3, child: Text('Bonjour')),
        disableAnimations: true,
      ));
      await tester.pump();

      // Aucune enveloppe d'animation : le texte est là dès la première frame.
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('Bonjour'), findsOneWidget);
    });
  });
}
