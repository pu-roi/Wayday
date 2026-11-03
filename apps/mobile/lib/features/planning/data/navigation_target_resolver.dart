import 'dart:async';
import 'dart:convert';
import '../domain/navigation_models.dart';
import '../domain/planning_models.dart';
import '../domain/trip_waypoints.dart';
import 'navigation_target_storage_stub.dart'
    if (dart.library.io) 'navigation_target_storage_native.dart'
    as storage;

const uiKitNavigationTargetsEnabled =
    bool.fromEnvironment('WAYDAY_PUBLIC_BUILD') &&
    bool.fromEnvironment('WAYDAY_ALTERNATIVE_NAVIGATION') &&
    bool.fromEnvironment('WAYDAY_UI_KIT_NAVIGATION_TARGETS');

/// Owns only UI Kit-acquired leases. The standard SDK pin cache is never read.
class NavigationTargetResolver {
  NavigationTargetResolver({
    required this.load,
    DateTime Function()? now,
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) : now = now ?? DateTime.now,
       read = read ?? storage.readTargets,
       write = write ?? storage.writeTargets;
  final Future<Map<Object?, Object?>> Function(String, int) load;
  final DateTime Function() now;
  final Future<String?> Function() read;
  final Future<void> Function(String) write;
  Future<List<TripWaypoint>>? _flight;
  static Future<List<TripWaypoint>>? _activeResolution;
  static Future<DateTime?>? _maintenanceFlight;
  static Future<void>? _cleanupFlight;
  static void Function()? onStoredChange;
  int _revision = 0;
  static const retention = Duration(days: 30);

  String? issue(Iterable<TripWaypoint> points) {
    if (points.isEmpty || points.length > 25) {
      return 'Navigation supports up to 25 remaining stops including the destination.';
    }
    for (final point in points) {
      final place = point.place;
      if (place.isGoogle || place.usesGoogleSdk) {
        if (place.providerPlaceId?.trim().isNotEmpty != true) {
          return 'A remaining Google destination has no Place ID. Google is retained.';
        }
      } else if (place.provider?.startsWith('google') == true ||
          !place.hasCoordinates) {
        return 'A remaining destination has an unsupported or unavailable location. Google is retained.';
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _read({bool recover = false}) async {
    final raw = await read();
    if (raw == null) return {};
    late final Map<String, dynamic> trips;
    late final bool pruned;
    try {
      final json = jsonDecode(raw) as Map;
      if (json['version'] != 1) throw const FormatException();
      trips = Map<String, dynamic>.from(json['trips'] as Map);
      pruned = _prune(trips);
    } catch (_) {
      if (recover) return {};
      throw const PlanningFailure(
        'Temporary navigation targets could not be read. Your trip is kept. Retry explicitly.',
        kind: 'target_storage',
      );
    }
    if (pruned) await _write(trips);
    return trips;
  }

  bool _prune(Map<String, dynamic> trips) {
    var changed = false;
    for (final trip in trips.values) {
      if (trip is! Map) throw const FormatException('Invalid target cache');
      for (final key in trip.keys.toList()) {
        final value = trip[key];
        if (value is! Map) throw const FormatException('Invalid target lease');
        if (value['phase'] != 'ready') {
          if (value.containsKey('lat') || value.containsKey('lon')) {
            trip[key] = {'source': 'googleUiKit', 'phase': 'expired'};
            changed = true;
          }
          continue;
        }
        var valid = false;
        try {
          final acquired = DateTime.parse(value['at'] as String);
          valid =
              value['source'] == 'googleUiKit' &&
              !acquired.isAfter(now()) &&
              now().isBefore(acquired.add(retention)) &&
              NavigationCoordinate(
                latitude: (value['lat'] as num).toDouble(),
                longitude: (value['lon'] as num).toDouble(),
              ).valid;
        } catch (_) {
          /* Remove invalid data rather than retaining coordinates. */
        }
        if (!valid) {
          trip[key] = {'source': 'googleUiKit', 'phase': 'expired'};
          changed = true;
        }
      }
    }
    return changed;
  }

  Future<void> _write(Map<String, dynamic> trips) async {
    _prune(trips);
    await write(jsonEncode({'version': 1, 'trips': trips}));
    onStoredChange?.call();
  }

  Future<List<TripWaypoint>> resolve(
    String tripId,
    List<TripWaypoint> points, {
    required bool allowFetch,
    required bool Function() stillCurrent,
  }) {
    if (_flight != null || _activeResolution != null) {
      return Future.error(
        const PlanningFailure(
          'A destination lookup is still finishing. Retry when it finishes.',
          kind: 'target_pending',
        ),
      );
    }
    final work = _resolve(tripId, points, allowFetch, stillCurrent);
    _flight = work;
    _activeResolution = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_flight, work)) _flight = null;
          if (identical(_activeResolution, work)) _activeResolution = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_flight, work)) _flight = null;
          if (identical(_activeResolution, work)) _activeResolution = null;
        },
      ),
    );
    return work;
  }

  Future<List<TripWaypoint>> _resolve(
    String tripId,
    List<TripWaypoint> points,
    bool allowFetch,
    bool Function() stillCurrent,
  ) async {
    await _cleanupFlight;
    await _maintenanceFlight;
    final problem = issue(points);
    if (problem != null) {
      throw PlanningFailure(problem, kind: 'target_unavailable');
    }
    void checkCurrent() {
      if (!stillCurrent()) {
        throw const PlanningFailure(
          'Destination preparation was cancelled. Your trip is kept.',
          kind: 'target_cancelled',
        );
      }
    }

    final needsGoogle = points.any(
      (p) => p.place.isGoogle || p.place.usesGoogleSdk,
    );
    final trips = needsGoogle
        ? await _read(recover: allowFetch)
        : <String, dynamic>{};
    checkCurrent();
    // There is one accepted trip. Discard obsolete caches without retaining history.
    final entries = Map<String, dynamic>.from((trips[tripId] as Map?) ?? {});
    final resolved = <TripWaypoint>[];
    for (var i = 0; i < points.length; i++) {
      checkCurrent();
      final point = points[i], place = point.place;
      final google = place.isGoogle || place.usesGoogleSdk;
      final id = google ? place.providerPlaceId! : null;
      NavigationCoordinate coordinate;
      var acquired = now().toUtc();
      DateTime? expires;
      if (id != null) {
        final cached = entries[id];
        Map<Object?, Object?>? data;
        if (cached is Map &&
            cached['source'] == 'googleUiKit' &&
            cached['phase'] == 'ready') {
          try {
            final at = DateTime.parse(cached['at'] as String).toUtc();
            final c = NavigationCoordinate(
              latitude: (cached['lat'] as num).toDouble(),
              longitude: (cached['lon'] as num).toDouble(),
            );
            if (c.valid &&
                !at.isAfter(now()) &&
                now().isBefore(at.add(retention))) {
              acquired = at;
              data = {'latitude': c.latitude, 'longitude': c.longitude};
            }
          } catch (_) {
            /* Invalid/expired data requires explicit recovery. */
          }
        }
        if (data == null) {
          if (!allowFetch) {
            throw const PlanningFailure(
              'Temporary destination coordinates are missing, expired or interrupted. Retry guidance to resolve the same places, or choose Google.',
              kind: 'target_recovery',
            );
          }
          final revision = ++_revision;
          entries[id] = {'source': 'googleUiKit', 'phase': 'pending'};
          await _write({tripId: entries});
          checkCurrent();
          try {
            data = await load(id, revision);
            checkCurrent();
            final millis = data['retrievedAtMillis'];
            if (data['placeId'] != id ||
                data['revision'] != revision ||
                data['resolved'] != true ||
                millis is! int ||
                millis <= 0 ||
                millis > now().millisecondsSinceEpoch ||
                data['latitude'] is! num ||
                data['longitude'] is! num) {
              throw const FormatException();
            }
            acquired = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
            final c = NavigationCoordinate(
              latitude: (data['latitude'] as num).toDouble(),
              longitude: (data['longitude'] as num).toDouble(),
            );
            if (!c.valid || !now().isBefore(acquired.add(retention))) {
              throw const FormatException();
            }
            entries[id] = {
              'source': 'googleUiKit',
              'phase': 'ready',
              'at': acquired.toIso8601String(),
              'lat': c.latitude,
              'lon': c.longitude,
            };
            checkCurrent();
            await _write({tripId: entries});
          } catch (error) {
            if (!stillCurrent()) rethrow;
            entries[id] = {'source': 'googleUiKit', 'phase': 'failed'};
            await _write({tripId: entries});
            if (error is PlanningFailure) rethrow;
            throw const PlanningFailure(
              'The exact Google destination could not be prepared. Your trip is kept. Retry explicitly.',
              kind: 'target_resolution',
            );
          }
        }
        coordinate = NavigationCoordinate(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
        );
        expires = acquired.add(retention);
      } else {
        coordinate = NavigationCoordinate(
          latitude: place.latitude!,
          longitude: place.longitude!,
        );
      }
      checkCurrent();
      resolved.add(
        point.withTarget(
          ResolvedNavigationTarget(
            tripId: tripId,
            waypointId: '$i:${placeKey(place)}',
            errandIds: List.unmodifiable(point.errandIds),
            coordinate: coordinate,
            source: google
                ? NavigationTargetSource.googleUiKit
                : NavigationTargetSource.independent,
            acquiredAt: acquired,
            expiresAt: expires,
            placeId: id,
          ),
        ),
      );
    }
    return List.unmodifiable(resolved);
  }

  static Future<void> clearFinished(
    String tripId, {
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) {
    // Capture earlier work before publishing this gate: later resolution waits
    // for cleanup, so awaiting a subsequently-created resolution would deadlock.
    final previous = _cleanupFlight, maintenance = _maintenanceFlight;
    final resolution = _activeResolution;
    final work = () async {
      await previous?.catchError((Object _) {});
      await maintenance?.catchError((Object _) => null);
      await resolution?.catchError((Object _) => <TripWaypoint>[]);
      final resolver = NavigationTargetResolver(
        read: read,
        write: write,
        load: (_, _) async => throw StateError('No lookup during cleanup'),
      );
      final trips = await resolver._read();
      trips.remove(tripId);
      await resolver._write(trips);
    }();
    _cleanupFlight = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_cleanupFlight, work)) _cleanupFlight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_cleanupFlight, work)) _cleanupFlight = null;
        },
      ),
    );
    return work;
  }

  /// Local cache hygiene only. No SDK, routing, GPS or background service.
  static Future<DateTime?> purgeStored({
    Future<String?> Function()? read,
    Future<void> Function(String)? write,
  }) {
    if (_cleanupFlight != null) {
      return _cleanupFlight!.then((_) => purgeStored(read: read, write: write));
    }
    if (_activeResolution != null) {
      return Future.value(DateTime.now().add(const Duration(seconds: 1)));
    }
    if (_maintenanceFlight != null) return _maintenanceFlight!;
    final work = () async {
      final resolver = NavigationTargetResolver(
        read: read,
        write: write,
        load: (_, _) async => throw StateError('No lookup during purge'),
      );
      final trips = await resolver._read();
      DateTime? next;
      for (final trip in trips.values.cast<Map<Object?, Object?>>()) {
        for (final value in trip.values.cast<Map<Object?, Object?>>()) {
          if (value['phase'] != 'ready') continue;
          final expiry = DateTime.parse(value['at'] as String).add(retention);
          if (next == null || expiry.isBefore(next)) next = expiry;
        }
      }
      return next;
    }();
    _maintenanceFlight = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_maintenanceFlight, work)) _maintenanceFlight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_maintenanceFlight, work)) _maintenanceFlight = null;
        },
      ),
    );
    return work;
  }
}
