import '../../places/domain/philippine_eligibility.dart';
import '../../places/domain/place_intent.dart';
import 'planning_models.dart';
import 'discovery_result.dart';
import 'business_hours.dart';
export 'discovery_result.dart';
export 'business_hours.dart';

/// Provider display data lives only in the current recommendation session.
class RecommendationPlace {
  RecommendationPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.acquiredAt,
    this.address = '',
    this.locality = '',
    this.types = const [],
    this.country,
    this.status,
    this.attributions = const [],
    this.hours = const BusinessHours(),
    this.primaryType = '',
    this.rating,
    this.ratingCount,
    this.providerRank = 0,
    this.qualityChecked = false,
  });
  final String id, name, address, locality;
  final double latitude, longitude;
  final DateTime acquiredAt;
  final List<String> types, attributions;
  final String? country, status;
  final BusinessHours hours;
  final String primaryType;
  final double? rating;
  final int? ratingCount;
  final int providerRank;
  final bool qualityChecked;
  String? get ratingSummary => rating == null
      ? null
      : '${rating!.toStringAsFixed(1)} Google rating${ratingCount == null ? '' : ' · $ratingCount ratings'}';
  double get quality => rating == null || ratingCount == null
      ? 3.5
      : (ratingCount! * rating! + 20 * 3.5) / (ratingCount! + 20);
  RecommendationPlace withHours(BusinessHours value) => RecommendationPlace(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    acquiredAt: acquiredAt,
    address: address,
    locality: locality,
    types: types,
    country: country,
    status: status,
    attributions: attributions,
    hours: value,
    primaryType: primaryType,
    rating: rating,
    ratingCount: ratingCount,
    providerRank: providerRank,
    qualityChecked: qualityChecked,
  );

  factory RecommendationPlace.fromJson(Map<Object?, Object?> json) {
    final id = json['id'],
        lat = json['latitude'],
        lon = json['longitude'],
        at = json['at'];
    if (id is! String ||
        id.isEmpty ||
        id.length > 512 ||
        lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        at is! int ||
        at <= 0 ||
        at > DateTime.now().millisecondsSinceEpoch) {
      throw const FormatException('Invalid place metadata');
    }
    String text(String key) {
      final value = json[key];
      if (value == null) return '';
      if (value is! String || value.length > 2000) {
        throw const FormatException('Invalid place text');
      }
      return value.trim();
    }

    List<String> strings(String key) {
      final values = json[key] ?? <String>[];
      if (values is! List ||
          values.length > 50 ||
          values.any((v) => v is! String || v.length > 4000)) {
        throw const FormatException('Invalid place attributes');
      }
      return values.cast<String>();
    }

    return RecommendationPlace(
      id: id,
      name: text('name'),
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      acquiredAt: DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      address: text('address'),
      locality: text('locality'),
      country: json['country'] as String?,
      status: json['status'] as String?,
      types: strings('types'),
      primaryType: text('primaryType'),
      qualityChecked: json['metadataVersion'] == 2,
      rating:
          json['rating'] is num &&
              (json['rating'] as num).isFinite &&
              (json['rating'] as num) >= 1 &&
              (json['rating'] as num) <= 5
          ? (json['rating'] as num).toDouble()
          : null,
      ratingCount:
          json['ratingCount'] is int && (json['ratingCount'] as int) >= 0
          ? json['ratingCount'] as int
          : null,
      providerRank: json['rank'] is int && (json['rank'] as int) >= 0
          ? json['rank'] as int
          : 0,
      attributions: strings('attributions'),
      hours: BusinessHours.fromJson(
        json,
        DateTime.fromMillisecondsSinceEpoch(at, isUtc: true),
      ),
    );
  }

  bool get countryEligible => country != null
      ? country == 'PH'
      : PhilippineEligibility.confirmed(latitude, longitude);
  bool get eligible =>
      name.isNotEmpty &&
      status != 'CLOSED_PERMANENTLY' &&
      status != 'CLOSED_TEMPORARILY' &&
      countryEligible &&
      types.any(
        (t) => !{
          'route',
          'street_address',
          'political',
          'locality',
          'premise',
          'subpremise',
          'postal_code',
          'geocode',
          'plus_code',
        }.contains(t),
      );

  PlaceIntent reference(GooglePinLease pin, {String label = ''}) => PlaceIntent(
    kind: PlaceKind.providerReference,
    label: label,
    provider: 'google_places_sdk',
    source: 'google_places_sdk',
    providerPlaceId: id,
    googlePin: pin,
    attributions: const ['Google Maps'],
  );
}

/// Same matrix epoch and direction for all three legs; service is excluded.
int? addedTravelSeconds(
  List<List<int?>> matrix,
  int before,
  int stop,
  int after,
) {
  final first = matrix[before][stop],
      second = matrix[stop][after],
      bypass = matrix[before][after];
  return first == null || second == null || bypass == null
      ? null
      : first + second - bypass;
}

class RecommendationLeg {
  const RecommendationLeg({
    required this.from,
    required this.to,
    required this.seconds,
    required this.departureSeconds,
    this.meters,
    this.addedSeconds,
  });
  final String from, to;
  final int seconds, departureSeconds;
  final int? meters, addedSeconds;
}

abstract interface class RecommendationDiscovery {
  Future<void> preflight(int maximumRequests);
  Future<DiscoveryResult> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
    HoursQuery? hours,
  });
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  });
  RecommendationPlace? metadata(PlaceIntent place);
}

/// Browsing never expands the automatic solver's shortlist.
class AlternativeBatch {
  const AlternativeBatch(this.candidates, {required this.exhausted});
  final List<PlanCandidate> candidates;
  final bool exhausted;
}

abstract interface class AlternativeDiscovery {
  Future<AlternativeBatch> moreAlternatives(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required Set<String> excludedKeys,
    required int limit,
    required bool Function() cancelled,
    HoursQuery? hours,
  });
}

abstract interface class HoursRefreshDiscovery {
  Future<RecommendationPlace?> retryHours(PlaceIntent place);
  BusinessHours hoursStatus(PlaceIntent place);
}
