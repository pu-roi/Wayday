import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test('words and category cannot silently decide destination intent', () {
    for (final title in [
      'Pick up laundry detergent',
      'Kunin ang pagkain',
      'Meet my boss',
      'Tingnan ang court',
    ]) {
      final e = Errand(id: 'a', title: title);
      const unknown = ErrandNeed(id: 'a', query: 'place', category: 'meeting');
      expect(needsActualLocation(e, unknown), isFalse);
      expect(needsPlaceRecommendation(e, unknown), isFalse);
      expect(needsLocationUnderstanding(e, unknown), isTrue);
      final flexible = unknown.copyWith(
        locationIntent: LocationIntent.flexible,
      );
      expect(needsPlaceRecommendation(e, flexible), isTrue);
      expect(needsActualLocation(e, flexible), isFalse);
    }
  });

  test(
    'explicit points and references take precedence over model flexibility',
    () {
      final e = fixture().errands.first;
      const flexible = ErrandNeed(
        id: 'a',
        query: 'grocery',
        locationIntent: LocationIntent.flexible,
      );
      expect(needsLocationUnderstanding(e, flexible), isFalse);
      expect(needsActualLocation(e, flexible), isFalse);
      expect(needsPlaceRecommendation(e, flexible), isFalse);
      final expired = e.copyWith(
        placeIntent: const PlaceIntent(
          kind: PlaceKind.providerReference,
          provider: 'google_places_sdk',
          providerPlaceId: 'chosen',
          label: 'My shop',
        ),
      );
      expect(needsActualLocation(expired, flexible), isTrue);
      expect(needsPlaceRecommendation(expired, flexible), isFalse);
    },
  );

  test(
    'a saved location answer can change the interpretation in either direction',
    () {
      const need = ErrandNeed(
        id: 'a',
        query: 'venue',
        category: 'meeting',
        requiresSpecificLocation: true,
        locationIntent: LocationIntent.specific,
      );
      const flexible = ClarificationResolution(
        outcome: 'flexible',
        kind: 'location',
        summary: 'Recommend a suitable venue',
        locationIntent: LocationIntent.flexible,
      );
      final changed = flexible.refine(need);
      expect(changed.locationIntent, LocationIntent.flexible);
      expect(
        needsPlaceRecommendation(
          const Errand(id: 'a', title: 'Arrange a meeting'),
          changed,
        ),
        isTrue,
      );
      const specific = ClarificationResolution(
        outcome: 'resolved',
        kind: 'location',
        summary: 'The existing meeting venue',
        locationIntent: LocationIntent.specific,
      );
      expect(specific.refine(changed).locationIntent, LocationIntent.specific);
    },
  );
}
