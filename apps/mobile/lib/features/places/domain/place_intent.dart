enum PlaceKind { unresolved, specific, saved, search, providerReference }

/// A revocable, temporary coordinate lease. Copies share the original expiry.
class GooglePinLease {
  GooglePinLease({DateTime Function()? now}) : now = now ?? DateTime.now;
  final DateTime Function() now;
  double? latitude, longitude;
  DateTime? acquiredAt;
  bool get valid {
    final acquired = acquiredAt;
    return acquired != null &&
        !now().isBefore(acquired) &&
        now().isBefore(acquired.add(const Duration(days: 30))) &&
        latitude != null &&
        longitude != null;
  }

  void clear() {
    latitude = null;
    longitude = null;
    acquiredAt = null;
  }
}

typedef GooglePinResolver = GooglePinLease Function(String placeId);

/// A label is deliberately unresolved until coordinates or a search rule exist.
class PlaceIntent {
  const PlaceIntent({
    this.kind = PlaceKind.unresolved,
    this.label = '',
    double? latitude,
    double? longitude,
    this.savedPlaceId,
    this.category,
    this.brand,
    this.source = 'user',
    this.address,
    this.sourceDate,
    this.coordinateKind,
    this.provider,
    this.retrievedAt,
    this.attributions = const [],
    this.providerPlaceId,
    this.googlePin,
  }) : _latitude = latitude,
       _longitude = longitude;

  final PlaceKind kind;
  final String label;
  final double? _latitude, _longitude;
  final String? providerPlaceId;
  final GooglePinLease? googlePin;
  bool get isGoogle => provider == 'google_ui_kit';
  double? get latitude => isGoogle
      ? (googlePin?.valid == true ? googlePin!.latitude : null)
      : _latitude;
  double? get longitude => isGoogle
      ? (googlePin?.valid == true ? googlePin!.longitude : null)
      : _longitude;
  final String? savedPlaceId;
  final String? category;
  final String? brand;
  final String source;
  final String? address, sourceDate, coordinateKind, provider, retrievedAt;
  final List<String> attributions;

  bool get hasCoordinates {
    final lat = latitude, lon = longitude;
    return lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat.abs() <= 90 &&
        lon.abs() <= 180;
  }

  Map<String, Object?> toJson() => {
    'kind': isGoogle ? PlaceKind.providerReference.name : kind.name,
    'label': label,
    if (!isGoogle) 'latitude': latitude,
    if (!isGoogle) 'longitude': longitude,
    'savedPlaceId': savedPlaceId,
    if (!isGoogle) 'category': category,
    if (!isGoogle) 'brand': brand,
    'source': source,
    if (!isGoogle) 'address': address,
    if (!isGoogle) 'sourceDate': sourceDate,
    if (!isGoogle) 'coordinateKind': coordinateKind,
    'provider': provider,
    if (!isGoogle) 'retrievedAt': retrievedAt,
    if (providerPlaceId != null) 'providerPlaceId': providerPlaceId,
    'attributions': attributions,
  };

  factory PlaceIntent.fromJson(
    Map<String, dynamic> json, {
    GooglePinResolver? resolveGooglePin,
  }) {
    final google = json['provider'] == 'google_ui_kit';
    final placeId = json['providerPlaceId'] as String?;
    if (google && (placeId == null || placeId.trim().isEmpty)) {
      throw const FormatException('A Google reference needs a place ID');
    }
    final latitude = google ? null : (json['latitude'] as num?)?.toDouble();
    final longitude = google ? null : (json['longitude'] as num?)?.toDouble();
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (!latitude.isFinite || latitude.abs() > 90)) ||
        (longitude != null && (!longitude.isFinite || longitude.abs() > 180))) {
      throw const FormatException('Invalid place coordinates');
    }
    final kind = PlaceKind.values.byName(json['kind'] as String);
    if (!google && kind == PlaceKind.specific && latitude == null) {
      throw const FormatException('A specific place needs coordinates');
    }
    return PlaceIntent(
      kind: google ? PlaceKind.providerReference : kind,
      label: json['label'] as String,
      latitude: latitude,
      longitude: longitude,
      savedPlaceId: json['savedPlaceId'] as String?,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      source: json['source'] as String? ?? 'user',
      address: google ? null : json['address'] as String?,
      sourceDate: json['sourceDate'] as String?,
      coordinateKind: json['coordinateKind'] as String?,
      provider: json['provider'] as String?,
      retrievedAt: json['retrievedAt'] as String?,
      attributions: (json['attributions'] as List?)?.cast<String>() ?? const [],
      providerPlaceId: placeId,
      googlePin: google ? resolveGooglePin?.call(placeId!) : null,
    );
  }

  PlaceIntent withLabel(String value, {String? labelSource}) => PlaceIntent(
    kind: kind,
    label: value,
    latitude: latitude,
    longitude: longitude,
    savedPlaceId: savedPlaceId,
    category: category,
    brand: brand,
    source: labelSource ?? source,
    address: address,
    sourceDate: sourceDate,
    coordinateKind: coordinateKind,
    provider: provider,
    retrievedAt: retrievedAt,
    attributions: attributions,
    providerPlaceId: providerPlaceId,
    googlePin: googlePin,
  );
}

class SavedPlace {
  const SavedPlace({required this.id, required this.place});
  final String id;
  final PlaceIntent place;
  Map<String, Object?> toJson() => {'id': id, 'place': place.toJson()};
  factory SavedPlace.fromJson(
    Map<String, dynamic> json, {
    GooglePinResolver? resolveGooglePin,
  }) => SavedPlace(
    id: json['id'] as String,
    place: PlaceIntent.fromJson(
      json['place'] as Map<String, dynamic>,
      resolveGooglePin: resolveGooglePin,
    ),
  );

  PlaceIntent get intent => PlaceIntent(
    kind: PlaceKind.saved,
    label: place.label,
    savedPlaceId: id,
    category: place.category,
    brand: place.brand,
    latitude: place.latitude,
    longitude: place.longitude,
    source: place.source,
    address: place.address,
    sourceDate: place.sourceDate,
    coordinateKind: place.coordinateKind,
    provider: place.provider,
    retrievedAt: place.retrievedAt,
    attributions: place.attributions,
    providerPlaceId: place.providerPlaceId,
    googlePin: place.googlePin,
  );
}
