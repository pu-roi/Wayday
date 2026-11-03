import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/understanding_failure_view.dart';

void main() {
  for (final entry in {
    'gateway_contract': 'Wayday service needs an update',
    'request_rejected': 'Understanding request was not accepted',
  }.entries) {
    testWidgets('${entry.key} has an accurate heading and explicit recovery', (
      tester,
    ) async {
      var saved = 0;
      var retry = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: UnderstandingFailureView(
              failure: PlanningFailure(
                'Your errands are kept.',
                kind: entry.key,
              ),
              onSaved: () => saved++,
              onRetry: () => retry++,
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('Gemini rejected the request'), findsNothing);
      expect(retry, 0);
      await tester.tap(find.text('Check saved understanding'));
      expect(saved, 1);
      expect(retry, 0);
      await tester.tap(find.text('Retry Gemini'));
      expect(retry, 1);
    });
  }
}
