import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

Map<String, Object?> listing(
  String id, {
  int? opening = 8,
  int closing = 20,
  bool enriched = true,
  String status = 'OPERATIONAL',
}) => {
  'id': id,
  'name': 'Actual business $id',
  'latitude': 14.58,
  'longitude': 121.06,
  'country': 'PH',
  'types': ['gym'],
  'status': status,
  'at': DateTime.now().millisecondsSinceEpoch,
  if (enriched) ...{
    'hoursVersion': 1,
    'utcOffset': 480,
    'regularHours': opening == null
        ? null
        : {
            'weekdays': ['Daily test hours'],
            'periods': [
              for (var d = 0; d < 7; d++)
                {
                  'open': {'day': d, 'hour': opening, 'minute': 0},
                  'close': {'day': d, 'hour': closing, 'minute': 0},
                },
            ],
          },
  },
};

class ShiftedRoads extends Roads {
  bool shift = false;
  @override
  Future<RefinedPlan> refine(
    DayPlan day,
    DaySchedule initial,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    if (!shift) return super.refine(day, initial, points, cancelled: cancelled);
    const delay = 3600;
    return RefinedPlan(
      DaySchedule(
        stops: [
          for (final s in initial.stops)
            ScheduledStop(s.placeKey, s.arrival + delay, s.departure + delay, [
              for (final t in s.tasks)
                ScheduledTask(t.errandId, t.start + delay, t.finish + delay),
            ]),
        ],
        omitted: initial.omitted,
        endArrival: initial.endArrival + delay,
        travelSeconds: initial.travelSeconds + delay,
      ),
      [],
      false,
    );
  }
}

void main() {
  GoogleRecommendationDiscovery service(
    PlacesInvoker invoke, {
    PlanningBudget? budget,
  }) {
    final pins = GooglePinCache(read: () async => null, write: (_) async {});
    addTearDown(pins.dispose);
    return GoogleRecommendationDiscovery(
      QuotaLedger(
        read: () async => null,
        write: (_) async {},
        googleBudget: budget,
      ),
      pins,
      invoke: invoke,
    );
  }

  Future<DiscoveryResult> search(
    GoogleRecommendationDiscovery source, {
    HoursQuery? hours,
  }) => source.discover(
    const ErrandNeed(id: 'a', query: 'gym'),
    polyline: 'seed',
    anchors: [pin],
    limit: 3,
    cancelled: () => false,
    hours: hours,
  );
  test(
    'closed-window records are excluded before the three-place shortlist',
    () async {
      final source = service(
        (_, _) async => [
          for (var i = 0; i < 3; i++)
            listing('closed$i', opening: 20, closing: 23),
          listing('open'),
          listing('unknown', opening: null),
          listing('temporary', status: 'CLOSED_TEMPORARILY'),
        ],
      );
      final result = await search(
        source,
        hours: const HoursQuery('2030-01-01', 600, 900, 15),
      );
      expect(
        result.candidates.map((p) => p.key),
        containsAll(['google:open', 'google:unknown']),
      );
      expect(result.candidates.length, 2);
      expect(result.exclusions[PlaceExclusion.hours], greaterThanOrEqualTo(3));
      expect(result.exclusions[PlaceExclusion.closed], greaterThanOrEqualTo(1));
    },
  );
  test(
    'old field profiles refresh; enriched missing hours reuse without hidden calls',
    () async {
      var calls = 0;
      final source = service((method, _) async {
        calls++;
        return [listing('a', opening: null, enriched: method != 'search')];
      });
      final place = (await search(source)).candidates.single.place;
      expect(source.metadata(place)!.hours.checked, isFalse);
      await source.hydrate(place);
      expect(
        source.hoursStatus(place).day('2030-01-01').state,
        HoursState.notProvided,
      );
      await source.hydrate(place);
      expect(calls, 3); // Partial corridor + anchor, then one details refresh.
    },
  );
  test(
    'failed check is not missing hours and explicit retry replaces the failure',
    () async {
      var fail = true;
      final source = service((_, _) async {
        if (fail) throw StateError('transport');
        return [listing('a', opening: null)];
      });
      final place = const PlaceIntent(
        kind: PlaceKind.providerReference,
        provider: 'google_places_sdk',
        providerPlaceId: 'a',
      );
      await expectLater(source.hydrate(place), throwsA(isA<PlanningFailure>()));
      expect(
        source.hoursStatus(place).day('2030-01-01').state,
        HoursState.failed,
      );
      fail = false;
      await source.retryHours(place);
      expect(
        source.hoursStatus(place).day('2030-01-01').state,
        HoursState.notProvided,
      );
    },
  );
  test(
    'enriched search/details reserve their conservative per-service estimates',
    () async {
      String? stored;
      final budget = PlanningBudget(
        read: () async => stored,
        write: (v) async => stored = v,
      );
      final source = service(
        (method, _) async => [listing('a', enriched: method != 'search')],
        budget: budget,
      );
      final place = (await search(source)).candidates.single.place;
      await source.hydrate(place);
      final services =
          ((jsonDecode(stored!) as Map)['testing'] as Map)['services'] as Map;
      expect(services['places_35000'], 70000);
      expect(services['places_20000'], 20000);
    },
  );
  test(
    'joint solve avoids closed-at-arrival branch and refinement rechecks closing',
    () async {
      final source = service(
        (_, _) async => [
          listing('late', opening: 12),
          listing('early', opening: 8, closing: 10),
        ],
      );
      final candidates = (await search(source)).candidates;
      final roads = ShiftedRoads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture().copyWith(
          departure: 540,
          deadline: 900,
          errands: [const Errand(id: 'a', title: 'Gym', durationMinutes: 15)],
        ),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: source,
        solver: (input) async => solveDay(input),
      );
      addTearDown(model.dispose);
      await model.understand();
      model.applyReview();
      model.found('a', candidates);
      await model.calculate();
      expect(model.proposalReady, isTrue);
      expect(model.result!.schedule.stops.single.placeKey, 'google:early');
      model.overridePlace('a', model.displayChoices['a']!);
      model.result = null;
      roads.shift = true;
      await model.calculate();
      expect(model.result, isNull);
      expect(model.recommendationFailure!.kind, 'business_hours');
      expect(model.error, contains('Gym'));
      expect(model.displayChoices['a']!.providerPlaceId, 'early');
      expect(model.overrides['a'], 'google:early');
    },
  );
}
