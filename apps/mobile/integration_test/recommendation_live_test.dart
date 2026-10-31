import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';

class _KnownNeeds implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation(const [
    ErrandNeed(
      id: 'gym',
      query: 'gym',
      locationIntent: LocationIntent.flexible,
    ),
    ErrandNeed(
      id: 'groceries',
      query: 'supermarket',
      category: 'grocery',
      locationIntent: LocationIntent.flexible,
    ),
  ]);
}

/// Explicit, separately accounted live qualification. Never personal-phone data
/// or Gemini generation. Coordinates are public-area test points, not homes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bounded live Ugong-to-Palatiw-area recommendation rehearsal',
    (tester) async {
      final identity = await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity');
      expect(identity!['package'], endsWith('.maptest'));
      final status = await GoogleRecommendationDiscovery.channel
          .invokeMapMethod<String, Object?>('status');
      expect(status!['configured'], true);
      const start = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Ugong-area test start',
        latitude: 14.5849,
        longitude: 121.0568,
      );
      const end = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Palatiw-area test destination',
        latitude: 14.5675,
        longitude: 121.0836,
      );
      final pins = GooglePinCache();
      final budget = PlanningBudget(allocation: () async => 2000000);
        final discovery = GoogleRecommendationDiscovery(QuotaLedger(googleBudget: budget), pins);
      if (const bool.fromEnvironment('WAYDAY_LIVE_PLACES_ONLY')) {
        addTearDown(pins.dispose);
        for (final need in const [
          ErrandNeed(
            id: 'gym',
            query: 'gym',
            locationIntent: LocationIntent.flexible,
          ),
          ErrandNeed(
            id: 'groceries',
            query: 'supermarket',
            category: 'grocery',
            locationIntent: LocationIntent.flexible,
          ),
        ]) {
          try {
            final response = await discovery.discover(
              need,
              polyline: null,
              anchors: [start],
              limit: 3,
              cancelled: () => false,
            );
            expect(response.outcome, DiscoveryOutcome.found);
            expect(
              response.candidates.every(
                (p) => discovery.metadata(p.place)?.name.isNotEmpty == true,
              ),
              true,
            );
            debugPrint(
              'WAYDAY_LIVE_PLACES_PASSED category=${need.id} candidates=${response.candidates.length}',
            );
          } on RecommendationFailure catch (failure) {
            fail(
              'LIVE_PLACES_STOPPED kind=${failure.kind} operation=${failure.operation.name} status=${failure.providerStatus}',
            );
          }
        }
        return;
      }
      final roads = PlanningRoads(http.Client(), budget);
      final model = PlanningController(
        DayPlan(
          date: calendarDate(DateTime.now().add(const Duration(days: 1))),
          from: start.label,
          fromPlace: start,
          to: end.label,
          toPlace: end,
          departure: 600,
          deadline: 1080,
          profile: TravelProfile.sedan,
          errands: const [
            Errand(id: 'gym', title: 'go to gym'),
            Errand(id: 'groceries', title: 'groceries'),
          ],
        ),
        _KnownNeeds(),
        roads,
        MemoryItineraryRepository(),
        discovery: discovery,
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      addTearDown(pins.dispose);
      await model.understand();
      await model
          .buildRecommendations(); // One bounded build; no automatic retry.
      if (model.result == null) {
        final failure = model.recommendationFailure;
        fail(
        'LIVE_RECOMMENDATION_STOPPED kind=${failure?.kind} operation=${model.recommendationOperation?.name} status=${failure?.providerStatus}',
        );
      }
      expect(model.stage, PreparationStage.recommendations);
      for (final id in ['gym', 'groceries']) {
        final selected = model.candidates[id]!;
        expect(selected, isNotEmpty);
        expect(
          selected.every(
            (p) =>
                p.place.hasCoordinates &&
                discovery.metadata(p.place)?.name.isNotEmpty == true,
          ),
          true,
        );
      }
      expect(model.result!.legs, isNotEmpty);
      expect(model.result!.geometry, isNotEmpty);
      // Safe aggregate evidence only; no provider text, coordinates or key logs.
      debugPrint(
        'WAYDAY_LIVE_RECOMMENDATION_PASSED errands=2 stops=${model.result!.schedule.stops.length}',
      );
    },
    skip: !const bool.fromEnvironment('WAYDAY_LIVE_RECOMMENDATION_REHEARSAL'),
  );
}
