/// Semantic search hints, never a catalogue of phrase-based errand rules.
class PlaceSearchIntent {
  const PlaceSearchIntent({
    required this.variants,
    required this.preferredTypes,
    required this.acceptableTypes,
    this.excludedPrimaryTypes = const [],
    this.version = 1,
  });
  final List<String> variants, preferredTypes, acceptableTypes;
  final List<String> excludedPrimaryTypes;
  final int version;
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
    final modern = json['version'] == 2;
    if (json.keys.any(
      (k) =>
          !(modern
                  ? {
                      'version',
                      'variants',
                      'preferredTypes',
                      'fallbackTypes',
                      'excludedPrimaryTypes',
                    }
                  : {'variants', 'preferredTypes', 'acceptableTypes'})
              .contains(k),
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
    final acceptable = modern
        ? {...preferred, ...values('fallbackTypes', 12, types: true)}.toList()
        : values('acceptableTypes', 12, types: true);
    final excluded = modern
        ? values('excludedPrimaryTypes', 12, types: true)
        : <String>[];
    if (variants.isEmpty || !preferred.every(acceptable.contains)) {
      throw const FormatException('Invalid search alternatives');
    }
    if (acceptable.any(excluded.contains)) {
      throw const FormatException('Conflicting search families');
    }
    return PlaceSearchIntent(
      variants: variants,
      preferredTypes: preferred,
      acceptableTypes: acceptable,
      excludedPrimaryTypes: excluded,
      version: modern ? 2 : 1,
    );
  }

  /// Hints are optional advice. Reject invalid advice without discarding the
  /// independently validated query, category, source constraints or questions.
  static PlaceSearchIntent? optionalFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    try {
      return PlaceSearchIntent.fromJson(value);
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    if (version == 2) 'version': 2,
    'variants': variants,
    'preferredTypes': preferredTypes,
    if (version == 1) 'acceptableTypes': acceptableTypes,
    if (version == 2)
      'fallbackTypes': acceptableTypes
          .where((v) => !preferredTypes.contains(v))
          .toList(),
    if (version == 2) 'excludedPrimaryTypes': excludedPrimaryTypes,
  };
  static Map<String, dynamic> get currentSchema => {
    'type': 'OBJECT',
    'nullable': true,
    'properties': {
      'version': {'type': 'INTEGER'},
      'variants': {
        'type': 'ARRAY',
        'maxItems': 3,
        'items': {'type': 'STRING'},
      },
      for (final key in [
        'preferredTypes',
        'fallbackTypes',
        'excludedPrimaryTypes',
      ])
        key: {
          'type': 'ARRAY',
          'maxItems': 12,
          'items': {'type': 'STRING'},
        },
    },
    'required': [
      'version',
      'variants',
      'preferredTypes',
      'fallbackTypes',
      'excludedPrimaryTypes',
    ],
  };
  static final currentPolicy =
      ' Place search policy v2 replaces the earlier searchIntent format: version=2, one to three complementary queries, '
      'preferredTypes for strongest venue matches, fallbackTypes for additional plausible families, excludedPrimaryTypes for incompatible primary business types. '
      'All type lists use only: ${supportedTypes.join(', ')}. Each type list has at most twelve entries. '
      'Preferred and fallback types must not overlap exclusions. The client derives acceptable types from their union. '
      'Return searchIntent for flexible business needs, otherwise null. Preserve explicit brands and qualifiers in every query. '
      'For consumer grocery purchases prefer supermarkets, grocery stores and public markets, with suitable retailers as alternatives; exclude wholesaler primary types unless bulk/wholesale intent is explicit. '
      'For service errands choose the needed service family; distinguish ingredients from prepared meals and existing pickups from new purchases. '
      'Use complementary venue queries rather than repeating only product words. Empty positive type lists allow specialist queries not described by the supported taxonomy. '
      'Do not invent business names, stock, availability, access, coordinates or hours. ';
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

  /// Avoid multiplying a large enum through nested, bounded output arrays.
  /// The allowlist and all cross-field/length checks remain enforced above.
  static Map<String, dynamic> get transportSchema {
    final result = schema;
    for (final key in ['preferredTypes', 'acceptableTypes']) {
      (result['properties'][key]['items'] as Map).remove('enum');
    }
    return result;
  }

  static final transportPolicy =
      ' Place search transport v2: preferredTypes and acceptableTypes must use only these supported venue types: ${supportedTypes.join(', ')}. '
      'All existing list limits and preferred-types-must-be-acceptable rules still apply. ';

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
