import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

class Discovery implements RecommendationDiscovery {
  @override
  Future<void> preflight(int maximumRequests) async {}
  var calls = 0;
  @override
  Future<List<PlanCandidate>> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
  }) async {
    calls++;
    return [
      PlanCandidate(key: placeKey(pin), place: pin, errandIds: {need.id}),
    ];
  }

  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) async => null;
  @override
  RecommendationPlace? metadata(PlaceIntent place) => null;
}

void main() {
  test(
    'approved proposals and an included extra errand survive restart',
    () async {
      final source = fixture().copyWith(
            errands: fixture().errands
                .map((e) => e.copyWith(placeIntent: const PlaceIntent()))
                .toList(),
          ),
          drafts = MemoryRecommendationDraftRepository(),
          roads = Roads();
      final interpreter = AdditionalInterpreter();
      final model = PlanningController(
        source,
        interpreter,
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
        discovery: Discovery(),
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      await model.restoreRecommendationDraft();
      model.approved.add('b');
      model.addAddition(model.interpretation!.additions.single);
      await model.buildRecommendations();
      expect(model.result, isNotNull);
      final reopened = PlanningController(
        source,
        interpreter,
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
        discovery: Discovery(),
      );
      addTearDown(reopened.dispose);
      await reopened.understand();
      await reopened.restoreRecommendationDraft();
      expect(reopened.additions, {'extra'});
      expect(reopened.approved, {'b'});
      expect(reopened.candidates['extra'], isNotEmpty);
    },
  );
  test(
    'an explicitly confirmed start persists before a first draft restore',
    () async {
      final source = fixture(),
          drafts = MemoryRecommendationDraftRepository(),
          roads = Roads();
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.setEndpoint(
        true,
        const PlaceIntent(
          label: 'New start',
          kind: PlaceKind.specific,
          latitude: 14.6,
          longitude: 121.07,
        ),
      );
      expect(await model.saveRecommendationDraft(), isTrue);
      final reopened = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
      );
      addTearDown(reopened.dispose);
      await reopened.understand();
      await reopened.restoreRecommendationDraft();
      expect(reopened.day.fromPlace.label, 'New start');
    },
  );
  test(
    'Close during understanding does not erase an existing recommendation draft',
    () async {
      final roads = Roads(),
          source = fixture(),
          drafts = MemoryRecommendationDraftRepository();
      final first = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
        solver: (input) async => solveDay(input),
      );
      addTearDown(first.dispose);
      addTearDown(roads.client.close);
      await first.understand();
      first.applyReview();
      await first.calculate();
      first.selectedErrand = 'a';
      await first.saveRecommendationDraft();
      final next = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
      );
      addTearDown(next.dispose);
      await next.saveRecommendationDraft();
      await next.understand();
      await next.restoreRecommendationDraft();
      expect(next.selectedErrand, 'a');
    },
  );
  test(
    'late restoration cannot replace a newly confirmed trip start',
    () async {
      final roads = Roads(),
          source = fixture(),
          drafts = MemoryRecommendationDraftRepository();
      final first = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: drafts,
        solver: (input) async => solveDay(input),
      );
      addTearDown(first.dispose);
      addTearDown(roads.client.close);
      await first.understand();
      first.applyReview();
      await first.calculate();
      final saved = await drafts.read(reviewTripSourceKey(source), null);
      final delayed = DeferredDrafts();
      final next = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        drafts: delayed,
      );
      addTearDown(next.dispose);
      await next.understand();
      final restore = next.restoreRecommendationDraft();
      const moved = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Confirmed new start',
        latitude: 14.59,
        longitude: 121.07,
      );
      next.setEndpoint(true, moved);
      delayed.result.complete(saved);
      await restore;
      expect(next.day.fromPlace.label, moved.label);
    },
  );
  test(
    'Ugong to Palatiw compares gym and coffee jointly instead of choosing the nearest branches',
    () {
      final keys = [
        'start',
        'near-gym',
        'route-gym',
        'near-coffee',
        'route-coffee',
        'end',
      ];
      final matrix = List.generate(
        6,
        (a) => List<int?>.generate(6, (b) => a == b ? 0 : 1800),
      );
      matrix[0][1] = 60;
      matrix[0][2] = 240;
      matrix[2][4] = 60;
      matrix[4][5] = 240;
      final input = <String, dynamic>{
        'keys': keys,
        'matrix': matrix,
        'start': 'start',
        'end': 'end',
        'departure': 28800,
        'deadline': 36000,
        'errands': [
          const Errand(id: 'gym', title: 'Go to gym').toJson(),
          const Errand(
            id: 'coffee',
            title: 'Buy coffee',
            afterErrandIds: ['gym'],
          ).toJson(),
        ],
        'options': {
          'gym': ['near-gym', 'route-gym'],
          'coffee': ['near-coffee', 'route-coffee'],
        },
      };
      final raw = solveDay(input);
      expect(raw['error'], isNull);
      final schedule = DaySchedule.fromJson(
        raw['schedule'] as Map<String, dynamic>,
      );
      expect(schedule.stops.map((s) => s.placeKey), [
        'route-gym',
        'route-coffee',
      ]);
      expect(schedule.travelSeconds, 540);
      expect(validateSchedule(input, schedule), isNull);
    },
  );
  test(
    'changing to an already compared branch reuses the road matrix',
    () async {
      final roads = CountedRoads();
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
      model.chooseAlternative('a', model.candidates['a']!.first.key);
      await model.calculate();
      expect(roads.calls, 1);
      expect(model.result, isNotNull);
    },
  );
  test(
    'whole-trip build discovers flexible work without manual selections and restores choices',
    () async {
      final source = fixture().copyWith(
        errands: [
          fixture().errands.first.copyWith(placeIntent: const PlaceIntent()),
        ],
      );
      final discovery = Discovery(),
          roads = Roads(),
          drafts = MemoryRecommendationDraftRepository();
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: discovery,
        drafts: drafts,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      await model.buildRecommendations();
      expect(discovery.calls, 1);
      expect(model.stage, PreparationStage.recommendations);
      expect(
        model.result!.schedule.stops.expand((s) => s.tasks).single.errandId,
        'a',
      );
      model.selectedErrand = 'a';
      await model.saveRecommendationDraft();
      final reopened = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: discovery,
        drafts: drafts,
      );
      addTearDown(reopened.dispose);
      await reopened.understand();
      await reopened.restoreRecommendationDraft();
      expect(reopened.selectedErrand, 'a');
      expect(reopened.candidates['a']!.single.place.hasCoordinates, isTrue);
      expect(reopened.result, isNull);
      expect(discovery.calls, 1);
    },
  );
}

class CountedRoads extends Roads {
  var calls = 0;
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

class AdditionalInterpreter extends Interpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation(
    (await super.interpret(day)).needs,
    additions: const [
      ErrandNeed(id: 'extra', query: 'coffee', proposedTitle: 'Buy coffee'),
    ],
  );
}

class DeferredDrafts implements RecommendationDraftRepository {
  final result = Completer<RecommendationDraft?>();
  @override
  Future<RecommendationDraft?> read(
    String source,
    String? context, {
    GooglePinResolver? resolver,
  }) => result.future;
  @override
  Future<void> save(String source, RecommendationDraft draft) async {}
}
