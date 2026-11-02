import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/features/planning/data/gemini_request_client.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';

/// Native journal fixtures only. Never dispatch or provision a provider key.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'fresh run journals stay separate and recover without generation',
    (tester) async {
      const channel = MethodChannel('wayday/planning');
      final identity = await channel.invokeMapMethod<String, String>(
        'identity',
      );
      expect(identity!['package'], endsWith('.maptest'));
      final body = interpretationRequest(
        DayPlan(
          errands: const [Errand(id: 'synthetic-fresh', title: 'Laundry')],
        ),
      );
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': body,
        'state': 'completed',
        'response': 'synthetic baseline',
      });
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': body,
        'runId': 'synthetic-run-a',
        'state': 'completed',
        'response': 'synthetic replacement',
      });
      final client = GeminiRequestClient(channel: channel);
      expect(
        (await client.request(body, savedOnly: true)).raw,
        'synthetic baseline',
      );
      expect(
        (await client.request(
          body,
          runId: 'synthetic-run-a',
          savedOnly: true,
        )).raw,
        'synthetic replacement',
      );
      await expectLater(
        client.request(body, runId: 'synthetic-run-b', savedOnly: true),
        throwsA(isA<PlanningFailure>()),
      );
      await client.invalidate(body, 'interpretation', runId: 'synthetic-run-a');
      expect(
        (await client.request(body, savedOnly: true)).raw,
        'synthetic baseline',
      );
      await expectLater(
        client.request(body, runId: 'synthetic-run-a', savedOnly: true),
        throwsA(isA<PlanningFailure>()),
      );
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': body,
        'runId': 'synthetic-run-pending',
        'state': 'pending',
      });
      await expectLater(
        client.request(body, runId: 'synthetic-run-pending', savedOnly: true),
        throwsA(isA<PlanningFailure>()),
      );
    },
  );
}
