import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';

class _DirectHttp extends HttpOverrides {}

/// Explicit public-fixture adapter qualification only. Default regression skips.
/// At most 12 matrix elements and 3 route legs, stopping on the first failure.
void main() {
  test('bounded live Routes adapters for walking motorcycle and sedan', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final client = IOClient(HttpClient());
      final file = File('../../.tools/planner-live-road-accounting.json');
      final budget = PlanningBudget(
        read: () async => await file.exists() ? file.readAsString() : null,
        write: (text) => file.writeAsString(text, flush: true),
      );
      final roads = PlanningRoads(
        client,
        budget,
        identity: () async => {
          'package': 'dev.wayday.wayday',
          'certificate': const String.fromEnvironment('WAYDAY_PROBE_SHA1'),
        },
      );
      const points = [
        PlanCandidate(
          key: '@start',
          place: PlaceIntent(
            kind: PlaceKind.specific,
            label: 'Public fixture start',
            latitude: 14.5849,
            longitude: 121.0568,
          ),
          errandIds: {},
        ),
        PlanCandidate(
          key: '@end',
          place: PlaceIntent(
            kind: PlaceKind.specific,
            label: 'Public fixture end',
            latitude: 14.5810,
            longitude: 121.0552,
          ),
          errandIds: {},
        ),
      ];
      try {
        for (final mode in [
          TravelProfile.walk,
          TravelProfile.motor,
          TravelProfile.sedan,
        ]) {
          final now = DateTime.now().toUtc().add(const Duration(hours: 8));
          final date = now.hour >= 23 ? now.add(const Duration(days: 1)) : now;
          final start = now.hour >= 23 ? 480 : now.hour * 60 + now.minute + 5;
          final day = DayPlan(
            errands: [],
            date: calendarDate(date),
            departure: start,
            deadline: 1439,
            profile: mode,
          );
          final matrix = await roads.matrix(day, points);
          final value = ((matrix['matrix'] as List).first as List)[1] as int?;
          expect(value, isNotNull);
          final refined = await roads.refine(
            day,
            DaySchedule(
              stops: [],
              omitted: {},
              endArrival: start * 60 + value!,
              travelSeconds: value,
            ),
            points,
          );
          expect(refined.geometry, isNotEmpty);
          expect(
            refined.schedule.endArrival,
            lessThanOrEqualTo(day.deadline * 60),
          );
          debugPrint(
            'WAYDAY_LIVE_ROADS_ADAPTER_PASSED mode=${mode.name} matrixElements=4 routeLegs=1',
          );
        }
      } finally {
        client.close();
      }
    }, _DirectHttp());
  }, skip: !const bool.fromEnvironment('WAYDAY_LIVE_ROADS'));
}
