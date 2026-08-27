import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/screens/search_screen.dart';

void main() {
  testWidgets('disposes its search controller when torn down', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    final controller = tester.widget<TextField>(find.byType(TextField)).controller!;

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    // A disposed ChangeNotifier throws when used again. Without the
    // dispose() override in SearchScreen, this call succeeds and the test
    // fails.
    expect(() => controller.addListener(() {}), throwsFlutterError);
  });
}
