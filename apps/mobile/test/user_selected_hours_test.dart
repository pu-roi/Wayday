import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';
import 'recommendation_flow_test.dart' show Discovery;

// Public-place timing scenario with synthetic identities, coordinates and roads.
// No phone database, native journal or personal endpoint is included.
class _HoursDiscovery extends Discovery {
  final at = DateTime.now();
  final leases = <String, GooglePinLease>{};
  final windows = {
    'campus': [540, 1020],
    'pickup': [720, 1320],
    'lunch': [600, 1320],
    'bank': [510, 1050],
    'groceries': [390, 1320],
  };
  PlaceIntent place(String id) => PlaceIntent(
    provider: 'google_places_sdk',
    providerPlaceId: id,
    googlePin: leases.putIfAbsent(
      id,
      () => GooglePinLease()
        ..acquiredAt = DateTime.now()
        ..latitude = 14.58
        ..longitude = 121.06,
    ),
  );
  @override
  RecommendationPlace? metadata(PlaceIntent place) {
    final id = place.providerPlaceId;
    if (id == null) return null;
    final window = windows[id]!;
    return RecommendationPlace(
      id: id,
      name: 'Fixture $id',
      latitude: 14.58,
      longitude: 121.06,
      acquiredAt: at,
      hours: BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: at,
        regular: {
          'periods': [
            for (var d = 0; d < 7; d++)
              {
                'open': {
                  'day': d,
                  'hour': window[0] ~/ 60,
                  'minute': window[0] % 60,
                },
                'close': {
                  'day': d,
                  'hour': window[1] ~/ 60,
                  'minute': window[1] % 60,
                },
              },
          ],
        },
      ),
    );
  }

  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) async => metadata(place);
}

class _CountedRoads extends Roads {
  int matrices = 0, refinements = 0;
  @override
  Future<Map<String, dynamic>> matrix(
    DayPlan day,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    matrices++;
    return super.matrix(day, points, cancelled: cancelled);
  }

  @override
  Future<RefinedPlan> refine(
    DayPlan day,
    DaySchedule initial,
    List<PlanCandidate> points, {
    bool Function()? cancelled,
  }) async {
    refinements++;
    return RefinedPlan(initial, [
      [
        [14.58, 121.06],
        [14.59, 121.07],
      ],
    ], false);
  }
}

PlanningRoads _transportRoads() => PlanningRoads(
  MockClient((request) async {
    final data = jsonDecode(request.body) as Map;
    if (request.url.path.contains('computeRouteMatrix')) {
      return http.Response(
        jsonEncode([
          for (var a = 0; a < (data['origins'] as List).length; a++)
            for (var b = 0; b < (data['destinations'] as List).length; b++)
              {
                'originIndex': a,
                'destinationIndex': b,
                'condition': 'ROUTE_EXISTS',
                'duration': '60s',
                'distanceMeters': 100,
              },
        ]),
        200,
      );
    }
    return http.Response(
      jsonEncode({
        'routes': [
          {
            'duration': '60s',
            'distanceMeters': 100,
            'polyline': {'encodedPolyline': '??AA'},
          },
        ],
      }),
      200,
    );
  }),
  PlanningBudget(read: () async => null, write: (_) async {}),
  apiKey: 'fixture',
  identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
);

void main() {
  test('an older solve cannot replace a newer explicit place choice', () async {
    final discovery = _HoursDiscovery(), roads = _CountedRoads();
    addTearDown(roads.client.close);
    final started = Completer<void>();
    final response = Completer<Map<String, dynamic>>();
    Map<String, dynamic>? solving;
    final model = PlanningController(
      fixture().copyWith(
        departure: 360,
        errands: [
          Errand(
            id: 'campus',
            title: 'Campus event',
            timing: TimingRule.at,
            minute: 510,
            placeIntent: discovery.place('campus'),
          ),
        ],
      ),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
      discovery: discovery,
      solver: (input) {
        solving = input;
        started.complete();
        return response.future;
      },
    );
    addTearDown(model.dispose);
    await model.understand();
    model.applyReview();
    final calculation = model.calculate();
    await started.future;
    model.chooseAlternative('campus', 'google:campus');
    response.complete(solveDay(solving!));
    await calculation;
    expect(model.result, isNull);
    expect(model.proposalReady, isFalse);
    expect(roads.refinements, 0);
    expect(model.hoursAreAdvisory('campus'), isTrue);
  });

  test(
    'recommended campus stays blocked until the user explicitly chooses it',
    () async {
      final discovery = _HoursDiscovery(), roads = _CountedRoads();
      addTearDown(roads.client.close);
      final drafts = MemoryRecommendationDraftRepository();
      final day = fixture().copyWith(
        departure: 360,
        errands: const [
          Errand(
            id: 'campus',
            title: 'Campus event',
            timing: TimingRule.at,
            minute: 510,
          ),
          Errand(id: 'bank', title: 'Bank'),
        ],
      );
      PlanningController controller() => PlanningController(
        day,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: discovery,
        drafts: drafts,
        solver: (input) async => solveDay(input),
      );
      final model = controller();
      addTearDown(model.dispose);
      await model.understand();
      model.applyReview();
      model.found('campus', [
        PlanCandidate(
          key: 'google:campus',
          place: discovery.place('campus'),
          errandIds: {'campus'},
        ),
      ]);
      // Replacing another errand pins this automatic result for stability.
      model.replacePlannedPlace('bank', discovery.place('bank'));
      expect(model.overrides.containsKey('campus'), isTrue);
      expect(model.hoursAreAdvisory('campus'), isFalse);
      expect(await model.saveRecommendationDraft(), isTrue);
      final reopened = controller();
      addTearDown(reopened.dispose);
      await reopened.understand();
      reopened.applyReview();
      await reopened.restoreRecommendationDraft();
      expect(reopened.hoursAreAdvisory('campus'), isFalse);
      expect(reopened.hoursAreAdvisory('bank'), isTrue);
      await model.calculate();
      expect(model.recommendationFailure!.kind, 'business_hours');
      expect(roads.matrices, 0);
      model.overridePlace('campus', discovery.place('campus'));
      await model.calculate();
      expect(model.error, isNull);
      expect(model.proposalReady, isTrue);
      expect(roads.matrices, 1);
      final selected = controller();
      addTearDown(selected.dispose);
      await selected.understand();
      selected.applyReview();
      await selected.restoreRecommendationDraft();
      expect(selected.hoursAreAdvisory('campus'), isTrue);
    },
  );

  for (final recommendedMinute in [510, 570]) {
    test(
      'advisory hours remain task-specific at a mixed shared stop at $recommendedMinute',
      () {
        final data = <String, dynamic>{
          'errands': [
            const Errand(
              id: 'fixed',
              title: 'User event',
              timing: TimingRule.at,
              minute: 490,
            ).toJson(),
            Errand(
              id: 'recommended',
              title: 'Service',
              timing: TimingRule.at,
              minute: recommendedMinute,
              afterErrandIds: ['fixed'],
            ).toJson(),
          ],
          'keys': ['start', 'campus', 'end'],
          'matrix': [
            [0, 0, 60],
            [60, 0, 60],
            [60, 60, 0],
          ],
          'start': 'start',
          'end': 'end',
          'departure': 360 * 60,
          'deadline': 1200 * 60,
          'options': {
            'fixed': ['campus'],
            'recommended': ['campus'],
          },
          'hours': {
            'campus': [
              [540 * 60, 1020 * 60],
            ],
          },
          'hoursAdvisoryErrands': ['fixed'],
        };
        final solved = solveDay(data);
        if (recommendedMinute == 510) {
          expect(solved['error'], 'conflict');
        } else {
          expect(solved['error'], isNull);
          final schedule = DaySchedule.fromJson(
            solved['schedule'] as Map<String, dynamic>,
          );
          expect(schedule.stops.length, 1);
          expect(validateSchedule(data, schedule), isNull);
          expect(
            validateSchedule({
              ...data,
              'hoursAdvisoryErrands': <String>[],
            }, schedule),
            'The visit is outside known business hours.',
          );
        }
      },
    );
  }

  for (final realAdapter in [false, true]) {
    test(
      'five errands retain an 8:30 user campus event despite reported 9:00 opening, real adapter=$realAdapter',
      () async {
        final discovery = _HoursDiscovery();
        final roads = realAdapter ? _transportRoads() : _CountedRoads();
        addTearDown(roads.client.close);
        final source = fixture().copyWith(
          departure: 390,
          deadline: 1200,
          fromPlace: discovery.place('campus'),
          errands: [
            Errand(
              id: 'campus',
              title: 'Campus event',
              timing: TimingRule.at,
              minute: 510,
              placeIntent: discovery.place('campus'),
            ),
            Errand(
              id: 'pickup',
              title: 'Pick up companion',
              timing: TimingRule.at,
              minute: 900,
              placeIntent: discovery.place('pickup'),
            ),
            const Errand(id: 'lunch', title: 'Lunch'),
            const Errand(id: 'bank', title: 'Bank'),
            const Errand(id: 'groceries', title: 'Groceries'),
          ],
        );
        final repository = MemoryItineraryRepository();
        Map<String, dynamic>? solverInput;
        final model = PlanningController(
          source,
          Interpreter(),
          roads,
          repository,
          discovery: discovery,
          solver: (input) async {
            solverInput = input;
            return solveDay(input);
          },
        );
        addTearDown(model.dispose);
        await model.understand();
        model.applyReview();
        for (final id in ['lunch', 'bank', 'groceries']) {
          model.found(id, [
            PlanCandidate(
              key: 'google:$id',
              place: discovery.place(id),
              errandIds: {id},
            ),
          ]);
        }
        await model.calculate();
        expect(model.error, isNull);
        expect(model.proposalReady, isTrue);
        if (roads is _CountedRoads) {
          expect(roads.matrices, 1);
          expect(roads.refinements, 1);
        }
        final schedule = model.result!.schedule;
        expect(validateSchedule(solverInput!, schedule), isNull);
        final tasks = {
          for (final s in schedule.stops)
            for (final t in s.tasks) t.errandId: t,
        };
        expect(tasks.keys.toSet(), {
          'campus',
          'pickup',
          'lunch',
          'bank',
          'groceries',
        });
        expect(tasks['campus']!.start, 510 * 60);
        expect(tasks['pickup']!.start, 900 * 60);
        for (final id in ['lunch', 'bank', 'groceries']) {
          final window = discovery.windows[id]!;
          expect(tasks[id]!.start, greaterThanOrEqualTo(window[0] * 60));
          expect(tasks[id]!.finish + 300, lessThanOrEqualTo(window[1] * 60));
        }
        expect(model.result!.geometry, isNotEmpty);
        expect(
          (await model.accept(0, 0)).stops.expand((s) => s.errandIds).length,
          5,
        );
      },
    );
  }
}
