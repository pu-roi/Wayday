import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  GoogleRecommendationDiscovery create(int count, void Function() called) {
    final pins = GooglePinCache(read: () async => null, write: (_) async {});
    addTearDown(pins.dispose);
    return GoogleRecommendationDiscovery(
      QuotaLedger(read: () async => null, write: (_) async {}),
      pins,
      invoke: (_, args) async {
        called();
        return List.generate(
          count,
          (i) => {
            'id': 'gym$i',
            'name': 'Gym branch $i',
            'latitude': 14.58 + i * .0001,
            'longitude': 121.06,
            'country': 'PH',
            'types': ['gym'],
            'at': DateTime.now().millisecondsSinceEpoch,
          },
        );
      },
    );
  }

  const need = ErrandNeed(
    id: 'gym',
    query: 'gym',
    locationIntent: LocationIntent.flexible,
  );
  test(
    'more suggestions reuse unused records without replacing the shortlist',
    () async {
      var calls = 0;
      final service = create(8, () => calls++);
      final original = await service.discover(
        need,
        polyline: 'seed',
        anchors: [pin],
        limit: 3,
        cancelled: () => false,
      );
      final excluded = original.candidates.map((p) => p.key).toSet();
      final browser = service;
      final more = await browser.moreAlternatives(
        need,
        polyline: 'seed',
        anchors: [pin],
        excludedKeys: excluded,
        limit: 3,
        cancelled: () => false,
      );
      expect(more.candidates.length, 3);
      expect(more.candidates.any((p) => excluded.contains(p.key)), isFalse);
      expect(original.candidates.length, 3);
      expect(calls, 1);
      expect(more.exhausted, isFalse);
    },
  );
  test(
    'all fresh contexts are browsed before spending on an unused anchor',
    () async {
      var calls = 0;
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, args) async {
          calls++;
          final prefix = args.containsKey('polyline') ? 'corridor' : 'anchor';
          return List.generate(
            3,
            (i) => {
              'id': '$prefix$i',
              'name': 'Gym $prefix $i',
              'latitude': 14.58 + i * .0001,
              'longitude': 121.06,
              'country': 'PH',
              'types': ['gym'],
              'at': DateTime.now().millisecondsSinceEpoch,
            },
          );
        },
      );
      // Another matching search has already populated the second anchor.
      const second = PlaceIntent(
        kind: PlaceKind.specific,
        latitude: 14.6,
        longitude: 121.08,
      );
      await service.discover(
        need,
        polyline: null,
        anchors: [second],
        limit: 3,
        cancelled: () => false,
      );
      final original = await service.discover(
        need,
        polyline: 'seed',
        anchors: [pin, second],
        limit: 3,
        cancelled: () => false,
      );
      final batch = await service.moreAlternatives(
        need,
        polyline: 'seed',
        anchors: [pin, second],
        limit: 3,
        excludedKeys: original.candidates.map((p) => p.key).toSet(),
        cancelled: () => false,
      );
      expect(batch.candidates.length, 3);
      expect(
        batch.candidates.every((p) => p.key.startsWith('google:anchor')),
        isTrue,
      );
      expect(calls, 2);
      expect(batch.exhausted, isFalse);
    },
  );
  test(
    'exhaustion deduplicates bounded searches and does not repeat them',
    () async {
      var calls = 0;
      final service = create(3, () => calls++);
      final original = await service.discover(
        need,
        polyline: 'seed',
        anchors: [pin, pin],
        limit: 3,
        cancelled: () => false,
      );
      final Set<String> excluded = {for (final p in original.candidates) p.key};
      final more = await service.moreAlternatives(
        need,
        polyline: 'seed',
        anchors: [pin, pin],
        excludedKeys: excluded,
        limit: 3,
        cancelled: () => false,
      );
      expect(more.candidates, isEmpty);
      expect(more.exhausted, isTrue);
      expect(calls, 2);
      await service.moreAlternatives(
        need,
        polyline: 'seed',
        anchors: [pin, pin],
        excludedKeys: excluded,
        limit: 3,
        cancelled: () => false,
      );
      expect(calls, 2);
    },
  );
}
