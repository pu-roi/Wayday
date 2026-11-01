import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';

List<PlanCandidate> points(int count) => List.generate(
  count,
  (i) => PlanCandidate(
    key: i == 0
        ? '@start'
        : i == count - 1
        ? '@end'
        : 'p$i',
    place: PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Point $i',
      latitude: 14.5 + i / 1000,
      longitude: 121,
    ),
    errandIds: i == 0 || i == count - 1 ? {} : {'e$i'},
  ),
);
http.Response matrixResponse(Map<String, dynamic> data) => http.Response(
  jsonEncode([
    for (var a = 0; a < (data['origins'] as List).length; a++)
      for (var b = 0; b < (data['destinations'] as List).length; b++)
        {
          'originIndex': a,
          'destinationIndex': b,
          'condition': 'ROUTE_EXISTS',
          'duration': '${100 + a * 10 + b}s',
          'distanceMeters': 50,
        },
  ]),
  200,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final day = DayPlan(
    errands: [],
    date: '2030-01-01',
    profile: TravelProfile.walk,
  );
  test(
    'trimmed acquisition preserves the dense solver branch and order result',
    () async {
      final selected = points(9);
      int? cost(int a, int b) => a == b
          ? 0
          : a == 3 && b == 6
          ? null
          : 30 + ((a * 11 + b * 7) % 17) * 30;
      int index(dynamic waypoint) {
        final location = (waypoint as Map)['location'] as Map;
        final latitude = (location['latLng'] as Map)['latitude'] as num;
        return (latitude * 1000).round() - 14500;
      }

      final roads = PlanningRoads(
        MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          final origins = data['origins'] as List,
              destinations = data['destinations'] as List;
          return http.Response(
            jsonEncode([
              for (var a = 0; a < origins.length; a++)
                for (var b = 0; b < destinations.length; b++)
                  {
                    'originIndex': a,
                    'destinationIndex': b,
                    'condition':
                        cost(
                              index(origins[a]['waypoint']),
                              index(destinations[b]['waypoint']),
                            ) ==
                            null
                        ? 'ROUTE_NOT_FOUND'
                        : 'ROUTE_EXISTS',
                    'duration':
                        '${cost(index(origins[a]['waypoint']), index(destinations[b]['waypoint'])) ?? 0}s',
                  },
            ]),
            200,
          );
        }),
        PlanningBudget(read: () async => null, write: (_) async {}),
        apiKey: 'fixture',
        identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
      );
      final optimized = await roads.matrix(day, selected);
      final input = {
        'errands': [
          for (final id in ['laundry', 'gym', 'grocery'])
            Errand(id: id, title: id).toJson(),
        ],
        'keys': selected.map((p) => p.key).toList(),
        'matrix': optimized['matrix'],
        'departure': 36000,
        'deadline': 64800,
        'start': '@start',
        'end': '@end',
        'options': {
          'laundry': ['p1'],
          'gym': ['p2', 'p3', 'p4'],
          'grocery': ['p5', 'p6', 'p7'],
        },
      };
      final dense = List.generate(
        9,
        (a) => List.generate(9, (b) => cost(a, b)),
      );
      expect(
        solveDay(input)['schedule'],
        solveDay({...input, 'matrix': dense})['schedule'],
      );
    },
  );
  test(
    'nine points request 64 elements and replacement reuses directed pairs',
    () async {
      var elements = 0;
      final roads = PlanningRoads(
        MockClient((request) async {
          final data = jsonDecode(request.body) as Map<String, dynamic>;
          elements +=
              (data['origins'] as List).length *
              (data['destinations'] as List).length;
          return matrixResponse(data);
        }),
        PlanningBudget(read: () async => null, write: (_) async {}),
        apiKey: 'fixture',
        identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
      );
      final original = points(9);
      final first = await roads.matrix(day, original);
      expect(elements, 64);
      expect((first['matrix'] as List)[1][0], isNull);
      expect((first['matrix'] as List)[8][1], isNull);
      await roads.matrix(day, original);
      expect(elements, 64);
      final changed = [...original];
      changed[4] = PlanCandidate(
        key: 'replacement',
        place: const PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Replacement',
          latitude: 14.7,
          longitude: 121,
        ),
        errandIds: {'e4'},
      );
      await roads.matrix(day, changed);
      expect(elements - 64, lessThanOrEqualTo(17));
      final cached = await roads.matrix(day, original);
      expect(cached['matrix'], first['matrix']);
    },
  );
  test('cancelling before dispatch reserves no matrix units', () async {
    String? saved;
    final roads = PlanningRoads(
      MockClient((_) async => throw StateError('Must not dispatch')),
      PlanningBudget(
        read: () async => saved,
        write: (value) async => saved = value,
      ),
      apiKey: 'fixture',
      identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
    );
    await expectLater(
      roads.matrix(day, points(3), cancelled: () => true),
      throwsA(isA<PlanningFailure>()),
    );
    expect(saved, isNull);
  });
  test('overlapping identical matrices share provider work', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final roads = PlanningRoads(
      MockClient((request) async {
        calls++;
        return response.future;
      }),
      PlanningBudget(read: () async => null, write: (_) async {}),
      apiKey: 'fixture',
      identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
    );
    final a = roads.matrix(day, points(3));
    final b = roads.matrix(day, points(3));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    response.complete(
      matrixResponse({
        'origins': [0, 1],
        'destinations': [1, 2],
      }),
    );
    await Future.wait([a, b]);
    expect(calls, 1);
  });
  test(
    'a timeout retry attaches to the active request without another charge',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      String? saved;
      final roads = PlanningRoads(
        MockClient((_) {
          calls++;
          return response.future;
        }),
        PlanningBudget(read: () async => saved, write: (v) async => saved = v),
        apiKey: 'fixture',
        identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
        requestTimeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        roads.matrix(day, points(3)),
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'timeout'),
        ),
      );
      final retry = roads.matrix(day, points(3));
      response.complete(
        matrixResponse({
          'origins': [0, 1],
          'destinations': [1, 2],
        }),
      );
      await retry;
      expect(calls, 1);
      expect(jsonDecode(saved!)['testing']['usedMicros'], 20000);
    },
  );
  test(
    'mode changes and background invalidation cannot reuse old road pairs',
    () async {
      var calls = 0;
      final roads = PlanningRoads(
        MockClient((r) async {
          calls++;
          return matrixResponse(jsonDecode(r.body) as Map<String, dynamic>);
        }),
        PlanningBudget(read: () async => null, write: (_) async {}),
        apiKey: 'fixture',
        identity: () async => {'package': 'fixture', 'certificate': 'fixture'},
      );
      await roads.matrix(day, points(3));
      await roads.matrix(day.copyWith(profile: TravelProfile.sedan), points(3));
      roads.invalidate();
      await roads.matrix(day, points(3));
      expect(calls, 3);
    },
  );
}
