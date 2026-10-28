enum PlaceKind { unresolved, specific, saved, search }

/// A label is deliberately unresolved until coordinates or a search rule exist.
class PlaceIntent {
  const PlaceIntent({
    this.kind = PlaceKind.unresolved,
    this.label = '',
    this.latitude,
    this.longitude,
    this.savedPlaceId,
    this.category,
    this.brand,
    this.source = 'user',
    this.address,
    this.sourceDate,
    this.coordinateKind,
  });

  final PlaceKind kind;
  final String label;
  final double? latitude;
  final double? longitude;
  final String? savedPlaceId;
  final String? category;
  final String? brand;
  final String source;
  final String? address, sourceDate, coordinateKind;

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'label': label,
    'latitude': latitude,
    'longitude': longitude,
    'savedPlaceId': savedPlaceId,
    'category': category,
    'brand': brand,
    'source': source,
    'address': address,
    'sourceDate': sourceDate,
    'coordinateKind': coordinateKind,
  };

  factory PlaceIntent.fromJson(Map<String, dynamic> json) {
    final latitude = (json['latitude'] as num?)?.toDouble();
    final longitude = (json['longitude'] as num?)?.toDouble();
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (!latitude.isFinite || latitude.abs() > 90)) ||
        (longitude != null && (!longitude.isFinite || longitude.abs() > 180))) {
      throw const FormatException('Invalid place coordinates');
    }
    final kind = PlaceKind.values.byName(json['kind'] as String);
    if (kind == PlaceKind.specific && latitude == null) {
      throw const FormatException('A specific place needs coordinates');
    }
    return PlaceIntent(
      kind: kind,
      label: json['label'] as String,
      latitude: latitude,
      longitude: longitude,
      savedPlaceId: json['savedPlaceId'] as String?,
      category: json['category'] as String?,
      brand: json['brand'] as String?,
      source: json['source'] as String? ?? 'user',
      address: json['address'] as String?,
      sourceDate: json['sourceDate'] as String?,
      coordinateKind: json['coordinateKind'] as String?,
    );
  }
}

class SavedPlace {
  const SavedPlace({required this.id, required this.place});
  final String id;
  final PlaceIntent place;
  Map<String, Object?> toJson() => {'id': id, 'place': place.toJson()};
  factory SavedPlace.fromJson(Map<String, dynamic> json) => SavedPlace(
    id: json['id'] as String,
    place: PlaceIntent.fromJson(json['place'] as Map<String, dynamic>),
  );

  PlaceIntent get intent => PlaceIntent(
    kind: PlaceKind.saved,
    label: place.label,
    savedPlaceId: id,
    latitude: place.latitude,
    longitude: place.longitude,
    source: place.source,
    address: place.address,
    sourceDate: place.sourceDate,
    coordinateKind: place.coordinateKind,
  );
}
