import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/screens/trips_screen.dart';

void main() {
  testWidgets('shows the empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: TripsScreen(onNavigate: (_) {})));
    expect(find.text('Aucune réservation'), findsOneWidget);
  });

  testWidgets('CTA requests the Explorer tab rather than navigating itself',
      (tester) async {
    int? requested;
    await tester.pumpWidget(
        MaterialApp(home: TripsScreen(onNavigate: (i) => requested = i)));

    await tester.tap(find.text('Découvrir les guides'));
    expect(requested, 0);
  });
}
