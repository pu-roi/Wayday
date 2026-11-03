import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/planning/presentation/trip_session.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';
import 'trip_navigation_test.dart' show FakeNavigationDriver;

class FakeTripMap implements TripMapPort {
  int follows = 0, overviews = 0;
  Completer<NavigationCoordinate?>? fix;
  List<TripWaypoint> overviewPoints = [];
  @override
  Future<NavigationCoordinate?> location() async => fix == null
      ? const NavigationCoordinate(latitude: 14.58, longitude: 121.06)
      : await fix!.future;
  @override
  Future<void> enable() async {}
  @override
  Future<void> disable() async {}
  @override
  Future<void> follow(TravelProfile profile) async {
    follows++;
  }

  @override
  Future<void> overview(
    List<NavigationLeg> segments,
    List<TripWaypoint> points,
  ) async {
    overviews++;
    overviewPoints = points;
  }
}

AcceptedItinerary tripFixture() => AcceptedItinerary(
  day: fixture().copyWith(
    toPlace: const PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Destination',
      latitude: 14.62,
      longitude: 121.1,
    ),
  ),
  stops: [
    const ItineraryStop(pin, ['a', 'b']),
  ],
  acceptedAt: DateTime.now(),
);
TripSession tripSession(
  FakeNavigationDriver driver, {
  AcceptedItinerary? plan,
  Future<void> Function(AcceptedItinerary)? save,
  Duration? timeout,
}) => TripSession(
  plan: plan ?? tripFixture(),
  navigation: TripNavigation(
    PlanningBudget(read: () async => null, write: (_) async {}),
    driver: driver,
  ),
  acquireLocation: () async =>
      const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
  save: save ?? (_) async {},
  mapTimeout: timeout ?? const Duration(seconds: 10),
  locationTimeout: timeout ?? const Duration(seconds: 30),
);

void main() {
  test(
    'recenter cancels a late overview without another camera move',
    () async {
      final driver = FakeNavigationDriver()..pendingSegments = Completer();
      final map = FakeTripMap();
      final model = tripSession(driver)..attach(map);
      addTearDown(model.dispose);
      await model.start();
      final overview = model.showWholeTrip();
      model.cameraFollowing(true);
      driver.pendingSegments!.complete([]);
      await overview;
      expect(map.overviews, 0);
      expect(model.following, isTrue);
    },
  );
  test(
    'manual pan cancels a pending overview without resetting the camera',
    () async {
      final driver = FakeNavigationDriver()..pendingSegments = Completer();
      final map = FakeTripMap();
      final model = tripSession(driver)..attach(map);
      addTearDown(model.dispose);
      await model.start();
      final overview = model.showWholeTrip();
      model.cameraGesture();
      driver.pendingSegments!.complete([]);
      await overview;
      expect(map.overviews, 0);
      expect(model.following, isFalse);
    },
  );
  test(
    'failed advancement preserves completed work for session recovery',
    () async {
      final driver = FakeNavigationDriver()..failAdvance = true;
      final model = tripSession(driver)..attach(FakeTripMap());
      addTearDown(model.dispose);
      await model.start();
      await model.complete('a');
      await model.complete('b');
      expect(model.plan.completed, {'a', 'b'});
      expect(model.active, isFalse);
      await Future<void>.delayed(Duration.zero);
      driver.failAdvance = false;
      await model.start();
      expect(model.current.finalDestination, isTrue);
      expect(model.currentErrands, isEmpty);
    },
  );
  test(
    'arrival and partial shared completion do not advance, successful saves do',
    () async {
      final driver = FakeNavigationDriver(), map = FakeTripMap();
      final gate = Completer<void>();
      final model = tripSession(driver, save: (_) => gate.future)..attach(map);
      addTearDown(model.dispose);
      await model.start();
      expect(driver.points.length, 2);
      expect(map.follows, 1);
      driver.signals.add(
        const NavigationSignal(
          NavigationSignalKind.arrival,
          target: NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        ),
      );
      expect(model.arrived, isTrue);
      expect(model.plan.completed, isEmpty);
      await model.complete('b');
      expect(model.plan.completed, isEmpty);
      expect(model.currentErrandId, 'a');
      final saving = model.complete('a');
      await model.complete('a');
      expect(driver.advances, 0);
      expect(model.plan.completed, isEmpty);
      gate.complete();
      await saving;
      expect(model.currentErrandId, 'b');
      expect(model.plan.completed, {'a'});
      await model.complete('b');
      expect(driver.advances, 1);
      expect(driver.requests, 1);
      expect(model.current.finalDestination, isTrue);
    },
  );
  test('save failure cannot complete or advance a task', () async {
    final driver = FakeNavigationDriver();
    final model = tripSession(
      driver,
      save: (_) async => throw StateError('storage'),
    )..attach(FakeTripMap());
    addTearDown(model.dispose);
    await model.start();
    await model.complete('a');
    expect(model.plan.completed, isEmpty);
    expect(driver.advances, 0);
    expect(model.stage, TripStage.failed);
  });
  test(
    'restart reconstructs remaining progress without completed checkboxes',
    () async {
      final driver = FakeNavigationDriver();
      final model = tripSession(driver, plan: tripFixture().complete('a'))
        ..attach(FakeTripMap());
      addTearDown(model.dispose);
      await model.start();
      expect(model.currentErrands, ['b']);
      await model.complete('b');
      expect(model.currentErrands, isEmpty);
      expect(driver.requests, 1);
    },
  );
  test(
    'overview and GPS events preserve navigation and cause no route request',
    () async {
      final driver = FakeNavigationDriver(), map = FakeTripMap();
      final model = tripSession(driver)..attach(map);
      addTearDown(model.dispose);
      await model.start();
      await model.showWholeTrip();
      expect(map.overviewPoints.length, 2);
      expect(model.overview, isTrue);
      driver.signals.add(const NavigationSignal(NavigationSignalKind.gpsLost));
      expect(model.gpsLost, isTrue);
      driver.signals.add(
        const NavigationSignal(NavigationSignalKind.gpsAvailable),
      );
      expect(model.gpsLost, isFalse);
      expect(map.follows, 1);
      expect(driver.requests, 1);
      model.cameraFollowing(true);
      expect(model.overview, isFalse);
    },
  );
  test('map and SDK location waits time out without dispatch', () async {
    final driver = FakeNavigationDriver();
    final model = tripSession(driver, timeout: const Duration(milliseconds: 5));
    addTearDown(model.dispose);
    await model.start();
    expect(model.error, contains('map did not become ready'));
    expect(driver.requests, 0);
    final otherDriver = FakeNavigationDriver(),
        map = FakeTripMap()..fix = Completer();
    final other = tripSession(
      otherDriver,
      timeout: const Duration(milliseconds: 5),
    )..attach(map);
    addTearDown(other.dispose);
    await other.start();
    expect(other.error, contains('location is unavailable'));
    expect(otherDriver.requests, 0);
    map.fix!.complete(null);
  });
  test(
    'backgrounding and late route completion cannot activate a session',
    () async {
      final driver = FakeNavigationDriver()..pending = Completer();
      final model = tripSession(driver)..attach(FakeTripMap());
      addTearDown(model.dispose);
      final start = model.start();
      while (driver.requests == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      await model.pause();
      driver.pending!.complete(nav.NavigationRouteStatus.statusOk);
      await start;
      expect(model.active, isFalse);
      expect(driver.starts, 0);
    },
  );
}
