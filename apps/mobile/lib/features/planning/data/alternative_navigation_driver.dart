import 'dart:async';
import 'package:flutter/services.dart';
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import 'alternative_route_client.dart';
import 'trip_navigation.dart';

/// Ordered transient routes and one active native leg. Only independently
/// validated navigation snapshots enter routing; movement never requests routes.
class AlternativeNavigationDriver
    implements NavigationDriver, PreparedNavigationDriver {
  AlternativeNavigationDriver({
    required this.client,
    required this.acquireLocation,
    required this.tripId,
    MethodChannel? channel,
    DateTime Function()? now,
  }) : channel =
           channel ?? const MethodChannel('wayday/alternative_navigation'),
       now = now ?? DateTime.now;
  final AlternativeRouteClient client;
  final Future<NavigationCoordinate> Function() acquireLocation;
  final String tripId;
  final MethodChannel channel;
  final DateTime Function() now;
  final _events = StreamController<NavigationSignal>.broadcast(sync: true);
  final _changes = StreamController<void>.broadcast(sync: true);
  Stream<void> get changes => _changes.stream;
  @override
  Stream<NavigationSignal> get events => _events.stream;
  List<NavigationLeg> _legs = [];
  List<TripWaypoint> _points = [];
  TravelProfile _profile = TravelProfile.walk;
  static int _sessions = 0;
  int _index = 0, _revision = 0;
  String? _session;
  NavigationProgress? progress;
  NavigationCoordinate? position;
  bool voiceAvailable = false, muted = false;
  Future<void>? _rerouting;
  Future<void>? _preparing;
  DateTime? _lastReroute;
  bool _rerouteFailed = false;
  bool get rerouting => _rerouting != null;

  @override
  Future<void> prepare(
    List<TripWaypoint> points,
    TravelProfile profile,
    NavigationCoordinate origin,
  ) {
    if (_preparing != null) return _preparing!;
    final work = _prepare(points, profile, origin);
    _preparing = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_preparing, work)) _preparing = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_preparing, work)) _preparing = null;
        },
      ),
    );
    return work;
  }

  Future<void> _prepare(
    List<TripWaypoint> points,
    TravelProfile profile,
    NavigationCoordinate origin,
  ) async {
    final issue = alternativeWaypointIssue(points);
    if (issue != null) {
      throw PlanningFailure(issue, kind: 'destination_restricted');
    }
    final revision = _revision;
    final legs = await client.route([
      origin,
      for (final p in points)
        NavigationCoordinate(
          latitude: p.coordinate!.latitude,
          longitude: p.coordinate!.longitude,
        ),
    ], profile);
    if (revision != _revision) return;
    _points = List.unmodifiable(points);
    _profile = profile;
    _legs = legs;
    _index = 0;
    position = origin;
  }

  @override
  Future<void> initialize(NavigationAppearance? colors) async {
    _revision++;
    final id = '$tripId:osm:${++_sessions}';
    _session = id;
    channel.setMethodCallHandler((call) async {
      if (call.method != 'event' || _session != id) return;
      final data = Map<String, dynamic>.from(call.arguments as Map);
      if (data['session'] != id) return;
      final kind = data['kind'];
      if (kind == 'voice') voiceAvailable = data['available'] == true;
      if (data['latitude'] is num && data['longitude'] is num) {
        final fix = NavigationCoordinate(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
        );
        if (fix.valid) position = fix;
      }
      switch (kind) {
        case 'progress':
          if (position == null) return;
          progress = NavigationProgress(
            position: position!,
            instruction: data['instruction'] as String? ?? '',
            distance: (data['distance'] as num).toDouble(),
            duration: (data['duration'] as num).toDouble(),
            bearing: (data['bearing'] as num).toDouble(),
            accuracy: (data['accuracy'] as num).toDouble(),
            step: data['step'] as int,
          );
          _events.add(
            NavigationSignal(NavigationSignalKind.progress, progress: progress),
          );
        case 'arrival':
          if (_points.isNotEmpty && _index < _points.length) {
            _events.add(
              NavigationSignal(
                NavigationSignalKind.arrival,
                target: NavigationCoordinate(
                  latitude: _points[_index].coordinate!.latitude,
                  longitude: _points[_index].coordinate!.longitude,
                ),
              ),
            );
          }
        case 'gpsLost':
          _events.add(const NavigationSignal(NavigationSignalKind.gpsLost));
        case 'gpsAvailable':
          _events.add(
            const NavigationSignal(NavigationSignalKind.gpsAvailable),
          );
        case 'offRoute':
          if (!_rerouteFailed) unawaited(_reroute());
        case 'failure':
          _events.add(
            const NavigationSignal(
              NavigationSignalKind.failure,
              message:
                  'Device guidance is unavailable. Check location access and retry guidance.',
            ),
          );
      }
      _changes.add(null);
    });
    await channel.invokeMethod<void>('initialize', {'session': id});
    if (_session != id) {
      await channel.invokeMethod<void>('stop', {'session': id});
    }
  }

  @override
  Future<void> destinations(
    List<TripWaypoint> stops,
    TravelProfile profile,
  ) async {
    if (_legs.isEmpty) await prepare(stops, profile, await acquireLocation());
  }

  @override
  Future<void> start() async {
    final id = _session;
    if (id == null || _index >= _legs.length) {
      throw const PlanningFailure(
        'The alternative route is unavailable. Retry guidance.',
      );
    }
    await channel.invokeMethod<void>('startLeg', {
      'session': id,
      'leg': {
        ..._legs[_index].toJson(),
        'mode': _profile == TravelProfile.walk ? 'walking' : 'driving',
      },
    });
    _changes.add(null);
  }

  @override
  Future<void> advance() async {
    if (_rerouting != null) await _rerouting;
    _index++;
    progress = null;
  }

  @override
  Future<List<NavigationLeg>> segments() async => _legs.skip(_index).toList();
  Future<void> setMuted(bool value) async {
    final id = _session;
    if (id == null) return;
    muted = value;
    voiceAvailable =
        await channel.invokeMethod<bool>('voice', {
          'session': id,
          'muted': value,
        }) ??
        false;
    _changes.add(null);
  }

  Future<void> _reroute() {
    if (_rerouting != null) return _rerouting!;
    if (_session == null ||
        _rerouteFailed ||
        position == null ||
        (_lastReroute != null &&
            now().difference(_lastReroute!) < const Duration(seconds: 15))) {
      return Future.value();
    }
    final revision = _revision, id = _session;
    _lastReroute = now();
    _events.add(const NavigationSignal(NavigationSignalKind.offRoute));
    final work = () async {
      try {
        final remaining = _points.skip(_index).toList();
        final issue = alternativeWaypointIssue(remaining);
        if (issue != null) throw PlanningFailure(issue, kind: 'target_expired');
        final fresh = await client.route([
          position!,
          for (final p in remaining)
            NavigationCoordinate(
              latitude: p.coordinate!.latitude,
              longitude: p.coordinate!.longitude,
            ),
        ], _profile);
        if (_revision != revision || _session != id) return;
        _points = remaining;
        _legs = fresh;
        _index = 0;
        await start();
        _events.add(const NavigationSignal(NavigationSignalKind.routeChanged));
      } catch (_) {
        if (_revision == revision && _session == id) {
          _rerouteFailed = true;
          _events.add(
            const NavigationSignal(
              NavigationSignalKind.failure,
              message:
                  'The route update failed. Your errands and progress are kept. Retry guidance explicitly.',
            ),
          );
        }
      }
    }();
    _rerouting = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_rerouting, work)) _rerouting = null;
      }),
    );
    return work;
  }

  @override
  Future<void> stop() async {
    final id = _session;
    _session = null;
    _revision++;
    if (id != null) await channel.invokeMethod<void>('stop', {'session': id});
    if (id != null) channel.setMethodCallHandler(null);
    // Keep the actual reroute flight until it settles; ignore its late result.
    await _rerouting;
    await _preparing?.catchError((Object _) {});
    _legs = [];
    _points = [];
    progress = null;
    _rerouteFailed = false;
    voiceAvailable = false;
  }
}
