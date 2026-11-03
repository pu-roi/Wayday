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

class ArrivalRoads extends Roads {
  ArrivalRoads(this.seconds);
  final int seconds;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async => {
    'matrix': List.generate(
      points.length,
      (i) => List.generate(points.length, (j) => i == j ? 0 : seconds),
    ),
    'fallback': false,
  };
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
  for (final timing in [
    TimingRule.at,
    TimingRule.arriveBy,
    TimingRule.finishBefore,
  ]) {
    test(
      'shortlist keeps the branch that can serve a future ${timing.name} errand',
      () async {
        final appointment = timing == TimingRule.at ? 840 : 600;
        final errand = Errand(
          id: 'a',
          title: 'Gym',
          timing: timing,
          minute: appointment,
          durationMinutes: 30,
        );
        final source = service(
          (_, _) async => [
            for (var i = 0; i < 3; i++)
              timing == TimingRule.at
                  ? listing('a$i', opening: 8, closing: 12)
                  : listing('a$i', opening: 12, closing: 17),
            timing == TimingRule.at
                ? listing('z-compatible', opening: 13, closing: 17)
                : listing(
                    'z-compatible',
                    opening: 8,
                    closing: timing == TimingRule.arriveBy ? 12 : 10,
                  ),
          ],
        );
        final roads = Roads();
        addTearDown(roads.client.close);
        final model = PlanningController(
          fixture().copyWith(
            errands: [errand],
            departure: timing == TimingRule.arriveBy ? 590 : 540,
            deadline: 1080,
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
        final shortlisted = await search(
          source,
          hours: model.hoursQuery(errand),
        );
        expect(shortlisted.candidates.map((p) => p.key), [
          'google:z-compatible',
        ]);
        model.found('a', shortlisted.candidates);
        await model.calculate();
        expect(model.proposalReady, isTrue);
        final stop = model.result!.schedule.stops.single;
        expect(stop.placeKey, 'google:z-compatible');
        expect(stop.arrival, (timing == TimingRule.arriveBy ? 591 : 541) * 60);
        if (timing == TimingRule.at) {
          expect(stop.tasks.single.start, appointment * 60);
        } else if (timing == TimingRule.arriveBy) {
          expect(stop.arrival, lessThanOrEqualTo(appointment * 60));
          expect(stop.departure, greaterThan(appointment * 60));
        } else {
          expect(stop.departure, lessThanOrEqualTo(appointment * 60));
        }
      },
    );
  }
  for (final minutes in [1, 55]) {
    test(
      'future-date branch selection uses a $minutes minute estimated arrival and full visit',
      () async {
        final source = service(
          (_, _) async => [
            listing('a-early', opening: 8, closing: 10),
            listing('z-later', opening: 9, closing: 12),
          ],
        );
        final roads = ArrivalRoads(minutes * 60);
        addTearDown(roads.client.close);
        const errand = Errand(id: 'a', title: 'Gym', durationMinutes: 15);
        final model = PlanningController(
          fixture().copyWith(errands: [errand], departure: 540, deadline: 1080),
          Interpreter(),
          roads,
          MemoryItineraryRepository(),
          discovery: source,
          solver: (input) async => solveDay(input),
        );
        addTearDown(model.dispose);
        await model.understand();
        model.applyReview();
        model.found(
          'a',
          (await search(source, hours: model.hoursQuery(errand))).candidates,
        );
        await model.calculate();
        expect(model.proposalReady, isTrue);
        final stop = model.result!.schedule.stops.single;
        expect(
          stop.placeKey,
          minutes == 1 ? 'google:a-early' : 'google:z-later',
        );
        expect(stop.arrival, (540 + minutes) * 60);
        expect(stop.departure, stop.arrival + 20 * 60);
      },
    );
  }
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
      model.review();
      model.applyReview();
      model.result = null;
      roads.shift = true;
      await model.calculate();
      expect(model.result, isNull);
      expect(model.recommendationFailure!.kind, 'business_hours');
      expect(model.error, contains('Gym'));
      expect(model.displayChoices['a']!.providerPlaceId, 'early');
      expect(model.overrides, isEmpty);
    },
  );
}
