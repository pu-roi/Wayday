import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'proposals require approval, reversals work, and stale inputs cannot be accepted',
    () async {
      final source = fixture(),
          repo = MemoryItineraryRepository(),
          roads = Roads();
      final model = PlanningController(source, Interpreter(), roads, repo);
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      expect(source.errands.last.afterErrandIds, isEmpty);
      model.applyReview();
      expect(model.day.errands.last.afterErrandIds, isEmpty);
      model.review();
      model.approved.add('b');
      model.applyReview();
      expect(model.day.errands.last.afterErrandIds, ['a']);
      expect(model.day.errands.last.durationMinutes, 40);
      model.review();
      model.approved.remove('b');
      model.applyReview();
      expect(model.day.errands.last.afterErrandIds, isEmpty);
      await model.calculate();
      expect(model.result, isNotNull);
      await expectLater(
        model.accept(1, 0),
        throwsA(isA<PlanningFailure>().having((e) => e.kind, 'kind', 'stale')),
      );
      expect(await repo.read(), isNull);
      final saved = await model.accept(0, 0);
      expect(saved.stops.expand((s) => s.errandIds).toSet(), {'a', 'b'});
      expect(source.errands.last.afterErrandIds, isEmpty);
      model.cancel();
      expect(model.result, isNull);
      expect(model.stage, PreparationStage.review);
    },
  );
  test('late interpretation cannot replace a cancelled session', () async {
    final interpreter = DeferredInterpreter(), roads = Roads();
    final model = PlanningController(
      fixture(),
      interpreter,
      roads,
      MemoryItineraryRepository(),
    );
    addTearDown(model.dispose);
    addTearDown(roads.client.close);
    final pending = model.understand();
    model.cancel();
    interpreter.response.complete(
      Interpretation([const ErrandNeed(id: 'a', query: 'x')]),
    );
    await pending;
    expect(model.interpretation, isNull);
    expect(model.stage, PreparationStage.failed);
  });
  test(
    'past starts, unlocated meetings and unqualified vehicle modes fail before routing',
    () async {
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture().copyWith(date: '2020-01-01'),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
      );
      addTearDown(model.dispose);
      await model.understand();
      expect(
        model.applyReview,
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'invalid_input'),
        ),
      );
      model.day = fixture().copyWith(profile: TravelProfile.truck);
      expect(
        model.applyReview,
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.kind,
            'kind',
            'unsupported_profile',
          ),
        ),
      );
      model.lightPickupConfirmed = true;
      model.applyReview();
      model.day = model.day.copyWith(profile: TravelProfile.bike);
      expect(
        model.applyReview,
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.kind,
            'kind',
            'unsupported_profile',
          ),
        ),
      );
    },
  );
  test('automatic order repair persists and increments revisions', () async {
    final original = fixture();
    final b = original.errands.last.copyWith(afterErrandIds: ['a']);
    final repo = MemoryDayRepository(
      initialData: original.copyWith(errands: [b, original.errands.first]),
    );
    final container = ProviderContainer(
      overrides: [dayRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    expect(container.read(todayProvider).errands.map((e) => e.id), ['a', 'b']);
    await Future<void>.delayed(Duration.zero);
    expect(repo.read().errands.map((e) => e.id), ['a', 'b']);
    final revision = container.read(todayProvider).revision;
    container.read(todayProvider.notifier).setTimes(departure: 600);
    expect(container.read(todayProvider).revision, greaterThan(revision));
  });
  test(
    'replanning acceptance keeps completed history and original prerequisite identities',
    () async {
      final source = fixture();
      final initial = AcceptedItinerary(
        day: source.copyWith(
          errands: [
            source.errands.first,
            source.errands.last.copyWith(afterErrandIds: ['a']),
          ],
        ),
        stops: [
          const ItineraryStop(pin, ['a', 'b']),
        ],
        acceptedAt: DateTime.now(),
      ).complete('a');
      final roads = Roads(), repo = MemoryItineraryRepository();
      addTearDown(roads.client.close);
      final model = PlanningController(
        source.copyWith(errands: [source.errands.last]),
        Interpreter(),
        roads,
        repo,
      );
      addTearDown(model.dispose);
      await model.understand();
      model.applyReview();
      await model.calculate();
      final next = await model.accept(0, 0, history: initial);
      expect(next.completed, {'a'});
      expect(next.stops.expand((s) => s.errandIds), ['a', 'b']);
      expect(next.day.errands.last.afterErrandIds, ['a']);
      expect(next.complete('b').completed, {'a', 'b'});
    },
  );
  test(
    'editing title or notes invalidates interpretation instead of using an old search need',
    () async {
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture(),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
      );
      addTearDown(model.dispose);
      await model.understand();
      model.edit(
        model.day.errands.first.copyWith(notes: 'Different requested items'),
      );
      expect(model.interpretationStale, isTrue);
      expect(model.applyReview, throwsA(isA<PlanningFailure>()));
    },
  );
  testWidgets(
    'review, calculate, inspect and accept a synthetic day using existing theme',
    (tester) async {
      final roads = Roads(), repo = MemoryItineraryRepository();
      addTearDown(roads.client.close);
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
      final next = find.text('Next: find suitable places');
      await tester.scrollUntilVisible(next, 300);
      await tester.pump();
      await tester.ensureVisible(next);
      await tester.pump();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Build my day'), findsOneWidget);
      await tester.tap(find.text('Build my day'));
      await tester.pumpAndSettle();
      expect(find.text('Recommended places'), findsOneWidget);
      final day = find.text('Next: see my day');
      await tester.scrollUntilVisible(day, 300);
      await tester.pump();
      await tester.ensureVisible(day);
      await tester.pump();
      await tester.tap(day);
      await tester.pumpAndSettle();
      expect(find.text('Your day'), findsOneWidget);
      final accept = find.text('Use this plan');
      await tester.scrollUntilVisible(accept, 300);
      await tester.pump();
      await tester.ensureVisible(accept);
      await tester.pump();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(find.text('Your plan'), findsOneWidget);
      expect((await repo.read())!.stops, isNotEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
