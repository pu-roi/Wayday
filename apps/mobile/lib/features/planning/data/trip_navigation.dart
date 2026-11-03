import 'dart:async';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../today/domain/day.dart';
import '../domain/planning_models.dart';
import '../domain/trip_waypoints.dart';
import 'planning_budget.dart';

export '../domain/trip_waypoints.dart';
export '../domain/navigation_models.dart';
import '../domain/navigation_models.dart';

enum NavigationSignalKind {
  arrival,
  gpsLost,
  gpsAvailable,
  routeChanged,
  progress,
  offRoute,
  failure,
}

class NavigationSignal {
  const NavigationSignal(this.kind, {this.target, this.progress, this.message});
  final NavigationSignalKind kind;
  final NavigationCoordinate? target;
  final NavigationProgress? progress;
  final String? message;
}

/// SDK boundary. Tests substitute a driver without opening a paid session.
abstract class NavigationDriver {
  Stream<NavigationSignal> get events;
  Future<void> initialize(NavigationAppearance? colors);
  Future<void> destinations(List<TripWaypoint> stops, TravelProfile profile);
  Future<void> start();
  Future<void> advance();
  Future<List<NavigationLeg>> segments();
  Future<void> stop();
}

abstract interface class PreparedNavigationDriver {
  Future<void> prepare(
    List<TripWaypoint> points,
    TravelProfile profile,
    NavigationCoordinate origin,
  );
}

class GoogleNavigationDriver implements NavigationDriver {
  final _events = StreamController<NavigationSignal>.broadcast(sync: true);
  final List<StreamSubscription<dynamic>> _listeners = [];
  int _revision = 0;
  bool _initialized = false;
  @override
  Stream<NavigationSignal> get events => _events.stream;
  @override
  Future<void> initialize(NavigationAppearance? colors) async {
    if (_initialized) await stop();
    final revision = ++_revision;
    final accepted =
        await nav.GoogleMapsNavigator.areTermsAccepted() ||
        await nav.GoogleMapsNavigator.showTermsAndConditionsDialog(
          'Wayday',
          'Wayday',
          uiParams: colors == null
              ? null
              : nav.TermsAndConditionsUIParams(
                  backgroundColor: colors.backgroundColor,
                  titleColor: colors.titleColor,
                  mainTextColor: colors.mainTextColor,
                  acceptButtonTextColor: colors.acceptButtonTextColor,
                  cancelButtonTextColor: colors.cancelButtonTextColor,
                ),
        );
    if (!accepted) {
      throw const PlanningFailure(
        'Accept Google navigation terms to start guidance.',
        kind: 'terms',
      );
    }
    if (revision != _revision) return;
    await nav.GoogleMapsNavigator.initializeNavigationSession(
      abnormalTerminationReportingEnabled: false,
      taskRemovedBehavior: nav.TaskRemovedBehavior.quitService,
    );
    _initialized = true;
    if (revision != _revision) {
      await stop();
      return;
    }
    void emit(NavigationSignal event) {
      if (revision == _revision) _events.add(event);
    }

    _listeners.add(
      nav.GoogleMapsNavigator.setOnArrivalListener(
        (event) => emit(
          NavigationSignal(
            NavigationSignalKind.arrival,
            target: event.waypoint.target == null
                ? null
                : NavigationCoordinate(
                    latitude: event.waypoint.target!.latitude,
                    longitude: event.waypoint.target!.longitude,
                  ),
          ),
        ),
      ),
    );
    _listeners.add(
      nav.GoogleMapsNavigator.setOnRouteChangedListener(
        () => emit(const NavigationSignal(NavigationSignalKind.routeChanged)),
      ),
    );
    _listeners.add(
      await nav.GoogleMapsNavigator.setOnGpsAvailabilityChangeListener(
        (event) => emit(
          NavigationSignal(
            event.isGpsLost || !event.isGpsValidForNavigation
                ? NavigationSignalKind.gpsLost
                : NavigationSignalKind.gpsAvailable,
          ),
        ),
      ),
    );
  }

  @override
  Future<void> destinations(
    List<TripWaypoint> stops,
    TravelProfile profile,
  ) async {
    final status = await nav.GoogleMapsNavigator.setDestinations(
      nav.Destinations(
        displayOptions: nav.NavigationDisplayOptions(),
        waypoints: [
          for (final point in stops)
            nav.NavigationWaypoint.withLatLngTarget(
              title: point.place.label,
              target: nav.LatLng(
                latitude: point.coordinate!.latitude,
                longitude: point.coordinate!.longitude,
              ),
            ),
        ],
        routingOptions: nav.RoutingOptions(
          locationTimeoutMs: 30000,
          travelMode: switch (profile) {
            TravelProfile.walk => nav.NavigationTravelMode.walking,
            TravelProfile.motor => nav.NavigationTravelMode.twoWheeler,
            TravelProfile.bike => nav.NavigationTravelMode.cycling,
            TravelProfile.sedan ||
            TravelProfile.truck => nav.NavigationTravelMode.driving,
          },
        ),
      ),
    );
    if (status != nav.NavigationRouteStatus.statusOk) {
      throw TripNavigation.routeFailure(status);
    }
  }

  @override
  Future<void> start() => nav.GoogleMapsNavigator.startGuidance();
  @override
  Future<void> advance() async {
    await nav.GoogleMapsNavigator.continueToNextDestination();
  }

  @override
  Future<List<NavigationLeg>> segments() async =>
      (await nav.GoogleMapsNavigator.getRouteSegments())
          .map(
            (s) => NavigationLeg([
              for (final p in s.latLngs ?? <nav.LatLng>[])
                if (p != null)
                  NavigationCoordinate(
                    latitude: p.latitude,
                    longitude: p.longitude,
                  ),
            ]),
          )
          .toList();
  @override
  Future<void> stop() async {
    _revision++;
    for (final listener in _listeners) {
      await listener.cancel();
    }
    _listeners.clear();
    if (!_initialized) return;
    try {
      await nav.GoogleMapsNavigator.stopGuidance();
    } finally {
      await nav.GoogleMapsNavigator.cleanup();
    }
    _initialized = false;
  }
}

class TripNavigation {
  TripNavigation(
    this.budget, {
    NavigationDriver? driver,
    this.provider = TripMapProvider.google,
  }) : driver = driver ?? GoogleNavigationDriver();
  final TripMapProvider provider;
  final PlanningBudget budget;
  final NavigationDriver driver;
  bool initialized = false;
  Future<void>? _flight;
  Future<void>? _stopping;
  Future<void>? _initializing;
  int _revision = 0;
  bool get settling => _stopping != null;
  Stream<NavigationSignal> get events => driver.events;
  Future<void> initialize({NavigationAppearance? colors}) async {
    final revision = _revision;
    await _stopping;
    if (revision != _revision) return;
    if (_initializing != null) return _initializing!;
    final work = driver.initialize(colors);
    _initializing = work;
    try {
      await work;
      if (revision == _revision) initialized = true;
    } finally {
      if (identical(_initializing, work)) _initializing = null;
    }
  }

  Future<void> guide(List<TripWaypoint> points, TravelProfile profile) {
    if (_flight != null) return _flight!;
    final work = _guide(points, profile);
    _flight = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_flight, work)) _flight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_flight, work)) _flight = null;
        },
      ),
    );
    return work;
  }

  Future<void> _guide(List<TripWaypoint> points, TravelProfile profile) async {
    final revision = _revision;
    if (!initialized) {
      throw const PlanningFailure('Start the navigation session first.');
    }
    if (profile == TravelProfile.bike) {
      throw const PlanningFailure(
        'Bicycle guidance has not been qualified in the Philippines. Choose a supported travel mode.',
        kind: 'unsupported_profile',
      );
    }
    if (points.isEmpty || points.length > 25) {
      throw const PlanningFailure(
        'Embedded navigation supports up to 25 remaining stops including the destination. Your saved plan is kept.',
        kind: 'waypoints',
      );
    }
    if (points.any((p) => p.coordinate?.valid != true)) {
      throw const PlanningFailure(
        'Refresh the expired or missing stop location in your saved plan before guidance.',
        kind: 'location_reference',
      );
    }
    // Reserve immediately before dispatch, per waypoint. Dispatched failures remain accounted.
    if (provider == TripMapProvider.google) {
      await budget.google('navigation', points.length, 25000);
    }
    if (revision != _revision) {
      if (provider == TripMapProvider.google) {
        await budget.google('navigation', points.length, 25000, release: true);
      }
      return;
    }
    await driver.destinations(points, profile);
    if (revision != _revision) return;
    await driver.start();
  }

  static PlanningFailure routeFailure(
    nav.NavigationRouteStatus status,
  ) => PlanningFailure(switch (status) {
    nav.NavigationRouteStatus.locationUnavailable ||
    nav.NavigationRouteStatus.locationUnknown =>
      'Google navigation could not establish your location. Check location services and try again.',
    nav.NavigationRouteStatus.apiKeyNotAuthorized =>
      'Google navigation access was denied. Your saved plan is kept.',
    nav.NavigationRouteStatus.quotaExceeded ||
    nav.NavigationRouteStatus.quotaCheckFailed =>
      'Google navigation is temporarily unavailable. Try another map or retry later. Your trip progress is kept.',
    nav.NavigationRouteStatus.networkError =>
      'The navigation route could not load. Check your internet connection.',
    _ =>
      'Google could not calculate this navigation route and travel mode. Your saved plan is kept.',
  }, kind: 'navigation_${status.name}');
  Future<void> advance() {
    if (_flight != null) return _flight!;
    final revision = _revision;
    final work = () async {
      await driver.advance();
      if (revision == _revision) await driver.start();
    }();
    _flight = work;
    unawaited(
      work.then(
        (_) {
          if (identical(_flight, work)) _flight = null;
        },
        onError: (Object _, StackTrace _) {
          if (identical(_flight, work)) _flight = null;
        },
      ),
    );
    return work;
  }

  Future<void> stop() {
    if (_stopping != null) return _stopping!;
    _revision++;
    initialized = false;
    final work = () async {
      // A caller timeout is not cancellation. Never overlap a second dispatch.
      await _initializing?.catchError((Object _) {});
      await _flight?.catchError((Object _) {});
      await driver.stop();
    }();
    _stopping = work;
    unawaited(
      work.then(
        (_) => _stopping = null,
        onError: (Object _, StackTrace _) => _stopping = null,
      ),
    );
    return work;
  }
}
