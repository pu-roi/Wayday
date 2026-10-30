import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/planning/data/recommendation_draft_repository.dart';
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
      expect(find.text('Recommended places'), findsOneWidget);
      expect(find.text('Search for a place'), findsNothing);
      expect(find.text('Use name only'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Review errands'), findsOneWidget);
      await tester.tap(find.text('Build recommendations'));
      await tester.pumpAndSettle();
      expect(find.text('Next: see my day'), findsOneWidget);
      expect(
        (await db.select(db.recommendationDrafts).get()).single.payload,
        isNotEmpty,
      );
      expect(tester.takeException(), isNull);
      debugPrint('WAYDAY_RECOMMENDATION_FLOW_PASSED');
    },
  );
}
