import '../../places/domain/philippine_eligibility.dart';
import '../../places/domain/place_intent.dart';
import 'planning_models.dart';

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
  });
  final String id, name, address, locality;
  final double latitude, longitude;
  final DateTime acquiredAt;
  final List<String> types, attributions;
  final String? country, status;

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
      attributions: strings('attributions'),
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
  Future<List<PlanCandidate>> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
  });
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  });
  RecommendationPlace? metadata(PlaceIntent place);
}
