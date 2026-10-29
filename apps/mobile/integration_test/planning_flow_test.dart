import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import '../test/helpers/planning_fixtures.dart';

/// Run with tool/test-map.ps1 to isolate package/database from the owner's app.
/// This exercises Android rendering/native identity; fixture services make no
/// Gemini generation, Routes or navigation-destination requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android planning review, native identity and local accepted progress',
    (tester) async {
      const channel = MethodChannel('wayday/planning');
      expect(
        await channel.invokeMethod<bool>('checkInterpretationJournal'),
        isTrue,
      );
      debugPrint('WAYDAY_DURABLE_INTERPRETATION_JOURNAL_PASSED');
      final cachedDay = DayPlan(
        errands: const [
          Errand(id: 'native-cache-fixture', title: 'Grocery fixture'),
        ],
      );
      final cachedBody = interpretationRequest(cachedDay);
      final response = jsonEncode({
        'candidates': [
          {
            'finishReason': 'STOP',
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'needs': [
                      {
                        'id': 'native-cache-fixture',
                        'query': 'grocery',
                        'category': 'grocery',
                        'items': ['rice'],
                        'durationMinutes': 20,
                        'after': <String>[],
                        'question': null,
                        'title': null,
                        'optional': null,
                        'timing': null,
                        'minute': null,
                      },
                    ],
                    'additions': <Object>[],
                  }),
                },
              ],
            },
          },
        ],
      });
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': cachedBody,
        'state': 'completed',
        'response': response,
      });
      var reservations = 0;
      final cacheBudget = PlanningBudget(
        read: () async => null,
        write: (_) async {
          reservations++;
        },
      );
      final cachedAnswer = await GeminiInterpreter(
        cacheBudget,
      ).interpret(cachedDay);
      expect(cachedAnswer.needs.single.id, 'native-cache-fixture');
      expect(reservations, 0);
      final pendingDay = DayPlan(
        errands: const [
          Errand(id: 'native-pending-fixture', title: 'Pending fixture'),
        ],
      );
      await channel.invokeMethod<void>('seedInterpretationFixture', {
        'body': interpretationRequest(pendingDay),
        'state': 'pending',
      });
      await expectLater(
        GeminiInterpreter(cacheBudget).interpret(pendingDay),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'interrupted'),
        ),
      );
      expect(reservations, 0);
      debugPrint(
        'WAYDAY_NATIVE_CACHE_REUSE_AND_INTERRUPTED_GUARD_PASSED generations=0',
      );
      final identity = await channel.invokeMapMethod<String, String>(
        'identity',
      );
      expect(identity?['package'], 'dev.wayday.wayday.maptest');
      expect(identity?['certificate'], matches(RegExp(r'^[A-F0-9]{40}$')));
      final configuration = await channel.invokeMapMethod<String, dynamic>(
        'geminiStatus',
      );
      expect(configuration?['configured'], isA<bool>());
      if (configuration?['configured'] == true &&
          configuration?['remainingGenerations'] == 0) {
        await expectLater(
          channel.invokeMethod<String>('interpret', {
            'body': '{"generationConfig":{"maxOutputTokens":1}}',
          }),
          throwsA(
            isA<PlatformException>().having(
              (e) => e.code,
              'code',
              'paid_allowance',
            ),
          ),
        );
        debugPrint('WAYDAY_NATIVE_PAID_GENERATION_GUARD_PASSED');
      }
      // Never print identity, key, notes, coordinates, provider records or response bodies.
      final roads = Roads(), repo = MemoryItineraryRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interpreterProvider.overrideWithValue(Interpreter()),
            planningRoadsProvider.overrideWithValue(roads),
            planningSolverProvider.overrideWithValue(
              (input) async => solveDay(input),
            ),
            itineraryRepositoryProvider.overrideWithValue(repo),
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(initialData: fixture()),
            ),
          ],
          child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Review errands'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Next: find suitable places'),
        260,
      );
      await tester.tap(find.text('Next: find suitable places'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build my day'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended places'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Next: see my day'), 260);
      await tester.pump();
      await tester.ensureVisible(find.text('Next: see my day'));
      await tester.pump();
      await tester.tap(find.text('Next: see my day'));
      await tester.pumpAndSettle();
      expect(find.text('Your day'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Use this plan'), 260);
      await tester.pump();
      await tester.ensureVisible(find.text('Use this plan'));
      await tester.pump();
      await tester.tap(find.text('Use this plan'));
      await tester.pumpAndSettle();
      expect(find.text('Your plan'), findsOneWidget);
      expect((await repo.read())?.stops, isNotEmpty);
      expect(tester.takeException(), isNull);
      debugPrint('WAYDAY_ANDROID_PLANNING_FIXTURE_PASSED');
      final keys = ['s', for (var i = 0; i < 12; i++) 'p$i', 'end'];
      final input = <String, dynamic>{
        'keys': keys,
        'errands': [
          for (var i = 0; i < 12; i++)
            Errand(id: 'e$i', title: 'Fixture $i', durationMinutes: 1).toJson(),
        ],
        'matrix': List.generate(
          14,
          (i) => List.generate(14, (j) => i == j ? 0 : 60),
        ),
        'options': {
          for (var i = 0; i < 12; i++) 'e$i': ['p$i'],
        },
        'departure': 28800,
        'deadline': 64800,
        'start': 's',
        'end': 'end',
        'budgetMillis': 150,
      };
      final clock = Stopwatch()..start();
      final solved = await solveInWorker(input);
      clock.stop();
      expect(solved['error'], isNull);
      final scheduled = DaySchedule.fromJson(
        solved['schedule'] as Map<String, dynamic>,
      );
      expect(validateSchedule(input, scheduled), isNull);
      debugPrint(
        'WAYDAY_ANDROID_WORKER_BENCHMARK millis=${clock.elapsedMilliseconds} tasks=12 timeLimited=${scheduled.timeLimited}',
      );
      roads.client.close();
    },
  );
}
