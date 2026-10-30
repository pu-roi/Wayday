import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/gemini_request_client.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wayday/clarification-fixture');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final context = ClarificationContext.create(
    const Errand(id: 'a', title: 'Groceries'),
    const ErrandNeed(
      id: 'a',
      query: 'grocery store',
      category: 'grocery',
      question: 'What items?',
    ),
    const [Errand(id: 'a', title: 'Groceries')],
  );
  late Map<String, String> disk;
  late int generations;
  Completer<void>? wait;
  setUp(() {
    disk = {};
    generations = 0;
    wait = null;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'geminiStatus') return {'configured': true};
      final args = Map<String, dynamic>.from(call.arguments as Map);
      final key = '${args['purpose']}:${args['body']}';
      if (call.method == 'interpretationStatus') {
        return disk.containsKey(key)
            ? {'state': 'completed', 'response': disk[key]}
            : {'state': 'missing'};
      }
      if (call.method == 'interpret') {
        generations++;
        await wait?.future;
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
                        summary:
                            'General groceries · Choose items at the store',
                        query: 'grocery store',
                      ).toJson(),
                    }),
                  },
                ],
              },
            },
          ],
        });
        disk[key] = response;
        return response;
      }
      throw StateError('Unexpected method ${call.method}');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  test(
    'answer namespace, duplicate coalescing, restart hit and changed-answer miss',
    () async {
      final client = GeminiRequestClient(channel: channel),
          resolver = GeminiClarificationResolver(
            client: GeminiRequestClient(channel: channel),
          );
      wait = Completer<void>();
      final first = resolver.resolve(context, 'Not sure'),
          same = resolver.resolve(context, 'Not sure');
      await Future<void>.delayed(Duration.zero);
      expect(generations, 1);
      wait!.complete();
      await Future.wait([first, same]);
      wait = null;
      expect(disk.keys.single, startsWith('clarification:'));
      final restarted = GeminiClarificationResolver(client: client);
      expect(
        (await restarted.resolve(context, 'Not sure', savedOnly: true)).outcome,
        'flexible',
      );
      expect(generations, 1);
      await restarted.resolve(context, 'Rice and soy sauce');
      expect(generations, 2);
      // An interpretation entry cannot satisfy a clarification lookup.
      final body = clarificationRequest(context, 'Another answer', []);
      disk['interpretation:$body'] = disk.values.first;
      await expectLater(
        restarted.resolve(context, 'Another answer', savedOnly: true),
        throwsA(isA<PlanningFailure>()),
      );
      expect(generations, 2);
    },
  );
}
