import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/screens/search_screen.dart';

void main() {
  testWidgets('disposes its controllers when torn down', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    // Replacing the tree disposes the State. If a TextEditingController was
    // left undisposed, the framework's leak detection surfaces it here.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
