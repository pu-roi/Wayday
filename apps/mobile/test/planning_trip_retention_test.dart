import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';
import 'package:wayday/features/planning/data/interpretation_request.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'helpers/planning_fixtures.dart';

class _RequestSpy extends Interpreter {
  final requests = <String>[];
  @override
  Future<Interpretation> interpret(DayPlan day) {
    requests.add(interpretationRequest(day));
    return super.interpret(day);
  }
}

class _FailingTrips implements ReviewTripRepository {
  final memory = MemoryReviewTripRepository();
  bool fail = true;
  int reads = 0;
  @override
  Future<ReviewTrip?> read(DayPlan source) {
    reads++;
    return memory.read(source);
  }

  @override
  Future<void> save(DayPlan source, DayPlan draft) async {
    if (fail) throw StateError('fixture storage failure');
    await memory.save(source, draft);
  }
}

void main() {
  testWidgets(
    'manual errand clock survives reopen after unchanged interpretation inputs',
    (tester) async {
      final base = fixture();
      final source = base.copyWith(
        departure: 780,
        errands: [
          base.errands.first.copyWith(
            title: 'Pickup',
            timing: TimingRule.arriveBy,
            minute: 570,
          ),
        ],
      );
      final interpreter = _RequestSpy();
      final today = MemoryDayRepository(initialData: source);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayRepositoryProvider.overrideWithValue(today),
            interpreterProvider.overrideWithValue(interpreter),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanningView()),
                  ),
                  child: const Text('Open planner'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Pickup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('errand-time')));
      await tester.tap(find.byKey(const Key('errand-time')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('time-hour')), '2');
      await tester.tap(find.text('PM'));
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PlanningReview>(find.byType(PlanningReview))
            .model
            .day
            .errands
            .first
            .minute,
        870,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      final model = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model;
      expect(model.day.errands.first.minute, 870);
      expect(model.reviewErrands.first.minute, 870);
      expect(today.read().errands.first.minute, 570);
      expect(interpreter.requests, hasLength(2));
      expect(interpreter.requests.first, interpreter.requests.last);
      expect(find.text('Edit Pickup'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'save failure remains visible and explicit retry retains the edit',
    (tester) async {
      final trips = _FailingTrips(), source = fixture();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(initialData: source),
            ),
            interpreterProvider.overrideWithValue(Interpreter()),
            reviewTripRepositoryProvider.overrideWithValue(trips),
          ],
          child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trip details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Departure'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12:00 PM'));
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your review changes could not be saved. Retry saving before closing.',
        ),
        findsOneWidget,
      );
      trips.fail = false;
      await tester.tap(find.text('Retry saving trip settings'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving trip settings'), findsNothing);
      expect((await trips.memory.read(source))!.departure, 720);
    },
  );

  testWidgets('replanning inputs never inherit the normal Today review trip', (
    tester,
  ) async {
    final trips = _FailingTrips()..fail = false;
    final source = fixture();
    await trips.save(source, source.copyWith(date: '2026-12-25'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayRepositoryProvider.overrideWithValue(
            MemoryDayRepository(initialData: source),
          ),
          interpreterProvider.overrideWithValue(Interpreter()),
          reviewTripRepositoryProvider.overrideWithValue(trips),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: PlanningView(initial: source),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PlanningReview>(find.byType(PlanningReview)).model.day.date,
      source.date,
    );
    expect(trips.reads, 0);
  });

  testWidgets(
    'a confirmed review date survives Close and reopen without changing Today',
    (tester) async {
      final source = fixture().copyWith(date: '2020-01-01');
      final today = MemoryDayRepository(initialData: source), roads = Roads();
      addTearDown(roads.client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayRepositoryProvider.overrideWithValue(today),
            interpreterProvider.overrideWithValue(Interpreter()),
            planningRoadsProvider.overrideWithValue(roads),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const PlanningView()),
                  ),
                  child: const Text('Open planner'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Build recommendations'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final edited = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model
          .day
          .date;
      expect(edited, isNot('2020-01-01'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Build recommendations'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open planner'));
      await tester.pumpAndSettle();
      final reopened = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model
          .day;
      expect(reopened.date, edited);
      expect(today.read().date, '2020-01-01');
    },
  );
}
