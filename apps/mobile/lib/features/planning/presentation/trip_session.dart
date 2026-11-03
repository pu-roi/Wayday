import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../today/domain/day.dart';
import '../data/itinerary_repository.dart';
import '../data/trip_navigation.dart';
import '../domain/planning_models.dart';
import '../data/navigation_target_resolver.dart';

enum TripStage { idle, terms, location, map, route, guiding, paused, failed }

abstract class TripMapPort {
  Future<NavigationCoordinate?> location();
  Future<void> enable();
  Future<void> disable();
  Future<void> follow(TravelProfile profile);
  Future<void> overview(
    List<NavigationLeg> segments,
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
    this.createNavigation,
    this.persistProvider,
    this.acquireAlternativeLocation,
    this.targetResolver,
    this.mapTimeout = const Duration(seconds: 10),
    this.locationTimeout = const Duration(seconds: 30),
    this.routeTimeout = const Duration(seconds: 45),
  }) {
    _events = navigation.events.listen(_onEvent);
  }
  AcceptedItinerary plan;
  TripNavigation navigation;
  final TripNavigation Function(TripMapProvider)? createNavigation;
  final Future<AcceptedItinerary> Function(String, TripMapProvider)?
  persistProvider;
  final Future<NavigationCoordinate> Function() acquireLocation;
  final Future<NavigationCoordinate> Function()? acquireAlternativeLocation;
  final NavigationTargetResolver? targetResolver;
  final Future<void> Function(AcceptedItinerary) save;
  final Duration mapTimeout, locationTimeout, routeTimeout;
  late StreamSubscription<NavigationSignal> _events;
  TripStage stage = TripStage.idle;
  bool mapRequested = false,
      saving = false,
      arrived = false,
      gpsLost = false,
      overview = false,
      following = true;
  String? error;
  static const _placeDetailsMessage =
      'Google place details are unavailable. Existing directions and your progress are kept. Retry explicitly.';
  bool placeDetailsUnavailable = false;
  void placeDetailsAvailability(bool available) {
    placeDetailsUnavailable = !available;
    if (!available) {
      error = _placeDetailsMessage;
    } else if (error == _placeDetailsMessage) {
      error = null;
    }
    _emit();
  }

  NavigationProgress? progress;
  NavigationCoordinate? initialPosition;
  TripMapPort? _map;
  var _mapReady = Completer<TripMapPort>();
  int mapSession = 0;
  bool switching = false;
  Future<void>? _switchFlight;
  TripMapProvider get provider => navigation.provider;
  Future<void>? _startFlight;
  bool _disposed = false;
  int _revision = 0;
  int _overviewRevision = 0;
  Future<void>? _saveFlight;
  List<TripWaypoint> _submitted = [];
  int _index = 0;
  bool get active => stage == TripStage.guiding;
  bool get busy =>
      switching ||
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
  String? get alternativeIssue =>
      targetResolver?.issue(remaining) ??
      (targetResolver == null
          ? alternativeDestinationIssue(remaining.map((p) => p.place))
          : null);

  Future<List<TripWaypoint>> _targets(
    List<TripWaypoint> points,
    TripMapProvider provider,
    int revision, {
    required bool allowFetch,
  }) async {
    if (targetResolver == null ||
        (provider == TripMapProvider.google &&
            points.every((p) => p.place.hasCoordinates))) {
      return points;
    }
    return targetResolver!.resolve(
      plan.runId,
      points,
      allowFetch: allowFetch,
      stillCurrent: () => _valid(revision),
    );
  }

  List<String> get currentErrands => current.errandIds;
  String? get currentErrandId =>
      currentErrands.where((id) => !plan.completed.contains(id)).firstOrNull;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  bool _valid(int revision) => !_disposed && revision == _revision;
  void attach(TripMapPort map, {int? session}) {
    if (_disposed || (session != null && session != mapSession)) return;
    _map = map;
    if (!_mapReady.isCompleted) _mapReady.complete(map);
  }

  Future<void> switchProvider(
    TripMapProvider provider, {
    NavigationAppearance? colors,
  }) {
    if (_switchFlight != null) return _switchFlight!;
    if (busy ||
        (provider == this.provider && plan.navigationProvider == provider) ||
        createNavigation == null ||
        persistProvider == null) {
      return Future.value();
    }
    final work = _switchProvider(provider, colors);
    _switchFlight = work;
    unawaited(
      work.whenComplete(() {
        if (identical(_switchFlight, work)) _switchFlight = null;
      }),
    );
    return work;
  }

  Future<void> _switchProvider(
    TripMapProvider provider,
    NavigationAppearance? colors,
  ) async {
    final revision = ++_revision;
    final old = navigation;
    TripNavigation? next;
    bool choiceSaved = false;
    switching = true;
    error = null;
    _emit();
    try {
      if (_saveFlight != null || old.settling || _startFlight != null) {
        throw const PlanningFailure(
          'The previous navigation or progress save is still finishing. Try again shortly.',
        );
      }
      var points = remainingWaypoints(plan);
      if (provider == TripMapProvider.openStreetMap) {
        final issue = alternativeIssue;
        if (issue != null) {
          throw PlanningFailure(issue, kind: 'destination_restricted');
        }
      }
      if (plan.day.profile == TravelProfile.bike ||
          (plan.day.profile == TravelProfile.truck &&
              !plan.lightPickupConfirmed)) {
        throw const PlanningFailure(
          'This travel mode is not qualified for alternative guidance.',
          kind: 'unsupported_profile',
        );
      }
      points = await _targets(
        points,
        provider,
        revision,
        allowFetch: true,
      ).timeout(routeTimeout);
      if (!_valid(revision)) return;
      next = createNavigation!(provider);
      final driver = next.driver;
      if (driver is PreparedNavigationDriver) {
        final origin = await (acquireAlternativeLocation ?? acquireLocation)()
            .timeout(locationTimeout);
        await (driver as PreparedNavigationDriver)
            .prepare(points, plan.day.profile, origin)
            .timeout(routeTimeout);
      }
      if (!_valid(revision)) return;
      final write = persistProvider!(plan.runId, provider);
      _saveFlight = write.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      // Do not detach a timed-out storage write or permit another switch while
      // it can still commit. This operation serializes with repository progress.
      final saved = await write;
      _saveFlight = null;
      plan = saved;
      choiceSaved = true;
      String identity(TripWaypoint point) =>
          '${placeKey(point.place)}:${point.errandIds.join(',')}:${point.finalDestination}';
      if (!listEquals(
        points.map(identity).toList(),
        remainingWaypoints(saved).map(identity).toList(),
      )) {
        throw const PlanningFailure(
          'Trip progress changed during preparation. Your latest progress is kept. Choose a provider again.',
          kind: 'target_changed',
        );
      }
      await _map?.disable();
      await old.stop();
      if (_disposed) return;
      await _events.cancel();
      navigation = next;
      choiceSaved = false;
      next = null;
      _events = navigation.events.listen(_onEvent);
      _map = null;
      _mapReady = Completer<TripMapPort>();
      mapSession++;
      mapRequested = false;
      progress = null;
      placeDetailsUnavailable = false;
      _submitted = [];
      _index = 0;
      stage = TripStage.paused;
      if (!_valid(revision)) return;
      switching = false;
      await start(colors: colors);
    } catch (failure) {
      _saveFlight = null;
      if (choiceSaved) {
        try {
          plan = await persistProvider!(plan.runId, old.provider);
        } catch (_) {
          // Never overwrite newer progress or recreate a finished trip during
          // recovery. The explicit error keeps retry/provider choices visible.
        }
      }
      if (_valid(revision)) {
        _revision++;
        error = failure is PlanningFailure
            ? failure.message
            : 'The navigation provider could not be changed. Your trip and progress are kept. Choose a provider or retry explicitly.';
        if (!old.initialized) stage = TripStage.failed;
      }
    } finally {
      if (next != null) await next.stop().catchError((Object _) {});
      switching = false;
      _emit();
    }
  }

  Future<void> start({
    NavigationAppearance? colors,
    bool allowTargetFetch = false,
  }) {
    if (_startFlight != null) return _startFlight!;
    final work = _start(colors, allowTargetFetch);
    _startFlight = work;
    unawaited(
      work.then(
        (_) => _startFlight = null,
        onError: (Object _, StackTrace _) => _startFlight = null,
      ),
    );
    return work;
  }

  Future<void> _start(
    NavigationAppearance? colors,
    bool allowTargetFetch,
  ) async {
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
      stage = TripStage.route;
      _emit();
      final points = await _targets(
        remainingWaypoints(plan),
        provider,
        revision,
        allowFetch: allowTargetFetch,
      ).timeout(routeTimeout);
      if (!_valid(revision)) return;
      // Style-ready callbacks can render markers before guide() runs. Publish
      // the validated snapshot before requesting either map, never original
      // SDK coordinates that may already have expired.
      _submitted = points;
      _index = 0;
      stage = TripStage.terms;
      _emit();
      await navigation.initialize(colors: colors);
      if (!_valid(revision)) return;
      stage = TripStage.location;
      _emit();
      initialPosition =
          await (provider == TripMapProvider.openStreetMap
                  ? (acquireAlternativeLocation ?? acquireLocation)()
                  : acquireLocation())
              .timeout(locationTimeout);
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

  void mapFailure(int session) {
    if (_disposed || session != mapSession) return;
    _revision++;
    stage = TripStage.failed;
    error =
        'The alternative map could not be displayed. Check the internet connection and retry, or choose Google. Your progress is kept.';
    mapRequested = false;
    _map = null;
    _mapReady = Completer<TripMapPort>();
    mapSession++;
    unawaited(navigation.stop().catchError((Object _) {}));
    _emit();
  }

  void _onEvent(NavigationSignal event) {
    if (!active) return;
    switch (event.kind) {
      case NavigationSignalKind.arrival:
        final target = event.target;
        if (target != null &&
            target.latitude == current.coordinate?.latitude &&
            target.longitude == current.coordinate?.longitude) {
          arrived = true;
        }
      case NavigationSignalKind.gpsLost:
        gpsLost = true;
      case NavigationSignalKind.gpsAvailable:
        gpsLost = false;
      case NavigationSignalKind.routeChanged:
        error = null;
        if (overview) unawaited(showWholeTrip());
      case NavigationSignalKind.progress:
        progress = event.progress;
      case NavigationSignalKind.offRoute:
        error = 'You are away from the route. Updating directions…';
      case NavigationSignalKind.failure:
        error =
            event.message ??
            'Guidance is unavailable. Retry guidance explicitly.';
        stage = TripStage.failed;
        unawaited(navigation.stop().catchError((Object _) {}));
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
    if (!following && !overview) return;
    _overviewRevision++;
    overview = false;
    following = false;
    _emit();
  }

  Future<void> pause() async {
    _revision++;
    stage = TripStage.paused;
    _emit();
    unawaited(_stopForeground());
  }

  Future<void> _stopForeground() async {
    final stopping = navigation.stop().catchError((Object _) {});
    try {
      await _map?.disable();
    } catch (_) {
      /* The navigator still must stop. */
    }
    await stopping;
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    unawaited(_events.cancel());
    unawaited(_stopForeground());
    super.dispose();
  }
}
