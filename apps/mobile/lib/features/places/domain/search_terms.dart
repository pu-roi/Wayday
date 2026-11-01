import 'dart:convert';
import 'philippine_brands.g.dart';

/// Matching normalization never changes display labels or the user's field.
String matchText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp("[’‘'`]"), '')
    .replaceAll(RegExp(r'[^a-z0-9À-ž\s]'), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

class SearchBrand {
  const SearchBrand(
    this.name,
    this.aliases, {
    this.geoCategories = '',
    this.landmark = false,
  });
  final String name;
  final Set<String> aliases;
  final String geoCategories;
  final bool landmark;
}

final List<SearchBrand> searchBrands = [
  for (final row in jsonDecode(philippineBrandsJson) as List)
    SearchBrand(row['name'] as String, {
      matchText(row['name'] as String),
      for (final alias in row['aliases'] as List) matchText(alias as String),
    }, geoCategories: (row['categories'] as List).join(',')),
  const SearchBrand('SM Megamall', {'megamall', 'sm megamall'}, landmark: true),
];

final _brandAliases = _indexBrandAliases();
Map<String, List<SearchBrand>> _indexBrandAliases() {
  final index = <String, List<SearchBrand>>{};
  for (final brand in searchBrands) {
    for (final alias in brand.aliases) {
      index.putIfAbsent(alias, () => []).add(brand);
    }
  }
  return index;
}

class BrandSearchTerm {
  const BrandSearchTerm(this.brand, this.qualifiers);
  final SearchBrand brand;
  final String qualifiers;
  String get providerText =>
      qualifiers.isEmpty ? brand.name : '${brand.name} $qualifiers';
}

BrandSearchTerm? brandSearchTerm(String value) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  // Test word boundaries in the original text, retaining original qualifiers
  // (including punctuation such as Shangri-La) for the provider request.
  for (final end in [
    ...RegExp(r'\s').allMatches(text).map((m) => m.start),
    text.length,
  ].reversed) {
    final prefix = matchText(text.substring(0, end));
    final brands = _brandAliases[prefix];
    if (brands?.length == 1) {
      return BrandSearchTerm(brands!.single, text.substring(end).trim());
    }
  }
  return null;
}

bool brandOnlyQuery(String query) =>
    brandSearchTerm(query)?.qualifiers.isEmpty == true &&
    brandSearchTerm(query)?.brand.landmark == false;

String providerSearchText(String query) => interpretSearch(query).providerText;

class SearchInterpretation {
  const SearchInterpretation(
    this.original,
    this.providerText, {
    this.brand,
    this.suggestions = const [],
  });
  final String original, providerText;
  final BrandSearchTerm? brand;
  final List<String> suggestions;
  bool get corrected => matchText(original) != matchText(providerText);
}

SearchInterpretation interpretSearch(String value, {bool useOriginal = false}) {
  final text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  final exact = brandSearchTerm(text);
  if (useOriginal) return SearchInterpretation(text, text, brand: exact);
  if (exact != null) {
    return SearchInterpretation(text, exact.providerText, brand: exact);
  }
  // Never turn numbers/addresses or short abbreviations into a brand.
  if (RegExp(r'\d').hasMatch(text) || matchText(text).length < 5) {
    return SearchInterpretation(text, text);
  }
  final matches = <String, (int, BrandSearchTerm)>{};
  final ends = [
    ...RegExp(r'\s').allMatches(text).map((m) => m.start),
    text.length,
  ];
  for (final end in ends.take(5)) {
    final prefix = matchText(text.substring(0, end));
    if (prefix.length < 5 || prefix.length > 40) continue;
    for (final brand in searchBrands.where((b) => !b.landmark)) {
      if (RegExp(r'\d').hasMatch(brand.name)) continue;
      for (final alias in brand.aliases) {
        final length = prefix.length < alias.length
            ? prefix.length
            : alias.length;
        final limit = length >= 8
            ? 2
            : length >= 5
            ? 1
            : 0;
        if (limit == 0 || (prefix.length - alias.length).abs() > limit) {
          continue;
        }
        final distance = boundedEditDistance(prefix, alias, limit);
        if (distance <= limit &&
            (matches[brand.name] == null ||
                distance < matches[brand.name]!.$1)) {
          matches[brand.name] = (
            distance,
            BrandSearchTerm(brand, text.substring(end).trim()),
          );
        }
      }
    }
  }
  final sorted = matches.values.toList()
    ..sort((a, b) {
      final score = a.$1.compareTo(b.$1);
      return score != 0 ? score : a.$2.brand.name.compareTo(b.$2.brand.name);
    });
  if (sorted.isEmpty) return SearchInterpretation(text, text);
  if (sorted.length == 1 || sorted[1].$1 > sorted.first.$1) {
    final match = sorted.first.$2;
    return SearchInterpretation(text, match.providerText, brand: match);
  }
  return SearchInterpretation(
    text,
    text,
    suggestions: sorted.take(3).map((v) => v.$2.providerText).toList(),
  );
}

/// Bounded optimal-string-alignment distance, including adjacent transpositions.
int boundedEditDistance(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  var previous = List.generate(b.length + 1, (i) => i);
  List<int>? beforePrevious;
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, limit + 1)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      var best = previous[j] + 1;
      if (current[j - 1] + 1 < best) best = current[j - 1] + 1;
      final substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1);
      if (substitution < best) best = substitution;
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
        final transposition = beforePrevious![j - 2] + 1;
        if (transposition < best) best = transposition;
      }
      current[j] = best;
    }
    beforePrevious = previous;
    previous = current;
  }
  return previous.last;
}
