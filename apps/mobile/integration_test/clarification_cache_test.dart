import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/gemini_request_client.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';

/// Disposable .maptest emulator only. All answers are explicitly synthetic.
/// No credential is provisioned, and all client calls are saved-only.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native answer namespace preserves base understanding and pending state',
    (tester) async {
      const channel = MethodChannel('wayday/planning');
      final identity = await channel.invokeMapMethod<String, String>(
        'identity',
      );
      expect(identity!['package'], endsWith('.maptest'));
      expect(
        (await channel.invokeMapMethod<String, dynamic>(
          'geminiStatus',
        ))!['configured'],
        isFalse,
      );
      expect(
        await channel.invokeMethod<bool>('checkInterpretationJournal'),
        isTrue,
      );
      const e = Errand(id: 'a', title: 'Synthetic groceries');
      final c = ClarificationContext.create(
        e,
        const ErrandNeed(
          id: 'a',
          query: 'grocery store',
          category: 'grocery',
          question: 'What items?',
        ),
        const [e],
      );
      final base = legacyInterpretationRequest(DayPlan(errands: const [e]));
      final response = jsonEncode({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'id': 'a',
                    ...const ClarificationResolution(
                      outcome: 'flexible',
                      kind: 'preference',
                      summary: 'Synthetic general groceries',
                      query: 'grocery store',
                    ).toJson(),
                  }),
                },
              ],
            },
          },
        ],
      });
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': base,
        'state': 'completed',
        'response': 'synthetic base cache',
      });
      for (var i = 0; i < 34; i++) {
        await channel.invokeMethod<void>('seedInterpretationFixture', {
          'body': clarificationRequest(c, 'Synthetic answer $i', []),
          'purpose': 'clarification',
          'state': 'completed',
          'response': response,
        });
      }
      final baseStatus = await channel.invokeMapMethod<String, dynamic>(
        'interpretationStatus',
        {'body': base},
      );
      expect(baseStatus!['response'], 'synthetic base cache');
      final resolver = GeminiClarificationResolver(
        client: GeminiRequestClient(channel: channel),
      );
      expect(
        (await resolver.resolve(
          c,
          'Synthetic answer 33',
          savedOnly: true,
        )).summary,
        'Synthetic general groceries',
      );
      final pending = clarificationRequest(c, 'Synthetic pending answer', []);
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': pending,
        'purpose': 'clarification',
        'state': 'pending',
      });
      await expectLater(
        resolver.resolve(c, 'Synthetic pending answer', savedOnly: true),
        throwsA(isA<PlanningFailure>()),
      );
      final status = await channel.invokeMapMethod<String, dynamic>(
        'interpretationStatus',
        {'body': pending, 'purpose': 'clarification'},
      );
      expect(status!['state'], 'pending');
    },
  );
}
