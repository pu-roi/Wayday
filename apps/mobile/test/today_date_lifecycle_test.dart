import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/presentation/today_view.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  testWidgets(
    'an accepted current trip protects an otherwise empty Today date',
    (tester) async {
      final trips = MemoryItineraryRepository();
      await trips.save(
        AcceptedItinerary(
          day: fixture(),
          stops: [
            ItineraryStop(pin, ['a', 'b']),
          ],
          acceptedAt: DateTime.now(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          dayRepositoryProvider.overrideWithValue(
            MemoryDayRepository(
              initialData: DayPlan(errands: [], date: '2026-10-31'),
            ),
          ),
          todayClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 1)),
          itineraryRepositoryProvider.overrideWithValue(trips),
          placeMapBuilderProvider.overrideWithValue(
            (_) => const SizedBox.expand(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildTheme(), home: const TodayView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).date, '2026-10-31');
      expect(find.text('Current trip'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'midnight refreshes only an empty form and clear resets a chosen date',
    (tester) async {
      var now = DateTime.utc(2026, 10, 31, 15, 59, 59);
      final repository = MemoryDayRepository(
        initialData: DayPlan(errands: [], date: '2026-10-31'),
      );
      final container = ProviderContainer(
        overrides: [
          dayRepositoryProvider.overrideWithValue(repository),
          todayClockProvider.overrideWithValue(() => now),
          itineraryRepositoryProvider.overrideWithValue(
            MemoryItineraryRepository(),
          ),
          placeMapBuilderProvider.overrideWithValue(
            (_) => const SizedBox.expand(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildTheme(), home: const TodayView()),
        ),
      );
      await tester.pumpAndSettle();
      now = DateTime.utc(2026, 10, 31, 16, 0, 1);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).date, '2026-11-01');
      final controller = container.read(todayProvider.notifier);
      controller.setDate(DateTime(2026, 11, 5));
      controller.refreshDefaultDate(now);
      expect(container.read(todayProvider).date, '2026-11-05');
      controller.clear();
      expect(container.read(todayProvider).date, '2026-11-01');
      expect(container.read(todayProvider).dateSelected, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
