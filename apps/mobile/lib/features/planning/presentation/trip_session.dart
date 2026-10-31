import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../today/domain/day.dart';
import '../data/itinerary_repository.dart';
import '../data/trip_navigation.dart';
import '../domain/planning_models.dart';

enum TripStage { idle, terms, location, map, route, guiding, paused, failed }

abstract class TripMapPort {
  Future<nav.LatLng?> location();
  Future<void> enable();
  Future<void> follow(TravelProfile profile);
  Future<void> overview(
    List<nav.RouteSegment> segments,
    List<TripWaypoint> points,
  );
}

/// Owns user progress independently from the native navigator and map viewport.
class TripSession extends ChangeNotifier {
  TripSession({
    required this.plan,
    required this.navigation,
    required this.acquireLocation,
    required this.save,
    this.mapTimeout = const Duration(seconds: 10),
    this.locationTimeout = const Duration(seconds: 30),
    this.routeTimeout = const Duration(seconds: 45),
  }) {
    _events = navigation.events.listen(_onEvent);
  }
  AcceptedItinerary plan;
  final TripNavigation navigation;
  final Future<nav.LatLng> Function() acquireLocation;
  final Future<void> Function(AcceptedItinerary) save;
  final Duration mapTimeout, locationTimeout, routeTimeout;
  late final StreamSubscription<NavigationSignal> _events;
  TripStage stage = TripStage.idle;
  bool mapRequested = false,
      saving = false,
      arrived = false,
      gpsLost = false,
      overview = false,
      following = true;
  String? error;
  nav.LatLng? initialPosition;
  TripMapPort? _map;
  final _mapReady = Completer<TripMapPort>();
  Future<void>? _startFlight;
  bool _disposed = false;
  int _revision = 0;
  int _overviewRevision = 0;
  Future<void>? _saveFlight;
  List<TripWaypoint> _submitted = [];
  int _index = 0;
  bool get active => stage == TripStage.guiding;
  bool get busy =>
      saving ||
      {
        TripStage.terms,
        TripStage.location,
        TripStage.map,
        TripStage.route,
      }.contains(stage);
  TripWaypoint get current =>
      _submitted.isNotEmpty && _index < _submitted.length
      ? _submitted[_index]
      : remainingWaypoints(plan).first;
  List<TripWaypoint> get remaining => _submitted.isNotEmpty
      ? _submitted.skip(_index).toList()
      : remainingWaypoints(plan);
  List<String> get currentErrands => current.errandIds;
  String? get currentErrandId =>
      currentErrands.where((id) => !plan.completed.contains(id)).firstOrNull;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int revision) => !_disposed && revision == _revision;
  void attach(TripMapPort map) {
    _map = map;
    if (!_mapReady.isCompleted) _mapReady.complete(map);
  }

  Future<void> start({nav.TermsAndConditionsUIParams? colors}) {
    if (_startFlight != null) return _startFlight!;
    final work = _start(colors);
    _startFlight = work;
    unawaited(
      work.then(
        (_) => _startFlight = null,
        onError: (Object _, StackTrace _) => _startFlight = null,
      ),
    );
    return work;
  }

  Future<void> _start(nav.TermsAndConditionsUIParams? colors) async {
    if (active) return;
    final revision = ++_revision;
    error = null;
    try {
      if (navigation.settling || _saveFlight != null) {
        throw const PlanningFailure(
          'The previous navigation request or progress save is still finishing. Try again shortly.',
        );
      }
      if (plan.day.profile == TravelProfile.truck &&
          !plan.lightPickupConfirmed) {
        throw const PlanningFailure(
          'Confirm a compatible light pickup before starting ordinary driving guidance.',
        );
      }
      stage = TripStage.terms;
      _emit();
      await navigation.initialize(colors: colors);
      if (!_valid(revision)) return;
      stage = TripStage.location;
      _emit();
      initialPosition = await acquireLocation().timeout(locationTimeout);
      if (!_valid(revision)) return;
      stage = TripStage.map;
      mapRequested = true;
      _emit();
      final map = _map ?? await _mapReady.future.timeout(mapTimeout);
      if (!_valid(revision)) return;
      await map.enable();
      stage = TripStage.location;
      _emit();
      await _waitForLocation(map, revision).timeout(locationTimeout);
      if (!_valid(revision)) return;
      _submitted = remainingWaypoints(plan);
      _index = 0;
      stage = TripStage.route;
      _emit();
      await navigation
          .guide(_submitted, plan.day.profile)
          .timeout(routeTimeout);
      if (!_valid(revision)) return;
      await map.follow(plan.day.profile);
      if (!_valid(revision)) return;
      stage = TripStage.guiding;
      arrived = false;
      gpsLost = false;
      following = true;
      overview = false;
      _emit();
    } catch (failure) {
      if (!_valid(revision)) return;
      final failedStage = stage;
      _revision++;
      stage = TripStage.failed;
      error = failure is PlanningFailure
          ? failure.message
          : failure is TimeoutException
          ? switch (failedStage) {
              TripStage.map =>
                'The navigation map did not become ready. Retry guidance.',
              TripStage.location =>
                'Your navigation location is unavailable. Check location services, move where GPS is available and retry.',
              _ =>
                'The navigation route did not finish loading. Your progress is kept. Retry when the request has finished.',
            }
          : 'Navigation could not start. Your saved plan is kept. Try again.';
      unawaited(navigation.stop().catchError((Object _) {}));
      _emit();
    }
  }

  Future<void> _waitForLocation(TripMapPort map, int revision) async {
    while (_valid(revision)) {
      if (await map.location() != null) return;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
  }

  void _onEvent(NavigationSignal event) {
    if (!active) return;
    switch (event.kind) {
      case NavigationSignalKind.arrival:
        final target = event.target;
        if (target != null &&
            target.latitude == current.place.latitude &&
            target.longitude == current.place.longitude) {
          arrived = true;
        }
      case NavigationSignalKind.gpsLost:
        gpsLost = true;
      case NavigationSignalKind.gpsAvailable:
        gpsLost = false;
      case NavigationSignalKind.routeChanged:
        if (overview) unawaited(showWholeTrip());
    }
    _emit();
  }

  Future<void> complete(String id) async {
    if (busy ||
        !active ||
        id != currentErrandId ||
        plan.completed.contains(id)) {
      return;
    }
    final revision = _revision;
    saving = true;
    error = null;
    _emit();
    try {
      final before = plan;
      final updated = plan.complete(id);
      final write = save(updated);
      _saveFlight = write;
      unawaited(
        write.then(
          (_) {
            if (!_disposed && identical(plan, before)) {
              plan = updated;
              _emit();
            }
            if (identical(_saveFlight, write)) _saveFlight = null;
          },
          onError: (Object _, StackTrace _) {
            if (identical(_saveFlight, write)) _saveFlight = null;
          },
        ),
      );
      await write.timeout(const Duration(seconds: 10));
      if (!_valid(revision)) return;
      plan = updated;
      if (current.errandIds.every(plan.completed.contains) &&
          !current.finalDestination) {
        await navigation.advance().timeout(routeTimeout);
        if (!_valid(revision)) return;
        _index++;
        _overviewRevision++;
        arrived = false;
        if (overview) await showWholeTrip();
      }
    } catch (failure) {
      if (!_valid(revision)) return;
      error = failure is PlanningFailure
          ? failure.message
          : 'Progress or the next route could not be updated. Your saved progress is kept. Resume guidance to recover.';
      stage = TripStage.failed;
      unawaited(navigation.stop().catchError((Object _) {}));
    } finally {
      if (!_disposed) {
        saving = false;
        _emit();
      }
    }
  }

  Future<void> showWholeTrip() async {
    if (!active || _map == null) return;
    final revision = _revision;
    final viewRevision = ++_overviewRevision;
    try {
      final segments = await navigation.driver.segments().timeout(
        const Duration(seconds: 10),
      );
      if (!_valid(revision) || !active || viewRevision != _overviewRevision) {
        return;
      }
      await _map!.overview(segments, remaining);
      if (!_valid(revision) || viewRevision != _overviewRevision) return;
      overview = true;
      following = false;
      error = null;
      _emit();
    } catch (_) {
      if (_valid(revision) && viewRevision == _overviewRevision) {
        error =
            'The whole-trip route could not be displayed. Guidance and your choices are kept.';
        _emit();
      }
    }
  }

  void cameraFollowing(bool value) {
    following = value;
    if (value) {
      overview = false;
      _overviewRevision++;
    }
    _emit();
  }

  void cameraGesture() {
    _overviewRevision++;
    overview = false;
    following = false;
    _emit();
  }

  Future<void> pause() async {
    _revision++;
    stage = TripStage.paused;
    _emit();
    unawaited(navigation.stop().catchError((Object _) {}));
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_events.cancel());
    unawaited(navigation.stop().catchError((Object _) {}));
    super.dispose();
  }
}
