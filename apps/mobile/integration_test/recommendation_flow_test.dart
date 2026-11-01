import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
import 'package:wayday/features/planning/data/reusable_trip_repository.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import '../test/helpers/planning_fixtures.dart';

/// Disposable .maptest only. No keys, fixture journal, live search or generation.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android automatic recommendation, Back and retained local choice',
    (tester) async {
      final identity = await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity');
      expect(identity!['package'], endsWith('.maptest'));
      await expectLater(
        const MethodChannel(
          'wayday/recommendations',
        ).invokeMethod<void>('search', {'query': ''}),
        throwsA(isA<PlatformException>()),
      );
      final db = WaydayDatabase(),
          drafts = SqliteRecommendationDraftRepository(db),
          roads = Roads();
      final reusable = SqliteReusableTripRepository(
        db,
        (_) => GooglePinLease(),
      );
      addTearDown(db.close);
      addTearDown(roads.client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interpreterProvider.overrideWithValue(Interpreter()),
            planningRoadsProvider.overrideWithValue(roads),
            planningSolverProvider.overrideWithValue(
              (input) async => solveDay(input),
            ),
            recommendationDraftRepositoryProvider.overrideWithValue(drafts),
            reusableTripRepositoryProvider.overrideWithValue(reusable),
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(initialData: fixture()),
            ),
          ],
          child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build recommendations'));
      await tester.pumpAndSettle();
      expect(find.text('Your plan'), findsOneWidget);
      expect(find.text('Trip details'), findsNothing);
      expect(find.text('Search for a place'), findsNothing);
      expect(find.text('Use name only'), findsNothing);
      await tester.tap(find.text('Change').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Errand 1 of 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Next errand'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Errand 2 of 2'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Choose a place'), findsNothing);
      expect(find.text('Your plan'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Review errands'), findsOneWidget);
      await tester.tap(find.text('Build recommendations'));
      await tester.pumpAndSettle();
      expect(find.text('Start trip'), findsOneWidget);
      await tester.tap(find.text('Save for reuse'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Synthetic reusable errands',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      final saved = await tester.runAsync(reusable.read);
      expect(
        saved!.where((t) => t.name == 'Synthetic reusable errands'),
        isNotEmpty,
      );
      expect(
        (await db.select(db.recommendationDrafts).get()).single.payload,
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      debugPrint('WAYDAY_RECOMMENDATION_FLOW_PASSED');
    },
  );
}
