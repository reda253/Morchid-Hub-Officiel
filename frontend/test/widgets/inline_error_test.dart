import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/widgets/inline_error.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders nothing when message is null', (tester) async {
    await tester.pumpWidget(wrap(const InlineError(message: null)));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders the message when present', (tester) async {
    await tester.pumpWidget(wrap(const InlineError(message: 'Email déjà utilisé')));
    expect(find.text('Email déjà utilisé'), findsOneWidget);
  });

  testWidgets('shows an error icon alongside the message', (tester) async {
    await tester.pumpWidget(wrap(const InlineError(message: 'Champ requis')));
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });
}
