import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class CountingRoads extends Roads {
  int calls = 0, active = 0, peak = 0;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    calls++;
    active++;
    if (active > peak) peak = active;
    try {
      await gate?.future;
      if (fail) throw const PlanningFailure('Road timeout', kind: 'timeout');
      return await super.matrix(day, points, cancelled: cancelled);
    } finally {
      active--;
    }
  }
}

class Drafts extends MemoryRecommendationDraftRepository {
  bool fail = false;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<void> save(String source, RecommendationDraft draft) async {
    calls++;
    await gate?.future;
    if (fail) throw StateError('storage');
    await super.save(source, draft);
  }
}

class WaitingPreparation extends CountingRoads {
  final preparation = Completer<void>();
  @override
  Future<void> preflight(int points, int legs, {bool seed = false}) =>
      preparation.future;
}

class CountingUnderstanding extends Interpreter {
  int calls = 0;
  @override
  Future<Interpretation> interpret(DayPlan day) {
    calls++;
    return super.interpret(day);
  }
}

const alternative = PlaceIntent(
  kind: PlaceKind.specific,
  label: 'Alternative gym',
  latitude: 14.6,
  longitude: 121.07,
);
void main() {
  test('preparation times out visibly before dispatching road work', () async {
    final roads = WaitingPreparation();
    final model = PlanningController(
      fixture(),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
      preparationTimeout: const Duration(milliseconds: 15),
      solver: (input) async => solveDay(input),
    );
    addTearDown(model.dispose);
    addTearDown(roads.client.close);
    await model.understand();
    await model.buildRecommendations();
    expect(model.busy, isFalse);
    expect(model.recommendationFailure?.kind, 'timeout');
    expect(roads.calls, 0);
    roads.preparation.complete();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(roads.calls, 0);
  });
  Future<PlanningController> create(
    CountingRoads roads,
    Drafts drafts, {
    Duration debounce = Duration.zero,
    CountingUnderstanding? understanding,
  }) async {
    final model = PlanningController(
      fixture(),
      understanding ?? Interpreter(),
      roads,
      MemoryItineraryRepository(),
      drafts: drafts,
      routeDebounce: debounce,
      draftSaveTimeout: const Duration(milliseconds: 20),
      solver: (input) async => solveDay(input),
    );
    addTearDown(model.dispose);
    addTearDown(roads.client.close);
    await model.understand();
    model.applyReview();
    await model.calculate();
    return model;
  }

  Future<void> settle() async =>
      Future<void>.delayed(const Duration(milliseconds: 35));
  test(
    'a replacement updates automatically, preserves other choices and is debounced',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final understanding = CountingUnderstanding();
      final model = await create(
        roads,
        drafts,
        debounce: const Duration(milliseconds: 20),
        understanding: understanding,
      );
      final other = model.displayChoices['b'];
      await model.replaceAndRefresh('a', alternative);
      expect(model.result, isNull);
      expect(roads.calls, 1);
      expect(model.routeRefreshState, RouteRefreshState.queued);
      await model.replaceAndRefresh('a', alternative.withLabel('Final gym'));
      await settle();
      await settle();
      expect(model.proposalReady, isTrue);
      expect(roads.calls, 2);
      expect(model.displayChoices['b'], other);
      final before = roads.calls;
      await model.replaceAndRefresh('a', model.displayChoices['a']!);
      await settle();
      expect(roads.calls, before);
      expect(understanding.calls, 1);
      model.review();
      await model.buildRecommendations();
      expect(roads.calls, before);
      expect(understanding.calls, 1);
    },
  );
  test(
    'an older flight cannot overwrite a newer choice and only one road flight runs',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final model = await create(roads, drafts);
      roads.gate = Completer<void>();
      await model.replaceAndRefresh('a', alternative);
      await settle();
      await model.replaceAndRefresh('b', alternative.withLabel('Other stop'));
      await settle();
      expect(roads.calls, 2);
      roads.gate!.complete();
      roads.gate = null;
      await settle();
      await settle();
      expect(model.proposalReady, isTrue);
      expect(roads.calls, 3);
      expect(roads.peak, 1);
      expect(model.displayChoices['b']!.label, 'Other stop');
    },
  );
  test(
    'an older failed save cannot overwrite a newer saved choice status',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final model = await create(roads, drafts);
      final oldWrite = Completer<void>();
      drafts.gate = oldWrite;
      model.replacePlannedPlace('a', alternative);
      final oldSave = model.saveRecommendationDraft();
      drafts.gate = null;
      model.replacePlannedPlace('b', alternative.withLabel('Second place'));
      expect(await model.saveRecommendationDraft(), isTrue);
      oldWrite.completeError(StateError('late storage failure'));
      expect(await oldSave, isFalse);
      expect(model.recommendationStorageError, isNull);
    },
  );
  test(
    'save failure dispatches no roads and explicit retry restores the update',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final model = await create(roads, drafts);
      drafts.fail = true;
      await model.replaceAndRefresh('a', alternative);
      await settle();
      expect(roads.calls, 1);
      expect(model.recommendationStorageError, isNotNull);
      expect(model.routeRefreshState, RouteRefreshState.failed);
      drafts.fail = false;
      await model.retryRouteRefresh();
      expect(model.proposalReady, isTrue);
      expect(roads.calls, 2);
    },
  );
  test(
    'an unresolved save times out and a repeated save attaches to the same write',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final model = await create(roads, drafts);
      drafts.gate = Completer<void>();
      await model.replaceAndRefresh('a', alternative);
      expect(model.recommendationStorageError, isNotNull);
      final count = drafts.calls;
      expect(await model.saveRecommendationDraft(), isFalse);
      expect(drafts.calls, count);
      expect(roads.calls, 1);
      drafts.gate!.complete();
      await settle();
    },
  );
  test(
    'failed update retains the new place, does not retry itself and Back stops queued work',
    () async {
      final roads = CountingRoads(), drafts = Drafts();
      final model = await create(roads, drafts);
      roads.fail = true;
      await model.replaceAndRefresh('a', alternative);
      await settle();
      await settle();
      expect(model.routeRefreshState, RouteRefreshState.failed);
      expect(model.result, isNull);
      expect(model.displayChoices['a'], alternative);
      expect(roads.calls, 2);
      roads.fail = false;
      await model.retryRouteRefresh();
      expect(model.proposalReady, isTrue);
      await model.replaceAndRefresh('a', alternative.withLabel('Queued'));
      model.review();
      await settle();
      expect(model.stage, PreparationStage.review);
      expect(roads.calls, 3);
    },
  );
}
