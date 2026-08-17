import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morchid_hub/main.dart';

void main() {
  testWidgets('app boots to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MorchidHubApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
