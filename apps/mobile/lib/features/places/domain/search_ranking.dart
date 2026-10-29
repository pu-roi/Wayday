import 'dart:math' as math;
import 'place_search.dart';
import 'search_terms.dart';
export 'search_terms.dart' show matchText, brandOnlyQuery;

int matchGroup(String query, PlaceSearchResult result) {
  final q = matchText(query);
  final names = [result.name, ...result.alternateNames].map(matchText).toList();
  final name = names.first;
  final words = q.split(' ').where((w) => w.isNotEmpty).toList();
  final combined =
      '$name ${matchText(result.address ?? '')} ${matchText(result.locality ?? '')}';
  bool hasWords(String text, Iterable<String> tokens) {
    final available = text.split(' ').toSet();
    return tokens.every(available.contains);
  }

  if (q.isEmpty) return 0;
  if (names.contains(q)) return 0;
  const mall = {'megamall', 'sm megamall'};
  if (mall.contains(q) && names.any(mall.contains)) return 0;
  final recordedBrand = matchText(result.brand ?? '');
  if (recordedBrand.isNotEmpty &&
      (q == recordedBrand || q.startsWith('$recordedBrand ')) &&
      hasWords(combined, words.skip(recordedBrand.split(' ').length))) {
    return 0;
  }
  final queryBrand = brandSearchTerm(query);
  if (queryBrand != null && !queryBrand.brand.landmark) {
    final metadataBrand = brandSearchTerm(result.brand ?? '');
    final branch =
        metadataBrand?.brand == queryBrand.brand ||
        names.any((n) => brandSearchTerm(n)?.brand == queryBrand.brand);
    final qualifiers = matchText(
      queryBrand.qualifiers,
    ).split(' ').where((w) => w.isNotEmpty);
    if (branch && hasWords(combined, qualifiers)) return 0;
  }
  if (names.any((n) => hasWords(n, words))) return 1;
  if (hasWords(combined, words)) return 2;
  if (names.any(
    (n) =>
        n.startsWith(q) ||
        n.contains(q) ||
        words.any((w) => n.split(' ').any((part) => part.startsWith(w))),
  )) {
    return 3;
  }
  return 4;
}

List<PlaceSearchResult> rankPlaces(
  Iterable<PlaceSearchResult> values,
  String query,
  SearchOrigin? origin,
) {
  double distance(PlaceSearchResult p) {
    if (origin == null) return 0;
    final meters = distanceMeters(
      origin.latitude,
      origin.longitude,
      p.latitude,
      p.longitude,
    );
    if (origin.approximate) {
      return (meters / math.max(1000, origin.accuracy)).floorToDouble();
    }
    return meters;
  }

  int provider(String id) => switch (id) {
    'geoapify' => 0,
    'locationiq' => 1,
    'photon' => 2,
    _ => 3,
  };
  return [...values]..sort((a, b) {
    var order = matchGroup(query, a).compareTo(matchGroup(query, b));
    if (order == 0) order = distance(a).compareTo(distance(b));
    if (order == 0) order = a.rank.compareTo(b.rank);
    if (order == 0) {
      order = provider(a.provider).compareTo(provider(b.provider));
    }
    if (order == 0) order = a.sourceId.compareTo(b.sourceId);
    return order;
  });
}

String? searchDistanceLabel(PlaceSearchResult result, SearchOrigin? origin) {
  if (origin == null) return null;
  if (origin.approximate) return 'Near your approximate location';
  final meters = distanceMeters(
    origin.latitude,
    origin.longitude,
    result.latitude,
    result.longitude,
  );
  final number = meters < 1000
      ? '${math.max(100, (meters / 100).round() * 100)} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';
  return origin.kind == SearchOriginKind.map
      ? 'About $number from map center · straight-line'
      : 'About $number away · straight-line';
}
