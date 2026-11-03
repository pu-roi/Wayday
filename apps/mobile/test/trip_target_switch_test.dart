import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/data/navigation_target_resolver.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/planning/presentation/trip_session.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'trip_navigation_test.dart' show FakeNavigationDriver;
import 'trip_provider_switch_test.dart' show PreparedDriver;
import 'trip_session_test.dart' show tripFixture, FakeTripMap;

void main() {
  test(
    'a completed task racing preparation keeps latest progress and the old navigator',
    () async {
      final repository = MemoryItineraryRepository();
      await repository.save(tripFixture());
      final google = FakeNavigationDriver(),
          alternative = PreparedDriver()..preparation = Completer();
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
            const NavigationCoordinate(latitude: 14.5, longitude: 121),
        save: repository.updateProgress,
        persistProvider: repository.updateNavigationProvider,
        createNavigation: (provider) => service(alternative, provider),
      );
      addTearDown(model.dispose);
      model.attach(FakeTripMap());
      await model.start();
      final work = model.switchProvider(TripMapProvider.openStreetMap);
      await Future<void>.delayed(Duration.zero);
      await repository.updateProgress(repository.value!.complete('a'));
      alternative.preparation!.complete();
      await work;
      expect(model.provider, TripMapProvider.google);
      expect(google.stops, 0);
      expect(alternative.starts, 0);
      expect(model.plan.completed, {'a'});
      expect(repository.value!.completed, {'a'});
      expect(repository.value!.navigationProvider, TripMapProvider.google);
      expect(model.error, contains('progress changed'));
    },
  );
  test(
    'Google trip switches both ways after SDK expiry and keeps shared-stop progress',
    () async {
      var leaseClock = DateTime.now();
      final original = PlaceIntent(
        provider: 'google_places_sdk',
        providerPlaceId: 'exact-branch',
        googlePin: GooglePinLease(now: () => leaseClock)
          ..acquiredAt = leaseClock
          ..latitude = 14.1
          ..longitude = 121.2,
      );
      final base = tripFixture();
      final repository = MemoryItineraryRepository();
      await repository.save(
        AcceptedItinerary(
          day: base.day,
          stops: [
            ItineraryStop(original, ['a', 'b']),
          ],
          acceptedAt: base.acceptedAt,
        ),
      );
      String? disk;
      var lookups = 0;
      final resolver = NavigationTargetResolver(
        read: () async => disk,
        write: (v) async => disk = v,
        load: (id, revision) async {
          lookups++;
          return {
            'placeId': id,
            'revision': revision,
            'resolved': true,
            'retrievedAtMillis': DateTime.now().millisecondsSinceEpoch,
            'latitude': 14.58,
            'longitude': 121.06,
          };
        },
      );
      final google = FakeNavigationDriver(), alternative = PreparedDriver();
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
        targetResolver: resolver,
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.5, longitude: 121),
        save: repository.updateProgress,
        persistProvider: repository.updateNavigationProvider,
        createNavigation: (provider) => service(
          provider == TripMapProvider.google ? google : alternative,
          provider,
        ),
      );
      addTearDown(model.dispose);
      model.attach(FakeTripMap());
      model.addListener(() {
        if (model.mapRequested) {
          model.attach(FakeTripMap(), session: model.mapSession);
        }
      });
      await model.start();
      expect(model.alternativeIssue, isNull);
      leaseClock = leaseClock.add(const Duration(days: 31));
      expect(original.hasCoordinates, isFalse);
      await model.switchProvider(TripMapProvider.openStreetMap);
      expect(model.active, isTrue, reason: model.error);
      expect(lookups, 1);
      expect(alternative.points.first.coordinate!.latitude, 14.58);
      expect(alternative.points.first.place, same(original));
      alternative.signals.add(
        const NavigationSignal(
          NavigationSignalKind.arrival,
          target: NavigationCoordinate(latitude: 14.58, longitude: 121.06),
        ),
      );
      expect(model.arrived, isTrue);
      expect(model.plan.completed, isEmpty);
      await model.complete('a');
      expect(alternative.advances, 0);
      expect(model.currentErrandId, 'b');
      await model.switchProvider(TripMapProvider.google);
      expect(model.active, isTrue, reason: model.error);
      expect(google.points.first.coordinate!.latitude, 14.58);
      expect(model.plan.completed, {'a'});
      expect(repository.value!.completed, {'a'});
      expect(repository.value!.stops.first.place, same(original));
      expect(lookups, 1);
    },
  );

  test(
    'expired SDK coordinates do not block cached alternative restart',
    () async {
      final base = tripFixture();
      final place = const PlaceIntent(
        provider: 'google_places_sdk',
        providerPlaceId: 'exact-branch',
      );
      final plan = AcceptedItinerary(
        day: base.day,
        stops: [
          ItineraryStop(place, ['a', 'b']),
        ],
        acceptedAt: base.acceptedAt,
        navigationProvider: TripMapProvider.openStreetMap,
      );
      String? disk;
      var calls = 0;
      final resolver = NavigationTargetResolver(
        read: () async => disk,
        write: (v) async => disk = v,
        load: (id, revision) async {
          calls++;
          return {
            'placeId': id,
            'revision': revision,
            'resolved': true,
            'latitude': 14.58,
            'longitude': 121.06,
            'retrievedAtMillis': DateTime.now().millisecondsSinceEpoch,
          };
        },
      );
      await resolver.resolve(
        plan.runId,
        remainingWaypoints(plan),
        allowFetch: true,
        stillCurrent: () => true,
      );
      final model = TripSession(
        plan: plan,
        navigation: TripNavigation(
          PlanningBudget(read: () async => null, write: (_) async {}),
          driver: PreparedDriver(),
          provider: TripMapProvider.openStreetMap,
        ),
        targetResolver: NavigationTargetResolver(
          read: () async => disk,
          write: (v) async => disk = v,
          load: (_, _) async => throw StateError('no automatic lookup'),
        ),
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.5, longitude: 121),
        save: (_) async {},
      );
      addTearDown(model.dispose);
      model.addListener(() {
        if (model.stage == TripStage.map && model.mapRequested) {
          expect(
            model.remaining.first.coordinate!.latitude,
            14.58,
            reason:
                'Style-ready callbacks need resolved markers before guide() starts.',
          );
        }
      });
      model.attach(FakeTripMap());
      await model.start();
      expect(model.active, isTrue, reason: model.error);
      expect(calls, 1);
      expect(model.current.coordinate!.latitude, 14.58);
    },
  );
}
