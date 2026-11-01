import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:drift/native.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import '../test/helpers/planning_fixtures.dart';

class LegacyUnderstanding implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async =>
      Interpretation(const [ErrandNeed(id: 'a', query: 'laundry shop')]);
}

class LocationCheck implements ClarificationResolver {
  int calls = 0;
  @override
  Future<ClarificationResolution> resolve(
    ClarificationContext context,
    String answer, {
    List<String> history = const [],
    bool retry = false,
    bool savedOnly = false,
  }) async {
    calls++;
    return const ClarificationResolution(
      outcome: 'resolved',
      kind: 'location',
      locationIntent: LocationIntent.specific,
      summary: 'Existing laundry collection',
    );
  }
}

/// Disposable .maptest, mocked interpretation/search/map/roads. No provisioning,
/// personal package operations or live paid requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android explicit location understanding, manual picker and durable result',
    (tester) async {
      final identity = await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity');
      expect(identity!['package'], endsWith('.maptest'));
      final db = WaydayDatabase(NativeDatabase.memory()),
          resolver = LocationCheck(),
          roads = Roads();
      addTearDown(db.close);
      addTearDown(roads.client.close);
      PlaceMapRequest? map;
      final source = fixture().copyWith(
        errands: const [Errand(id: 'a', title: 'pick up laundry')],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            interpreterProvider.overrideWithValue(LegacyUnderstanding()),
            clarificationResolverProvider.overrideWithValue(resolver),
            clarificationRepositoryProvider.overrideWithValue(
              SqliteClarificationRepository(db),
            ),
            planningRoadsProvider.overrideWithValue(roads),
            dayRepositoryProvider.overrideWithValue(
              MemoryDayRepository(initialData: source),
            ),
            placeMapBuilderProvider.overrideWithValue((request) {
              map = request;
              return const Center(child: Text('Synthetic manual map'));
            }),
          ],
          child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Needs your answer'), findsOneWidget);
      expect(find.text('Choose actual location'), findsNothing);
      expect(find.text('Recheck location needs with Gemini'), findsNothing);
      await tester.tap(
        find.text(
          'Do you have a specific place in mind, or should Wayday suggest one?',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'My clothes are already at my usual shop',
      );
    await tester.pumpAndSettle();
      await tester.tap(find.text('Use answer'));
      // A settled frame does not imply the native SQLite write has completed.
      final answerDeadline = DateTime.now().add(const Duration(seconds: 15));
      while ((resolver.calls == 0 ||
              find.text('Use answer').evaluate().isNotEmpty) &&
          DateTime.now().isBefore(answerDeadline)) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      expect(resolver.calls, 1);
      expect(find.text('Choose actual location'), findsOneWidget);
      await tester.ensureVisible(find.text('Choose actual location'));
      await tester.tap(find.text('Choose actual location'));
      await tester.pumpAndSettle();
      expect(map!.centerPicker, isTrue);
      expect(map!.focus?.hasCoordinates ?? false, isFalse);
      map!.onSelect!(14.58, 121.06);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(find.text('Review errands'), findsOneWidget);
      expect(find.text('Choose actual location'), findsNothing);
      expect(resolver.calls, 1);
      expect(
        (await db.select(db.clarificationSessions).get()).single.payload,
        contains('Existing laundry collection'),
      );
      expect(tester.takeException(), isNull);
      debugPrint('WAYDAY_LOCATION_UNDERSTANDING_PASSED');
    },
  );
}
