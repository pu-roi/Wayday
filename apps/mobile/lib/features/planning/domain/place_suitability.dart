import 'planning_models.dart';
import 'recommendation.dart';
import 'place_search_intent.dart';

/// Category/type policy evaluates an interpreted need; it never parses phrases.
int placeSuitability(ErrandNeed need, RecommendationPlace place) {
  final types = {...place.types, place.primaryType}..remove('');
  final intent = need.searchIntent;
  if (intent?.excludedPrimaryTypes.contains(place.primaryType) == true) {
    return 0;
  }
  // A conflicting primary wholesale classification is stronger than a generic
  // retail secondary tag. Explicit wholesale intent may opt that family in.
  if (place.primaryType == 'wholesaler' &&
      !((intent?.acceptableTypes ?? const <String>[]).contains('wholesaler')) &&
      {'grocery', 'marketplace', 'convenience'}.contains(need.category)) {
    return 0;
  }
  final preferred =
      intent?.preferredTypes.toSet() ??
      switch (need.category) {
        'grocery' || 'marketplace' => {
          'supermarket',
          'market',
          'farmers_market',
          'warehouse_store',
        },
        'pharmacy' => {'pharmacy', 'drugstore'},
        'convenience' => {'convenience_store', 'grocery_store'},
        'food' => {
          'restaurant',
          'cafe',
          'coffee_shop',
          'meal_takeaway',
          'fast_food_restaurant',
        },
        _ => <String>{},
      };
  final acceptable =
      intent?.acceptableTypes.toSet() ??
      switch (need.category) {
        'grocery' || 'marketplace' => {
          ...preferred,
          'grocery_store',
          'convenience_store',
          'discount_store',
          'food_store',
        },
        _ => preferred,
      };
  if (acceptable.isNotEmpty &&
      PlaceSearchIntent.supportedTypes.contains(place.primaryType) &&
      !{'store', 'food_store'}.contains(place.primaryType) &&
      !acceptable.contains(place.primaryType)) {
    return 0;
  }
  if (preferred.any(types.contains)) return 2;
  if (acceptable.isEmpty) return 2; // Generic/specialist text-query evidence.
  if (acceptable.any(types.contains)) return 1;
  // Missing classification is weaker evidence, not proof of an unrelated type.
  if (types.difference({
    'establishment',
    'point_of_interest',
    'store',
  }).isEmpty) {
    return 1;
  }
  return 0;
}
