import 'planning_models.dart';
import 'recommendation.dart';

/// Category/type policy evaluates an interpreted need; it never parses phrases.
int placeSuitability(ErrandNeed need, RecommendationPlace place) {
  final types = {...place.types, place.primaryType}..remove('');
  final intent = need.searchIntent;
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
