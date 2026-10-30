import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test(
    'an existing laundry pickup cannot be replaced by another laundry shop',
    () {
      expect(
        needsActualLocation(
          const Errand(id: 'x', title: 'Pick up laundry'),
          const ErrandNeed(id: 'x', query: 'laundry shop'),
        ),
        isTrue,
      );
      expect(
        needsActualLocation(
          const Errand(id: 'x', title: 'Find a laundry shop'),
          const ErrandNeed(id: 'x', query: 'laundry shop'),
        ),
        isFalse,
      );
    },
  );
  test(
    'SDK and legacy references share identity and never serialize provider text',
    () {
      final lease = GooglePinLease()
        ..latitude = 14.58
        ..longitude = 121.06
        ..acquiredAt = DateTime.now();
      final sdk = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'My gym',
        provider: 'google_places_sdk',
        providerPlaceId: 'gym',
        googlePin: lease,
      );
      final legacy = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'Gym search',
        provider: 'google_ui_kit',
        providerPlaceId: 'gym',
        googlePin: lease,
      );
      expect(sdk.isGoogle, isTrue);
      expect(placeKey(sdk), placeKey(legacy));
      expect(sdk.toJson().containsKey('latitude'), isFalse);
      expect(sdk.toJson().containsKey('address'), isFalse);
      expect(
        PlaceIntent.fromJson(
          sdk.toJson(),
          resolveGooglePin: (_) => lease,
        ).hasCoordinates,
        isTrue,
      );
    },
  );
  test(
    'only real, named, located, eligible businesses enter recommendation pools',
    () {
      final at = DateTime.now().millisecondsSinceEpoch;
      Map<String, Object?> raw(String id) => {
        'id': id,
        'name': 'Laundry $id',
        'latitude': 14.58,
        'longitude': 121.06,
        'types': ['laundry'],
        'at': at,
      };
      expect(RecommendationPlace.fromJson(raw('one')).eligible, isTrue);
      expect(
        RecommendationPlace.fromJson({
          ...raw('closed'),
          'status': 'CLOSED_PERMANENTLY',
        }).eligible,
        isFalse,
      );
      expect(
        RecommendationPlace.fromJson({
          ...raw('street'),
          'types': ['route'],
        }).eligible,
        isFalse,
      );
      expect(
        RecommendationPlace.fromJson({
          ...raw('foreign'),
          'country': 'US',
        }).eligible,
        isFalse,
      );
      expect(
        RecommendationPlace.fromJson({...raw('unnamed'), 'name': ''}).eligible,
        isFalse,
      );
      expect(
        () => RecommendationPlace.fromJson({...raw('bad'), 'latitude': 1000}),
        throwsFormatException,
      );
    },
  );
  test('detours use directed road times and exclude service duration', () {
    final times = [
      [0, 120, 90],
      [400, 0, 100],
      [90, 600, 0],
    ];
    expect(addedTravelSeconds(times, 0, 1, 2), 130);
    expect(addedTravelSeconds(times, 2, 1, 0), 910);
    expect(
      addedTravelSeconds(
        [
          [0, null],
          [2, 0],
        ],
        0,
        1,
        0,
      ),
      isNull,
    );
  });
}
