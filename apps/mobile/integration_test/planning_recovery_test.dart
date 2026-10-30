import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/review_trip_repository.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import '../test/helpers/planning_fixtures.dart';

/// Run only with tool/test-map.ps1. All services are synthetic, and the real
/// SQLite file belongs to the disposable .maptest package, never the owner app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android review trip settings survive view and database recreation',
    (tester) async {
      const channel = MethodChannel('wayday/planning');
      final identity = await channel.invokeMapMethod<String, String>(
        'identity',
      );
      expect(identity!['package'], endsWith('.maptest'));
      final before = await channel.invokeMapMethod<String, dynamic>(
        'geminiStatus',
      );
      final base = fixture();
      final source = base.copyWith(
            date: '2020-01-01',
            errands: [
              base.errands.first.copyWith(
                title: 'Pickup',
                timing: TimingRule.arriveBy,
                minute: 570,
              ),
            ],
          ),
          roads = Roads();
      var db = WaydayDatabase();
      await db.delete(db.reviewTrips).go();
      late SqliteReviewTripRepository trips;
      final today = MemoryDayRepository(initialData: source);
      Future<void> launch() async {
        trips = SqliteReviewTripRepository(db);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              dayRepositoryProvider.overrideWithValue(today),
              interpreterProvider.overrideWithValue(Interpreter()),
              planningRoadsProvider.overrideWithValue(roads),
              reviewTripRepositoryProvider.overrideWithValue(trips),
            ],
            child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
          ),
        );
        await tester.pumpAndSettle();
      }

      await launch();
      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final chosen = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model
          .day
          .date;
      await tester.tap(find.text('Departure'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('12:00 PM'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12:00 PM'));
      await tester.ensureVisible(find.text('Save time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      expect((await trips.read(source))!.departure, 720);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Next: find suitable places'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Edit Pickup'));
      await tester.tap(find.text('Edit Pickup'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('errand-time')));
      await tester.tap(find.byKey(const Key('errand-time')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('time-hour')), '2');
      await tester.tap(find.text('PM'));
      await tester.ensureVisible(find.text('Save time'));
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await trips.read(source))!.timingEdits['a']!.minute, 870);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await db.close();
      db = WaydayDatabase();
      await launch();
      final restored = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model
          .day;
      expect(restored.date, chosen);
      expect(restored.departure, 720);
      expect(restored.errands.single.minute, 870);
      expect(today.read().errands.single.minute, 570);
      expect(today.read().date, '2020-01-01');
      expect(today.read().departure, 510);
      final after = await channel.invokeMapMethod<String, dynamic>(
        'geminiStatus',
      );
      expect(after!['configured'], before!['configured']);
      expect(today.read().errands.single.minute, 570);
      debugPrint('WAYDAY_REVIEW_TRIP_ANDROID_RECREATION_PASSED requests=0');
      await tester.pumpWidget(const SizedBox.shrink());
      await db.close();
      roads.client.close();
    },
  );
}
