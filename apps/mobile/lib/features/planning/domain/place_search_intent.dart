/// Semantic search hints, never a catalogue of phrase-based errand rules.
class PlaceSearchIntent {
  const PlaceSearchIntent({
    required this.variants,
    required this.preferredTypes,
    required this.acceptableTypes,
  });
  final List<String> variants, preferredTypes, acceptableTypes;
  static const supportedTypes = {
    'supermarket',
    'grocery_store',
    'market',
    'farmers_market',
    'food_store',
    'convenience_store',
    'discount_store',
    'warehouse_store',
    'wholesaler',
    'butcher_shop',
    'bakery',
    'liquor_store',
    'health_food_store',
    'restaurant',
    'cafe',
    'coffee_shop',
    'meal_takeaway',
    'fast_food_restaurant',
    'pharmacy',
    'drugstore',
    'gym',
    'fitness_center',
    'sports_complex',
    'laundry',
    'hair_salon',
    'barber_shop',
    'beauty_salon',
    'bank',
    'atm',
    'hardware_store',
    'shopping_mall',
    'department_store',
    'pet_store',
    'electronics_store',
    'car_repair',
    'car_wash',
    'gas_station',
    'hospital',
    'doctor',
    'dentist',
    'post_office',
    'government_office',
    'park',
    'store',
    'book_store',
    'clothing_store',
    'shoe_store',
    'sporting_goods_store',
  };
  factory PlaceSearchIntent.fromJson(Map<String, dynamic> json) {
    if (json.keys.any(
      (k) => !{'variants', 'preferredTypes', 'acceptableTypes'}.contains(k),
    )) {
      throw const FormatException('Unexpected search intent');
    }
    List<String> values(String key, int limit, {bool types = false}) {
      final raw = json[key];
      if (raw is! List ||
          raw.length > limit ||
          raw.any(
            (v) =>
                v is! String ||
                v.trim().isEmpty ||
                v.length > 100 ||
                (types && !supportedTypes.contains(v)),
          )) {
        throw const FormatException('Invalid search intent');
      }
      return List.unmodifiable(raw.cast<String>().map((s) => s.trim()).toSet());
    }

    final variants = values('variants', 3);
    final preferred = values('preferredTypes', 12, types: true);
    final acceptable = values('acceptableTypes', 12, types: true);
    if (variants.isEmpty || !preferred.every(acceptable.contains)) {
      throw const FormatException('Invalid search alternatives');
    }
    return PlaceSearchIntent(
      variants: variants,
      preferredTypes: preferred,
      acceptableTypes: acceptable,
    );
  }
  Map<String, dynamic> toJson() => {
    'variants': variants,
    'preferredTypes': preferredTypes,
    'acceptableTypes': acceptableTypes,
  };
  static Map<String, dynamic> get schema => {
    'type': 'OBJECT',
    'nullable': true,
    'properties': {
      'variants': {
        'type': 'ARRAY',
        'maxItems': 3,
        'items': {'type': 'STRING'},
      },
      for (final key in ['preferredTypes', 'acceptableTypes'])
        key: {
          'type': 'ARRAY',
          'maxItems': 12,
          'items': {'type': 'STRING', 'enum': supportedTypes.toList()},
        },
    },
    'required': ['variants', 'preferredTypes', 'acceptableTypes'],
  };
  static const policy =
      ' Place search policy v1: return searchIntent for flexible business needs, otherwise null. '
      'Read the whole errand, notes, items and explicit preferences in English, Filipino and Taglish. '
      'Return one to three complementary concise generic queries (100 chars each), preferredTypes and acceptableTypes from the schema. '
      'Preferred types must be acceptable. Empty type lists permit a specialist query when no supported type describes it. '
      'For general groceries prefer supermarkets and public markets; small shops can be suitable for specific purchases or fallback. '
      'Distinguish raw goods from prepared meals: chicken for cooking can use butchers, supermarkets or markets; a chicken meal needs food venues. '
      'Rice for home can use rice retailers, supermarkets, markets or relevant small shops. These are examples, not phrase rules. '
      'Ask the existing focused question only when essential meaning is ambiguous. Do not require brand or item lists for general shopping. '
      'Preserve explicit brands and qualifiers in every query; do not invent branch names, stock, access, coordinates or hours. '
      'Generic specialist queries are permitted; never claim category membership proves stock. ';
}
