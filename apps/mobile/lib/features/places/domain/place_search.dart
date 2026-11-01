import 'dart:math' as math;
import 'search_terms.dart';

String normalizeSearch(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

enum SearchCategory {
  marketplace(
    'Markets',
    ['palengke', 'wet market', 'public market'],
    'commercial.marketplace',
    'amenity:marketplace',
  ),
  food(
    'Restaurants and fast food',
    ['restaurant', 'restawran', 'kainan'],
    'catering.restaurant,catering.fast_food',
    'amenity:restaurant,amenity:fast_food',
  ),
  grocery(
    'Groceries',
    ['grocery', 'supermarket'],
    'commercial.supermarket,commercial.food_and_drink',
    'shop:supermarket,shop:convenience,shop:greengrocer',
  ),
  shop('Shops', ['store', 'shop'], 'commercial', 'shop:*'),
  convenience(
    'Convenience and sari-sari stores',
    [
      'sari sari',
      'sari sari store',
      'sari-sari',
      'sari-sari store',
      'tindahan',
      'convenience store',
    ],
    'commercial.convenience',
    'shop:convenience',
  ),
  pharmacy(
    'Pharmacies',
    ['botika', 'pharmacy'],
    'healthcare.pharmacy',
    'amenity:pharmacy',
  );

  const SearchCategory(
    this.label,
    this.aliases,
    this.geoapify,
    this.locationIq,
  );
  final String label, geoapify, locationIq;
  final List<String> aliases;
  static SearchCategory? match(String value) {
    final query = normalizeSearch(value).toLowerCase();
    for (final category in values) {
      if (category.aliases.contains(query)) return category;
    }
    return null;
  }
}

class SearchArea {
  const SearchArea(this.latitude, this.longitude, this.zoom);
  final double latitude, longitude, zoom;
  bool get local =>
      zoom >= 10 &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  String get key =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
}

class PlaceSearchRequest {
  PlaceSearchRequest(
    String text, {
    this.category,
    this.useOriginal = false,
    SearchArea? area,
    SearchOrigin? origin,
  }) : text = normalizeSearch(text),
       origin =
           origin ?? (area?.local == true ? SearchOrigin.map(area!) : null);
  final String text;
  final bool useOriginal;
  late final SearchInterpretation interpretation = interpretSearch(
    text,
    useOriginal: useOriginal,
  );
  String get providerText => interpretation.providerText;
  final SearchCategory? category;
  final SearchOrigin? origin;
  SearchArea? get area => origin?.area;
  static const radiusMeters = 5000;
  String get key =>
      '${providerText.toLowerCase()}|${category?.name ?? ''}|PH|${origin?.key ?? ''}|${category == null ? '' : radiusMeters}';
}

enum SearchOriginKind { device, map }

class SearchOrigin {
  const SearchOrigin.device(
    this.latitude,
    this.longitude, {
    this.approximate = false,
    this.accuracy = 0,
  }) : kind = SearchOriginKind.device,
       zoom = 12;
  SearchOrigin.map(SearchArea area)
    : latitude = area.latitude,
      longitude = area.longitude,
      zoom = area.zoom,
      approximate = false,
      accuracy = 0,
      kind = SearchOriginKind.map;
  final double latitude, longitude, zoom, accuracy;
  final bool approximate;
  final SearchOriginKind kind;
  SearchArea get area => SearchArea(latitude, longitude, zoom);
  String get key => '${kind.name}|${area.key}|${zoom.toStringAsFixed(2)}';
  String get rankingKey => '$key|$approximate|$accuracy';
  String get label => kind == SearchOriginKind.map
      ? 'This map area'
      : approximate
      ? 'Near your approximate location'
      : 'Near me';
}

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sourceId,
    this.address,
    this.provider = 'photon',
    this.osmId,
    this.category,
    this.street = false,
    this.attributions = const ['© OpenStreetMap contributors'],
    this.retrievedAt,
    this.rank = 0,
    this.brand,
    this.alternateNames = const [],
    this.locality,
  });
  final String name, sourceId, provider;
  final double latitude, longitude;
  final String? address, osmId, category;
  final bool street;
  final List<String> attributions;
  final DateTime? retrievedAt;
  final int rank;
  final String? brand, locality;
  final List<String> alternateNames;
  String get identity => osmId ?? sourceId;
  PlaceSearchResult withCredits(Iterable<String> credits) => PlaceSearchResult(
    name: name,
    latitude: latitude,
    longitude: longitude,
    sourceId: sourceId,
    address: address,
    provider: provider,
    osmId: osmId,
    category: category,
    street: street,
    attributions: {...attributions, ...credits}.toList(),
    retrievedAt: retrievedAt,
    rank: rank,
    brand: brand,
    alternateNames: alternateNames,
    locality: locality,
  );
}

enum SearchFailureKind { access, rate, daily, temporary, invalid, accounting }

class SearchFailure implements Exception {
  const SearchFailure(this.kind, {this.retryAt});
  final SearchFailureKind kind;
  final DateTime? retryAt;
}

enum SourcePhase { waiting, loading, complete, unavailable, disabled }

class SourceState {
  const SourceState(this.phase, {this.retryAt});
  final SourcePhase phase;
  final DateTime? retryAt;
}

double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  double rad(double v) => v * math.pi / 180;
  final a =
      math.pow(math.sin(rad(lat2 - lat1) / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(rad(lon2 - lon1) / 2), 2);
  return 6371000 * 2 * math.asin(math.sqrt(a.clamp(0, 1)));
}

bool sameSearchPlace(PlaceSearchResult a, PlaceSearchResult b) {
  if (a.identity == b.identity) return true;
  if (a.street || b.street) return false;
  if (normalizeSearch(a.name).toLowerCase() !=
      normalizeSearch(b.name).toLowerCase()) {
    return false;
  }
  if (a.address?.trim().isNotEmpty == true &&
      b.address?.trim().isNotEmpty == true &&
      normalizeSearch(a.address!).toLowerCase() !=
          normalizeSearch(b.address!).toLowerCase()) {
    return false;
  }
  return distanceMeters(a.latitude, a.longitude, b.latitude, b.longitude) <= 25;
}
