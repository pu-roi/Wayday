import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/recommendation_page.dart';
import 'package:wayday/features/planning/presentation/plan_map.dart';
import 'helpers/planning_fixtures.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

class CountUnderstanding extends Interpreter {
  int calls = 0;
  @override
  Future<Interpretation> interpret(DayPlan day) {
    calls++;
    return super.interpret(day);
  }
}

class CountRoads extends Roads {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) {
    calls++;
    return super.matrix(day, points, cancelled: cancelled);
  }
}

void main() {
  test(
    'several chosen replacements require one update and no new understanding',
    () async {
      final understanding = CountUnderstanding(), roads = CountRoads();
      final model = PlanningController(
        fixture(),
        understanding,
        roads,
        MemoryItineraryRepository(),
        solver: (input) async => solveDay(input),
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.applyReview();
      await model.calculate();
      final originalOrder = model.result!.schedule.stops
          .expand((s) => s.tasks.map((t) => t.errandId))
          .join('|');
      model.day = model.day.copyWith(
        errands: model.day.errands.reversed.toList(),
      );
      model.replacePlannedPlace(
        'a',
        const PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Alternative A',
          latitude: 14.6,
          longitude: 121.07,
        ),
      );
      final kept = model.displayChoices['a'];
      model.replacePlannedPlace(
        'b',
        const PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Alternative B',
          latitude: 14.61,
          longitude: 121.08,
        ),
      );
      expect(model.displayChoices['a'], kept);
      expect(model.result, isNull);
      expect(roads.calls, 1);
      await model.updatePlan();
      expect(model.proposalReady, isTrue);
      expect(
        model.orderChanged,
        originalOrder !=
            model.result!.schedule.stops
                .expand((s) => s.tasks.map((t) => t.errandId))
                .join('|'),
      );
      expect(understanding.calls, 1);
      expect(roads.calls, 2);
      await model.buildRecommendations();
      expect(roads.calls, 2);
      expect(understanding.calls, 1);
    },
  );
  testWidgets('places, schedule and visible replacements share one page', (
    tester,
  ) async {
    final model = PlanningController(
      fixture(),
      Interpreter(),
      Roads(),
      MemoryItineraryRepository(),
      solver: (input) async => solveDay(input),
    );
    addTearDown(model.dispose);
    await model.understand();
    model.applyReview();
    await model.calculate();
    var changes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: RecommendationPage(
            model: model,
            onChange: (_) => changes++,
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change'), findsWidgets);
    expect(find.textContaining('Arrive'), findsWidgets);
    expect(find.text('Start trip'), findsOneWidget);
    expect(find.text('Save for reuse'), findsOneWidget);
    expect(find.text('Next: see my day'), findsNothing);
    await tester.tap(find.text('Change').first);
    expect(changes, 1);
    model.result = null;
    model.error = 'Google testing budget reached.';
    model.recommendationFailure = const PlanningFailure(
      'Google testing budget reached.',
      kind: 'testing_budget',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: RecommendationPage(
            key: const ValueKey('paused'),
            model: model,
            onChange: (_) => changes++,
            onContinue: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change'), findsWidgets);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Retry route update'),
    );
    expect(start.onPressed, isNull);
  });
  testWidgets('inline map state survives refresh notice and route changes', (
    tester,
  ) async {
    final roads = Roads();
    final model = PlanningController(
      fixture(),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
      solver: (input) async => solveDay(input),
    );
    addTearDown(model.dispose);
    addTearDown(roads.client.close);
    await model.understand();
    model.applyReview();
    await model.calculate();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: model,
            builder: (_, child) => RecommendationPage(
              model: model,
              onChange: (_) {},
              onContinue: () {},
            ),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.byType(PlanMap),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final map = tester.state(find.byType(PlanMap));
    model.replacePlannedPlace(
      'a',
      const PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Replacement',
        latitude: 14.6,
        longitude: 121.07,
      ),
    );
    model.routeRefreshState = RouteRefreshState.refreshing;
    await tester.pump();
    expect(identical(tester.state(find.byType(PlanMap)), map), isTrue);
    await model.calculate();
    await tester.pump();
    expect(identical(tester.state(find.byType(PlanMap)), map), isTrue);
  });
}
