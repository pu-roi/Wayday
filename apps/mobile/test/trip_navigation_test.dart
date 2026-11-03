import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class FakeNavigationDriver implements NavigationDriver {
  final signals = StreamController<NavigationSignal>.broadcast(sync: true);
  int requests = 0, starts = 0, advances = 0, stops = 0;
  List<TripWaypoint> points = [];
  int initializations = 0;
  Completer<void>? advancing;
  Completer<List<NavigationLeg>>? pendingSegments;
  bool failAdvance = false;
  Completer<nav.NavigationRouteStatus>? pending;
  nav.NavigationRouteStatus status = nav.NavigationRouteStatus.statusOk;
  @override
  Stream<NavigationSignal> get events => signals.stream;
  @override
  Future<void> initialize(NavigationAppearance? colors) async {
    initializations++;
  }

  @override
  Future<void> destinations(
    List<TripWaypoint> values,
    TravelProfile profile,
  ) async {
    requests++;
    points = values;
    final value = pending == null ? status : await pending!.future;
    if (value != nav.NavigationRouteStatus.statusOk) {
      throw TripNavigation.routeFailure(value);
    }
  }

  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> advance() async {
    advances++;
    if (failAdvance) throw StateError('advance');
    await advancing?.future;
  }

  @override
  Future<List<NavigationLeg>> segments() async =>
      pendingSegments == null ? [] : await pendingSegments!.future;
  @override
  Future<void> stop() async {
    stops++;
  }
}

void main() {
  test(
    'stopping during initialization cannot open a late SDK session',
    () async {
      final driver = FakeNavigationDriver();
      final service = TripNavigation(
        PlanningBudget(read: () async => null, write: (_) async {}),
        driver: driver,
      );
      final start = service.initialize();
      await service.stop();
      await start;
      expect(service.initialized, isFalse);
      expect(driver.initializations, 0);
    },
  );
  test('late next-stop advancement cannot restart stopped guidance', () async {
    final driver = FakeNavigationDriver()..advancing = Completer();
    final service = TripNavigation(
      PlanningBudget(read: () async => null, write: (_) async {}),
      driver: driver,
    );
    await service.initialize();
    final next = service.advance();
    final stop = service.stop();
    driver.advancing!.complete();
    await Future.wait([next, stop]);
    expect(driver.starts, 0);
  });
  test(
    'accounts every submitted destination, progression does not resubmit',
    () async {
      String? saved;
      final driver = FakeNavigationDriver();
      final service = TripNavigation(
        PlanningBudget(
          read: () async => saved,
          write: (value) async => saved = value,
        ),
        driver: driver,
      );
      await service.initialize();
      await service.guide([
        TripWaypoint(pin, ['a']),
        TripWaypoint(pin, [], finalDestination: true),
      ], TravelProfile.walk);
      await service.advance();
      expect(driver.points.length, 2);
      expect(driver.requests, 1);
      expect(jsonDecode(saved!)['testing']['services']['navigation'], 50000);
    },
  );
  test(
    'overlapping route taps coalesce and a late result cannot restart guidance',
    () async {
      String? saved;
      final driver = FakeNavigationDriver()..pending = Completer();
      final service = TripNavigation(
        PlanningBudget(
          read: () async => saved,
          write: (value) async => saved = value,
        ),
        driver: driver,
      );
      await service.initialize();
      final one = service.guide([
        TripWaypoint(pin, ['a']),
      ], TravelProfile.walk);
      final two = service.guide([
        TripWaypoint(pin, ['a']),
      ], TravelProfile.walk);
      await Future<void>.delayed(Duration.zero);
      final stop = service.stop();
      driver.pending!.complete(nav.NavigationRouteStatus.statusOk);
      await Future.wait([one, two, stop]);
      expect(driver.requests, 1);
      expect(driver.starts, 0);
      expect(jsonDecode(saved!)['testing']['usedMicros'], 25000);
    },
  );
  test(
    'unsupported and oversized routes dispatch and reserve nothing',
    () async {
      String? saved;
      final driver = FakeNavigationDriver();
      final service = TripNavigation(
        PlanningBudget(
          read: () async => saved,
          write: (value) async => saved = value,
        ),
        driver: driver,
      );
      await service.initialize();
      await expectLater(
        service.guide([
          TripWaypoint(pin, ['a']),
        ], TravelProfile.bike),
        throwsA(anything),
      );
      await expectLater(
        service.guide(
          List.generate(26, (_) => TripWaypoint(pin, [])),
          TravelProfile.walk,
        ),
        throwsA(anything),
      );
      expect(saved, isNull);
      expect(driver.requests, 0);
    },
  );
  test(
    'provider failures keep conservative accounting and never start guidance',
    () async {
      String? saved;
      final driver = FakeNavigationDriver()
        ..status = nav.NavigationRouteStatus.apiKeyNotAuthorized;
      final service = TripNavigation(
        PlanningBudget(
          read: () async => saved,
          write: (value) async => saved = value,
        ),
        driver: driver,
      );
      await service.initialize();
      await expectLater(
        service.guide([
          TripWaypoint(pin, ['a']),
        ], TravelProfile.walk),
        throwsA(anything),
      );
      expect(driver.starts, 0);
      expect(jsonDecode(saved!)['testing']['usedMicros'], 25000);
    },
  );
}
