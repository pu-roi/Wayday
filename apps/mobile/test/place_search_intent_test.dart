import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/place_search_intent.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';

void main() {
  test(
    'semantic venue alternatives are bounded and survive interpretation',
    () {
      final intent = PlaceSearchIntent.fromJson({
        'variants': ['rice retailer', 'supermarket', 'public market'],
        'preferredTypes': ['grocery_store', 'market'],
        'acceptableTypes': [
          'grocery_store',
          'market',
          'supermarket',
          'convenience_store',
        ],
      });
      final need = ErrandNeed(
        id: 'rice',
        query: 'rice retailer',
        searchIntent: intent,
      );
      expect(
        ErrandNeed.fromJson(need.toJson()).searchIntent!.variants.last,
        'public market',
      );
      expect(
        () => PlaceSearchIntent.fromJson({
          ...intent.toJson(),
          'variants': ['a', 'b', 'c', 'd'],
        }),
        throwsFormatException,
      );
      expect(
        () => PlaceSearchIntent.fromJson({
          ...intent.toJson(),
          'acceptableTypes': ['invented_rice_inventory'],
        }),
        throwsFormatException,
      );
    },
  );
}
