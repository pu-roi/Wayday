import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/place_search_intent.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/place_suitability.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'automatic and alternative searches reject wholesale primary conflicts',
    () async {
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final discovery = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, args) async => [
          for (final primary in ['wholesaler', 'supermarket'])
            {
              'id': primary,
              'name': 'Synthetic $primary',
              'latitude': 14.58,
              'longitude': 121.06,
              'country': 'PH',
              'types': [primary, 'grocery_store'],
              'primaryType': primary,
              'at': DateTime.now().millisecondsSinceEpoch,
            },
        ],
      );
      final need = ErrandNeed(
        id: 'rice',
        query: 'rice',
        category: 'grocery',
        searchIntent: PlaceSearchIntent.fromJson({
          'version': 2,
          'variants': ['supermarket'],
          'preferredTypes': ['supermarket'],
          'fallbackTypes': ['grocery_store', 'market'],
          'excludedPrimaryTypes': ['wholesaler'],
        }),
      );
      final automatic = await discovery.discover(
        need,
        polyline: 'seed',
        anchors: [],
        limit: 3,
        cancelled: () => false,
      );
      final alternatives = await discovery.moreAlternatives(
        need,
        polyline: 'seed',
        anchors: [],
        excludedKeys: {},
        limit: 3,
        cancelled: () => false,
      );
      expect(automatic.candidates.single.place.providerPlaceId, 'supermarket');
      expect(
        alternatives.candidates.single.place.providerPlaceId,
        'supermarket',
      );
    },
  );
  Map<String, Object?> raw(String id, String type, {double lat = 14.58}) => {
    'id': id,
    'name': id,
    'latitude': lat,
    'longitude': 121.06,
    'country': 'PH',
    'types': [type],
    'primaryType': type,
    'rating': 4.7,
    'ratingCount': 100,
    'at': DateTime.now().millisecondsSinceEpoch,
  };
  test(
    'complementary searches stay bounded and supermarkets/markets precede small stores',
    () async {
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final queries = <String>[];
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, args) async {
          queries.add(args['query'] as String);
          return [
            raw('sari', 'convenience_store'),
            raw('supermarket', 'supermarket', lat: 14.59),
            if (args['query'] == 'public market')
              raw('palengke', 'market', lat: 14.6),
            raw('irrelevant', 'restaurant'),
          ];
        },
      );
      final result = await service.discover(
        const ErrandNeed(
          id: 'g',
          query: 'grocery',
          category: 'grocery',
          searchIntent: PlaceSearchIntent(
            variants: ['supermarket', 'public market', 'grocery store'],
            preferredTypes: ['supermarket', 'market'],
            acceptableTypes: [
              'supermarket',
              'market',
              'grocery_store',
              'convenience_store',
            ],
          ),
        ),
        polyline: 'seed',
        anchors: [pin, pin],
        limit: 3,
        cancelled: () => false,
      );
      expect(queries, ['supermarket', 'public market', 'grocery store']);
      final ids = result.candidates
          .map((p) => p.place.providerPlaceId)
          .toList();
      expect(ids.take(2), ['supermarket', 'palengke']);
      expect(ids, isNot(contains('irrelevant')));
    },
  );
  test(
    'raw ingredients reject food venues; ratings are sample tempered and optional',
    () {
      const rawChicken = ErrandNeed(
        id: 'c',
        query: 'raw chicken',
        category: 'grocery',
        searchIntent: PlaceSearchIntent(
          variants: ['butcher'],
          preferredTypes: ['butcher_shop'],
          acceptableTypes: ['butcher_shop', 'market', 'supermarket'],
        ),
      );
      final restaurant = RecommendationPlace.fromJson(
        raw('meal', 'restaurant'),
      );
      expect(placeSuitability(rawChicken, restaurant), 0);
      final butcher = RecommendationPlace.fromJson(
        raw('butcher', 'butcher_shop'),
      );
      expect(placeSuitability(rawChicken, butcher), 2);
      final sparse = RecommendationPlace.fromJson({
        ...raw('new', 'market'),
        'rating': 5,
        'ratingCount': 1,
      });
      expect(sparse.quality, lessThan(butcher.quality));
      final unknown = RecommendationPlace.fromJson({
        ...raw('unknown', 'market'),
        'rating': null,
      });
      expect(unknown.quality, 3.5);
      expect(unknown.eligible, isTrue);
    },
  );
}
