import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../places/domain/place_intent.dart';
import '../planning/data/itinerary_repository.dart';
import '../planning/presentation/planning_controller.dart';

const sharingEnabled = bool.fromEnvironment('WAYDAY_SHARING');

class SharingFailure implements Exception {
  const SharingFailure(this.message, {this.unavailable = false});
  final String message;
  final bool unavailable;
  @override
  String toString() => message;
}

class ShareStop {
  const ShareStop(
    this.id,
    this.title,
    this.place,
    this.latitude,
    this.longitude,
  );
  final String id, title, place;
  final double latitude, longitude;
  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'place': place,
    'latitude': latitude,
    'longitude': longitude,
  };
  factory ShareStop.fromJson(Map<String, dynamic> value) => ShareStop(
    value['id'] as String,
    value['title'] as String,
    value['place'] as String,
    (value['latitude'] as num).toDouble(),
    (value['longitude'] as num).toDouble(),
  );
}

class SharedSnapshot {
  SharedSnapshot({
    required this.sourceId,
    required this.route,
    required this.stops,
    required this.start,
    required this.destination,
    this.completed = const {},
  }) {
    final coordinates = [
      ...route,
      start,
      destination,
      for (final s in stops) [s.latitude, s.longitude],
    ];
    if (sourceId.isEmpty ||
        sourceId.length > 128 ||
        route.length < 2 ||
        route.length > 1600 ||
        stops.isEmpty ||
        stops.length > 12 ||
        coordinates.any(
          (p) =>
              p.length != 2 ||
              !p[0].isFinite ||
              !p[1].isFinite ||
              p[0].abs() > 90 ||
              p[1].abs() > 180,
        ) ||
        stops.map((s) => s.id).toSet().length != stops.length ||
        stops.any(
          (s) =>
              s.id.isEmpty ||
              s.id.length > 128 ||
              s.title.trim().isEmpty ||
              s.title.length > 240 ||
              s.place.isEmpty ||
              s.place.length > 240,
        ) ||
        !stops.map((s) => s.id).toSet().containsAll(completed)) {
      throw const SharingFailure(
        'This route cannot be shared. Refresh your plan before sharing.',
      );
    }
  }
  final String sourceId;
  final List<List<double>> route;
  final List<ShareStop> stops;
  final List<double> start, destination;
  final Set<String> completed;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'sourceId': sourceId,
    'route': route,
    'stops': stops.map((s) => s.toJson()).toList(),
    'start': {'latitude': start[0], 'longitude': start[1], 'label': 'Start'},
    'destination': {
      'latitude': destination[0],
      'longitude': destination[1],
      'label': 'Destination',
    },
    'completed': completed.toList(),
  };
  factory SharedSnapshot.fromJson(Map<String, dynamic> value) {
    if (value['version'] != 1) {
      throw const FormatException('Unknown sharing version');
    }
    List<double> point(Map<dynamic, dynamic> value) => [
      (value['latitude'] as num).toDouble(),
      (value['longitude'] as num).toDouble(),
    ];
    return SharedSnapshot(
      sourceId: value['sourceId'] as String,
      route: (value['route'] as List)
          .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
          .toList(),
      stops: (value['stops'] as List)
          .map((s) => ShareStop.fromJson(Map<String, dynamic>.from(s as Map)))
          .toList(),
      start: point(value['start'] as Map),
      destination: point(value['destination'] as Map),
      completed: (value['completed'] as List).cast<String>().toSet(),
    );
  }
  static SharedSnapshot fromPlan(PlanningController model) {
    final plan = model.result;
    if (!model.proposalReady || plan == null || plan.geometry.isEmpty) {
      throw const SharingFailure(
        'Refresh your plan to share its original route.',
      );
    }
    final route = [
      for (final segment in plan.geometry)
        for (final point in segment) List<double>.from(point),
    ];
    if (route.length > 1600) {
      throw const SharingFailure(
        'This route is too large to share without changing it. Your trip is kept.',
      );
    }
    final errands = {for (final e in model.activeErrands) e.id: e};
    final stops = <ShareStop>[];
    for (final stop in plan.schedule.stops) {
      for (final task in stop.tasks) {
        final e = errands[task.errandId],
            place = model.displayChoices[task.errandId];
        if (e == null || place == null || !place.hasCoordinates) {
          throw const SharingFailure(
            'Refresh the missing stop location before sharing.',
          );
        }
        stops.add(
          ShareStop(
            e.id,
            e.title,
            place.savedPlaceId != null || place.kind == PlaceKind.saved
                ? 'Chosen place'
                : model.displayPlace(place),
            place.latitude!,
            place.longitude!,
          ),
        );
      }
    }
    if (!model.day.fromPlace.hasCoordinates ||
        !model.day.toPlace.hasCoordinates) {
      throw const SharingFailure(
        'Refresh the start and destination before sharing.',
      );
    }
    final start = [
      model.day.fromPlace.latitude!,
      model.day.fromPlace.longitude!,
    ];
    final destination = [
      model.day.toPlace.latitude!,
      model.day.toPlace.longitude!,
    ];
    final sourceId = sha256
        .convert(
          utf8.encode(
            jsonEncode({
              'date': model.day.date,
              'route': route,
              'stops': stops.map((s) => s.toJson()).toList(),
              'start': start,
              'destination': destination,
            }),
          ),
        )
        .toString();
    return SharedSnapshot(
      sourceId: sourceId,
      route: route,
      stops: stops,
      start: start,
      destination: destination,
    );
  }

  bool matches(AcceptedItinerary plan) {
    final pairs = [
      for (final stop in plan.stops)
        for (final id in stop.errandIds) (id, stop.place),
    ];
    final errands = {for (final e in plan.day.errands) e.id: e};
    return plan.day.fromPlace.latitude == start[0] &&
        plan.day.fromPlace.longitude == start[1] &&
        plan.day.toPlace.latitude == destination[0] &&
        plan.day.toPlace.longitude == destination[1] &&
        pairs.length == stops.length &&
        List.generate(pairs.length, (i) {
          final (id, place) = pairs[i];
          final shared = stops[i];
          return id == shared.id &&
              errands[id]?.title == shared.title &&
              place.hasCoordinates &&
              place.latitude == shared.latitude &&
              place.longitude == shared.longitude;
        }).every((v) => v);
  }

  SharedSnapshot withCompleted(Set<String> completed) => SharedSnapshot(
    sourceId: sourceId,
    route: route,
    stops: stops,
    start: start,
    destination: destination,
    completed: completed,
  );

  List<PlaceIntent> get places => [
    PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Start',
      latitude: start[0],
      longitude: start[1],
      source: 'shared_google_route_snapshot',
    ),
    for (final s in stops)
      PlaceIntent(
        kind: PlaceKind.specific,
        label: s.place,
        latitude: s.latitude,
        longitude: s.longitude,
        source: 'shared_google_route_snapshot',
      ),
    PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Destination',
      latitude: destination[0],
      longitude: destination[1],
      source: 'shared_google_route_snapshot',
    ),
  ];
}

class ShareAccess {
  const ShareAccess({
    required this.id,
    required this.token,
    required this.role,
  });
  final String id, token, role;
  Map<String, String> toJson() => {'id': id, 'token': token, 'role': role};
  factory ShareAccess.fromJson(Map<String, dynamic> value) => ShareAccess(
    id: value['id'] as String,
    token: value['token'] as String,
    role: value['role'] as String,
  );
}

class SharedTrip {
  SharedTrip.fromJson(Map<String, dynamic> value)
    : snapshot = SharedSnapshot.fromJson(
        Map<String, dynamic>.from(value['snapshot'] as Map),
      ),
      expiresAt = DateTime.fromMillisecondsSinceEpoch(
        (value['expiresAt'] as num).toInt() * 1000,
      ),
      revision = value['revision'] as int,
      broadcastRevision = value['broadcastRevision'] as int? ?? 0,
      broadcasting = value['broadcasting'] == true,
      ownerSharing = value['ownerSharing'] == true,
      paired = value['paired'] == true,
      ownerLocation = value['ownerLocation'] is Map
          ? Map<String, dynamic>.from(value['ownerLocation'] as Map)
          : null,
      recipientLocation = value['recipientLocation'] is Map
          ? Map<String, dynamic>.from(value['recipientLocation'] as Map)
          : null;
  final SharedSnapshot snapshot;
  final DateTime expiresAt;
  final int revision, broadcastRevision;
  final bool broadcasting, ownerSharing, paired;
  final Map<String, dynamic>? ownerLocation, recipientLocation;
  static bool fresh(Map<String, dynamic>? fix, DateTime now) {
    if (fix == null ||
        fix['recordedAt'] is! num ||
        fix['receivedAt'] is! num ||
        fix['latitude'] is! num ||
        fix['longitude'] is! num ||
        fix['accuracy'] is! num) {
      return false;
    }
    final lat = fix['latitude'] as num,
        lon = fix['longitude'] as num,
        accuracy = fix['accuracy'] as num;
    if (!lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        !accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 50000) {
      return false;
    }
    final seconds = now.millisecondsSinceEpoch / 1000;
    return [fix['recordedAt'], fix['receivedAt']].every(
      (t) => (t as num).isFinite && seconds - t >= 0 && seconds - t <= 45,
    );
  }
}
