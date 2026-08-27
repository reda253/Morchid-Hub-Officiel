import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morchid_hub/models/user_models.dart';
import 'package:morchid_hub/widgets/error_state.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows title, message and retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(wrap(ErrorState(
      title: 'Connexion perdue',
      message: 'Vérifiez votre connexion internet.',
      onRetry: () => retried = true,
    )));

    expect(find.text('Connexion perdue'), findsOneWidget);
    expect(find.text('Vérifiez votre connexion internet.'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    expect(retried, isTrue);
  });

  testWidgets('omits the retry button when onRetry is null', (tester) async {
    await tester.pumpWidget(wrap(const ErrorState(
      title: 'Accès refusé',
      message: 'Vous n\'avez pas les droits.',
    )));
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('NOT_FOUND renders as an empty state with no retry', (tester) async {
    await tester.pumpWidget(wrap(ErrorState.fromApiError(
      ApiError(errorCode: 'NOT_FOUND', message: 'Aucun guide trouvé'),
      onRetry: () {},
    )));

    expect(find.text('Aucun guide trouvé'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
  });

  testWidgets('UNAUTHORIZED offers reconnection', (tester) async {
    var reauthed = false;
    await tester.pumpWidget(wrap(ErrorState.fromApiError(
      ApiError(errorCode: 'UNAUTHORIZED', message: 'Session expirée'),
      onReauth: () => reauthed = true,
    )));

    await tester.tap(find.text('Se reconnecter'));
    expect(reauthed, isTrue);
  });

  testWidgets('unknown codes fall back to a retryable generic state', (tester) async {
    await tester.pumpWidget(wrap(ErrorState.fromApiError(
      ApiError(errorCode: 'WEIRD_NEW_CODE', message: 'Boom'),
      onRetry: () {},
    )));

    expect(find.text('Réessayer'), findsOneWidget);
  });
}
