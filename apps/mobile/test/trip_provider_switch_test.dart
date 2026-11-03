import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/planning/presentation/trip_session.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'trip_navigation_test.dart';
import 'trip_session_test.dart';

class PreparedDriver extends FakeNavigationDriver
    implements PreparedNavigationDriver {
  Completer<void>? preparation;
  int preparations = 0;
  @override
  Future<void> prepare(
    List<TripWaypoint> points,
    TravelProfile profile,
    NavigationCoordinate origin,
  ) async {
    preparations++;
    await preparation?.future;
  }
}

class FailingStopDriver extends FakeNavigationDriver {
  bool failStop = false;
  @override
  Future<void> stop() async {
    if (failStop) throw StateError('cleanup failed');
    await super.stop();
  }
}

void main() {
  test(
    'a failed old-navigator stop restores provider metadata without losing tasks',
    () async {
      final repository = MemoryItineraryRepository();
      await repository.save(tripFixture().complete('a'));
      final google = FailingStopDriver(), alternative = PreparedDriver();
      TripNavigation service(
        FakeNavigationDriver driver,
        TripMapProvider provider,
      ) => TripNavigation(
        PlanningBudget(read: () async => null, write: (_) async {}),
        driver: driver,
        provider: provider,
      );
      final model = TripSession(
        plan: repository.value!,
        navigation: service(google, TripMapProvider.google),
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        save: repository.updateProgress,
        persistProvider: repository.updateNavigationProvider,
        createNavigation: (p) => service(alternative, p),
      );
      model.attach(FakeTripMap());
      await model.start();
      google.failStop = true;
      await model.switchProvider(TripMapProvider.openStreetMap);
      expect(model.provider, TripMapProvider.google);
      expect(repository.value!.navigationProvider, TripMapProvider.google);
      expect(repository.value!.completed, {'a'});
      expect(alternative.starts, 0);
      google.failStop = false;
      model.dispose();
    },
  );
  TripNavigation navigation(
    FakeNavigationDriver driver,
    TripMapProvider provider,
  ) => TripNavigation(
    PlanningBudget(read: () async => null, write: (_) async {}),
    driver: driver,
    provider: provider,
  );
  test(
    'prepares before persist/stop, coalesces taps, and switches both ways without losing progress',
    () async {
      final repository = MemoryItineraryRepository();
      await repository.save(tripFixture().complete('a'));
      final google = FakeNavigationDriver(),
          alternative = PreparedDriver()..preparation = Completer();
      final model = TripSession(
        plan: (await repository.read())!,
        navigation: navigation(google, TripMapProvider.google),
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        save: repository.updateProgress,
        persistProvider: repository.updateNavigationProvider,
        createNavigation: (p) =>
            navigation(p == TripMapProvider.google ? google : alternative, p),
      );
      addTearDown(model.dispose);
      model.attach(FakeTripMap());
      model.addListener(() {
        if (model.mapRequested) {
          model.attach(FakeTripMap(), session: model.mapSession);
        }
      });
      await model.start();
      final work = model.switchProvider(TripMapProvider.openStreetMap);
      final repeat = model.switchProvider(TripMapProvider.openStreetMap);
      expect(identical(work, repeat), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(google.stops, 0);
      expect(
        (await repository.read())!.navigationProvider,
        TripMapProvider.google,
      );
      alternative.preparation!.complete();
      await work;
      expect(model.active, isTrue);
      expect(model.provider, TripMapProvider.openStreetMap);
      expect(model.plan.completed, {'a'});
      expect(google.stops, 1);
      expect(alternative.preparations, 1);
      await model.complete('b');
      await model.switchProvider(TripMapProvider.google);
      expect(model.active, isTrue);
      expect(model.plan.completed, {'a', 'b'});
      expect(
        (await repository.read())!.navigationProvider,
        TripMapProvider.google,
      );
    },
  );
  test(
    'failed storage leaves the current navigator and progress intact',
    () async {
      final google = FakeNavigationDriver(), alternative = PreparedDriver();
      final model = TripSession(
        plan: tripFixture(),
        navigation: navigation(google, TripMapProvider.google),
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        save: (_) async {},
        persistProvider: (_, _) async => throw StateError('disk full'),
        createNavigation: (p) => navigation(alternative, p),
      );
      addTearDown(model.dispose);
      model.attach(FakeTripMap());
      await model.start();
      await model.switchProvider(TripMapProvider.openStreetMap);
      expect(model.provider, TripMapProvider.google);
      expect(model.active, isTrue);
      expect(google.stops, 0);
      expect(model.error, contains('could not be changed'));
    },
  );
  test(
    'pause invalidates delayed preparation without persisting or attaching it',
    () async {
      final repository = MemoryItineraryRepository();
      await repository.save(tripFixture());
      final alternative = PreparedDriver()..preparation = Completer();
      final model = TripSession(
        plan: repository.value!,
        navigation: navigation(FakeNavigationDriver(), TripMapProvider.google),
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        save: repository.updateProgress,
        persistProvider: repository.updateNavigationProvider,
        createNavigation: (p) => navigation(alternative, p),
      );
      addTearDown(model.dispose);
      model.attach(FakeTripMap());
      await model.start();
      final work = model.switchProvider(TripMapProvider.openStreetMap);
      await Future<void>.delayed(Duration.zero);
      await model.pause();
      alternative.preparation!.complete();
      await work;
      expect(model.provider, TripMapProvider.google);
      expect(repository.value!.navigationProvider, TripMapProvider.google);
      expect(alternative.starts, 0);
    },
  );
}
