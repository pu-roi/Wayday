import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/place_hours.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'alternatives_sheet_test.dart' show Browser;
import 'helpers/planning_fixtures.dart';

class HoursBrowser extends Browser {
  late BusinessHours value;
  late DateTime acquired;
  String? status;
  @override
  RecommendationPlace metadata(PlaceIntent p) => RecommendationPlace(
    id: 'business',
    name: 'Fixture business',
    latitude: 14.58,
    longitude: 121.06,
    acquiredAt: acquired,
    hours: value,
    status: status,
  );
}

void main() {
  const place = PlaceIntent(
    provider: 'google_places_sdk',
    providerPlaceId: 'business',
  );
  Map<String, Object> point(int day, int hour, int minute) => {
    'day': day,
    'hour': hour,
    'minute': minute,
  };
  testWidgets(
    'current status updates at opening and closing without checking the future trip',
    (tester) async {
      var now = DateTime.utc(2026, 11, 1, 0, 59, 30); // 08:59 Manila.
      final browser = HoursBrowser()..acquired = now;
      browser.value = BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: now,
        coverageStart: '2026-11-01',
        current: {
          'periods': [
            {'open': point(0, 9, 0), 'close': point(0, 9, 1)},
            {'open': point(1, 9, 0), 'close': point(1, 21, 0)},
          ],
        },
      );
      final roads = Roads();
      final model = PlanningController(
        fixture().copyWith(date: '2026-11-02'),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: browser,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: PlaceHours(model: model, place: place, now: () => now),
          ),
        ),
      );
      expect(find.text('Closed now'), findsOneWidget);
      expect(find.textContaining('Hours for 2026-11-02'), findsOneWidget);
      expect(find.textContaining('planned visit'), findsNothing);
      now = DateTime.utc(2026, 11, 1, 1, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(find.text('Open now'), findsOneWidget);
      now = DateTime.utc(2026, 11, 1, 1, 1);
      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Closed now'), findsOneWidget);
      expect(browser.calls, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'usual hours and provider closure are distinct from confirmed current hours',
    (tester) async {
      final now = DateTime.utc(2026, 11, 1, 2);
      final browser = HoursBrowser()..acquired = now;
      browser.value = BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: now,
        regular: {
          'periods': [
            {'open': point(0, 9, 0), 'close': point(0, 21, 0)},
          ],
        },
      );
      final roads = Roads();
      final model = PlanningController(
        fixture().copyWith(date: '2026-11-01'),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: browser,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      Widget page() => MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: PlaceHours(model: model, place: place, now: () => now),
        ),
      );
      await tester.pumpWidget(page());
      expect(find.text('Usually open now'), findsOneWidget);
      browser.status = 'CLOSED_TEMPORARILY';
      await tester.pumpWidget(page());
      expect(find.text('Reported temporarily closed'), findsOneWidget);
      expect(find.text('Usually open now'), findsNothing);
      browser.status = null;
      browser.value = BusinessHours(version: 1, checkedAt: now);
      await tester.pumpWidget(page());
      expect(find.text('Hours not provided by Google Maps'), findsOneWidget);
      expect(find.text('Closed now'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
