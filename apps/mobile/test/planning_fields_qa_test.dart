import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/planning/presentation/recommendation_page.dart';
import 'package:wayday/features/planning/presentation/review_errand_tile.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

import 'helpers/planning_fixtures.dart';

// The interpreter and roads are synthetic boundaries. Editor, review, worker
// solver, validation and itinerary serialization use the real implementations.
class _RecordingInterpreter implements SavedErrandInterpreter {
  final inputs = <DayPlan>[];
  final savedInputs = <DayPlan>[];
  final cache = <String, Interpretation>{};

  @override
  Future<Interpretation> saved(DayPlan day) async {
    savedInputs.add(day);
    return cache[interpretationRequest(day)] ??
        (throw const PlanningFailure('No saved meaning', kind: 'cache_miss'));
  }

  @override
  Future<Interpretation> interpret(DayPlan day) async {
    inputs.add(day);
    return cache[interpretationRequest(day)] = Interpretation([
      for (final e in day.errands)
        ErrandNeed(
          id: e.id,
          query: e.notes.isEmpty ? 'grocery' : 'pharmacy',
          category: e.notes.isEmpty ? 'grocery' : 'pharmacy',
          items: e.notes.isEmpty ? [] : ['insulin'],
          durationMinutes: 15,
          locationIntent: LocationIntent.flexible,
        ),
    ]);
  }
}

Future<void> _visibleTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget _planLauncher() => MaterialApp(
  theme: buildTheme(),
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const PlanningView())),
        child: const Text('Open plan'),
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Five-minute road legs, a 15-minute visit and one five-minute buffer:
  // arrive 08:05, finish service 08:20, leave 08:25, reach end 08:30.
  for (final scenario in [
    (TimingRule.anytime, null, 510, true),
    (TimingRule.anytime, null, 509, false),
    (TimingRule.at, 485, 510, true),
    (TimingRule.at, 484, 510, false),
    (TimingRule.arriveBy, 485, 510, true),
    (TimingRule.arriveBy, 484, 510, false),
    (TimingRule.finishBefore, 505, 510, true),
    (TimingRule.finishBefore, 504, 510, false),
  ]) {
    test(
      'exact boundary ${scenario.$1.name} at ${scenario.$2}, deadline ${scenario.$3}, fits=${scenario.$4}',
      () {
        final input = <String, dynamic>{
          'errands': [
            Errand(
              id: 'a',
              title: 'Visit',
              timing: scenario.$1,
              minute: scenario.$2,
            ).toJson(),
          ],
          'keys': ['s', 'a', 'end'],
          'matrix': [
            [0, 300, 300],
            [300, 0, 300],
            [300, 300, 0],
          ],
          'options': {
            'a': ['a'],
          },
          'departure': 480 * 60,
          'deadline': scenario.$3 * 60,
          'start': 's',
          'end': 'end',
        };
        final output = solveDay(input);
        if (scenario.$4) {
          final schedule = DaySchedule.fromJson(
            output['schedule'] as Map<String, dynamic>,
          );
          expect(validateSchedule(input, schedule), isNull);
          expect(schedule.stops.single.arrival, 485 * 60);
          expect(schedule.stops.single.tasks.single.finish, 500 * 60);
          expect(schedule.stops.single.departure, 505 * 60);
          expect(schedule.endArrival, 510 * 60);
        } else {
          expect(output['error'], 'conflict');
          expect(output['schedule'], isNull);
        }
      },
    );
  }

  for (final timing in TimingRule.values) {
    testWidgets(
      'restored ${timing.name}, notes, optional and duration reach the final itinerary',
      (tester) async {
        final source = fixture().copyWith(errands: [fixture().errands.first]);
        final interpreter = _RecordingInterpreter();
        final roads = Roads();
        final repo = MemoryItineraryRepository();
        Map<String, dynamic>? workerInput;
        addTearDown(roads.client.close);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              interpreterProvider.overrideWithValue(interpreter),
              planningRoadsProvider.overrideWithValue(roads),
              planningSolverProvider.overrideWithValue((input) async {
                workerInput = input;
                return solveDay(input);
              }),
              itineraryRepositoryProvider.overrideWithValue(repo),
              dayRepositoryProvider.overrideWithValue(
                MemoryDayRepository(initialData: source),
              ),
            ],
            child: _planLauncher(),
          ),
        );
        await tester.pumpAndSettle();
        await _visibleTap(tester, find.text('Open plan'));
        await _visibleTap(tester, find.text('Grocery'));
        await _visibleTap(tester, find.text('Edit errand'));
        final notes = find.widgetWithText(TextFormField, 'Notes (optional)');
        await tester.enterText(
          notes,
          'Buy insulin; keep the selected pharmacy',
        );
        await _visibleTap(tester, find.text('When'));
        await _visibleTap(tester, find.text(timing.label).last);
        await _visibleTap(tester, find.text('Done'));
        if (timing != TimingRule.anytime) {
          await tester.enterText(find.byKey(const Key('time-hour')), '10');
          await tester.enterText(find.byKey(const Key('time-minute')), '00');
          await _visibleTap(tester, find.text('Save time'));
        }
        await _visibleTap(tester, find.byType(Switch));
        await _visibleTap(tester, find.text('More details'));
        await tester.ensureVisible(find.byKey(const Key('errand-duration')));
        await tester.enterText(find.byKey(const Key('errand-duration')), '37');
        await _visibleTap(tester, find.text('Save'));

        expect(find.text('Review errands'), findsOneWidget);
        expect(find.textContaining('37 min'), findsOneWidget);
        expect(find.textContaining('If there’s time'), findsOneWidget);
        expect(find.text('Read updated notes with Gemini'), findsOneWidget);
        // An edit must not silently dispatch another interpretation.
        expect(interpreter.inputs, hasLength(1));
        await _visibleTap(tester, find.text('Read updated notes with Gemini'));
        expect(interpreter.inputs, hasLength(2));
        final analyzed = interpreter.inputs.last.errands.single;
        expect(analyzed.notes, 'Buy insulin; keep the selected pharmacy');
        expect(analyzed.timing, timing);
        expect(analyzed.minute, timing == TimingRule.anytime ? null : 600);
        expect(analyzed.optional, isTrue);
        expect(analyzed.durationMinutes, 37);
        expect(analyzed.durationConfirmed, isTrue);
        expect(
          interpretationRequest(interpreter.inputs.last),
          contains('Buy insulin; keep the selected pharmacy'),
        );

        await _visibleTap(tester, find.text('Close'));
        await _visibleTap(tester, find.text('Open plan'));
        expect(interpreter.inputs, hasLength(2));
        expect(interpreter.savedInputs, hasLength(1));
        await _visibleTap(tester, find.text('Build recommendations'));
        expect(find.text('Your plan'), findsOneWidget);
        expect(find.textContaining('Visit 37 min'), findsOneWidget);
        final model = tester
            .widget<RecommendationPage>(find.byType(RecommendationPage))
            .model;
        final schedule = model.result!.schedule;
        final task = schedule.stops.single.tasks.single;
        expect(task.finish - task.start, 37 * 60);
        expect(schedule.stops.single.departure - task.finish, 5 * 60);
        switch (timing) {
          case TimingRule.anytime:
            expect(task.start, source.departure * 60 + 60);
          case TimingRule.at:
            expect(task.start, 600 * 60);
          case TimingRule.arriveBy:
            expect(schedule.stops.single.arrival, lessThanOrEqualTo(600 * 60));
          case TimingRule.finishBefore:
            expect(
              schedule.stops.single.departure,
              lessThanOrEqualTo(600 * 60),
            );
        }
        expect(validateSchedule(workerInput!, schedule), isNull);
        expect(model.effectiveNeed(model.day.errands.single)!.items, [
          'insulin',
        ]);
        await _visibleTap(tester, find.text('Start trip'));
        final accepted = (await repo.read())!;
        final acceptedErrand = accepted.day.errands.single;
        expect(
          acceptedErrand.toJson()..remove('confirmedFields'),
          analyzed.toJson()..remove('confirmedFields'),
        );
        expect(acceptedErrand.confirmedFields, analyzed.confirmedFields);
        expect(accepted.stops.single.errandIds, ['a']);
        final reopened = AcceptedItinerary.fromJson(
          jsonDecode(jsonEncode(accepted.toJson())) as Map<String, dynamic>,
          (_) => GooglePinLease(),
        );
        expect(reopened.day.errands.single.toJson(), acceptedErrand.toJson());
        expect(source.errands.single.notes, isEmpty);
        expect(source.errands.single.optional, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  test(
    'duration edits invalidate the old route and change optional inclusion',
    () async {
      final source = fixture().copyWith(
        deadline: 570,
        errands: [
          fixture().errands.first,
          fixture().errands.last.copyWith(optional: true, durationMinutes: 90),
        ],
      );
      final roads = Roads();
      final interpreter = _RecordingInterpreter();
      final repo = MemoryItineraryRepository();
      final model = PlanningController(source, interpreter, roads, repo);
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.applyReview();
      await model.calculate();
      expect(model.result!.schedule.omitted.keys, ['b']);
      final first = await model.accept(0, 0);
      expect(first.omitted.keys, ['b']);
      model.review();
      model.edit(
        model.reviewInput(source.errands.last).copyWith(durationMinutes: 10),
      );
      expect(model.result, isNull);
      await expectLater(model.accept(0, 0), throwsA(isA<PlanningFailure>()));
      model.applyReview();
      await model.calculate();
      expect(model.result!.schedule.omitted, isEmpty);
      expect(
        model.result!.schedule.stops.single.tasks
            .map((t) => t.errandId)
            .toSet(),
        {'a', 'b'},
      );
      expect(interpreter.inputs, hasLength(1));
      final accepted = await model.accept(0, 0);
      expect(accepted.day.errands.last.durationMinutes, 10);
      expect(accepted.omitted, isEmpty);
    },
  );

  test(
    'Review dependencies reorder shared tasks and preserve separate durations',
    () async {
      final source = fixture();
      final roads = Roads();
      final interpreter = _RecordingInterpreter();
      final model = PlanningController(
        source,
        interpreter,
        roads,
        MemoryItineraryRepository(),
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.edit(
        source.errands.first.copyWith(
          afterErrandIds: ['b'],
          confirmedFields: {'dependencies'},
        ),
      );
      expect(model.reviewOrder.items.map((e) => e.id), ['b', 'a']);
      model.applyReview();
      await model.calculate();
      final stop = model.result!.schedule.stops.single;
      expect(stop.tasks.map((t) => t.errandId), ['b', 'a']);
      expect(stop.tasks[0].finish - stop.tasks[0].start, 40 * 60);
      expect(stop.tasks[1].finish - stop.tasks[1].start, 20 * 60);
      expect(stop.departure - stop.arrival, 65 * 60);
      final accepted = await model.accept(0, 0);
      expect(accepted.day.errands.last.afterErrandIds, ['b']);
    },
  );

  testWidgets(
    'reopened Review restores manual fields and requires explicit analysis on a cache miss',
    (tester) async {
      final source = fixture();
      final interpreter = _RecordingInterpreter();
      final roads = Roads();
      final settings = MemoryReviewTripRepository();
      final repo = MemoryItineraryRepository();
      addTearDown(roads.client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interpreterProvider.overrideWithValue(interpreter),
            planningRoadsProvider.overrideWithValue(roads),
            planningSolverProvider.overrideWithValue(
              (input) async => solveDay(input),
            ),
            itineraryRepositoryProvider.overrideWithValue(repo),
            reviewTripRepositoryProvider.overrideWithValue(settings),
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(initialData: source),
            ),
          ],
          child: _planLauncher(),
        ),
      );
      await _visibleTap(tester, find.text('Open plan'));
      await _visibleTap(tester, find.text('Grocery'));
      await _visibleTap(tester, find.text('Edit errand'));
      await tester.enterText(
        find.byKey(const Key('errand-notes')),
        'Buy insulin',
      );
      await _visibleTap(tester, find.text('When'));
      await _visibleTap(tester, find.text('Arrive by'));
      await _visibleTap(tester, find.text('Done'));
      await tester.enterText(find.byKey(const Key('time-hour')), '10');
      await _visibleTap(tester, find.text('Save time'));
      await _visibleTap(tester, find.byType(Switch));
      await _visibleTap(tester, find.text('More details'));
      await tester.ensureVisible(find.byKey(const Key('errand-duration')));
      await tester.enterText(find.byKey(const Key('errand-duration')), '37');
      await _visibleTap(tester, find.text('After another errand'));
      await _visibleTap(tester, find.text(source.errands.last.title));
      await _visibleTap(tester, find.text('Done'));
      await _visibleTap(tester, find.text('Save'));
      final edited = tester
          .widgetList<ReviewErrandTile>(find.byType(ReviewErrandTile))
          .singleWhere((t) => t.errand.id == 'a')
          .errand;
      expect(edited.notes, 'Buy insulin');
      expect(edited.durationMinutes, 37);
      expect(edited.optional, isTrue);
      expect(edited.afterErrandIds, ['b']);
      await _visibleTap(tester, find.text('Close'));
      await _visibleTap(tester, find.text('Open plan'));
      final restored = tester
          .widgetList<ReviewErrandTile>(find.byType(ReviewErrandTile))
          .singleWhere((t) => t.errand.id == 'a')
          .errand;
      expect(restored.timing, TimingRule.arriveBy);
      expect(restored.minute, 600);
      expect(restored.notes, 'Buy insulin');
      expect(restored.durationMinutes, 37);
      expect(restored.optional, isTrue);
      expect(restored.afterErrandIds, ['b']);
      expect(interpreter.inputs, hasLength(1));
      expect(interpreter.savedInputs.single.errands.first.notes, 'Buy insulin');
      final build = find.widgetWithText(FilledButton, 'Build recommendations');
      expect(tester.widget<FilledButton>(build).onPressed, isNull);
      await _visibleTap(tester, find.text('Read updated notes with Gemini'));
      expect(interpreter.inputs, hasLength(2));
      await _visibleTap(tester, find.text('Close'));
      await _visibleTap(tester, find.text('Open plan'));
      expect(interpreter.inputs, hasLength(2));
      expect(find.text('Read updated notes with Gemini'), findsNothing);
      await _visibleTap(tester, build);
      final model = tester
          .widget<RecommendationPage>(find.byType(RecommendationPage))
          .model;
      final task = model.result!.schedule.stops
          .expand((s) => s.tasks)
          .singleWhere((task) => task.errandId == 'a');
      expect(task.finish - task.start, 37 * 60);
      await _visibleTap(tester, find.text('Start trip'));
      final accepted = (await repo.read())!.day.errands.singleWhere(
        (e) => e.id == 'a',
      );
      expect(accepted.toJson(), restored.toJson());
      expect(tester.takeException(), isNull);
    },
  );
}
