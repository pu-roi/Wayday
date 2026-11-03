import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/alternative_navigation_driver.dart';
import 'package:wayday/features/planning/data/alternative_route_client.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/navigation_target_resolver.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/planning/presentation/alternative_trip_map.dart';
import 'package:wayday/features/planning/presentation/trip_session.dart';
import 'package:wayday/features/planning/presentation/trip_view.dart';
import 'package:wayday/features/today/domain/day.dart';
import '../test/trip_session_test.dart' show tripFixture;

class FixtureRoutes extends AlternativeRouteClient {
  @override
  Future<List<NavigationLeg>> route(
    List<NavigationCoordinate> points,
    TravelProfile profile,
  ) async => [
    for (var i = 1; i < points.length; i++)
      NavigationLeg(
        [points[i - 1], points[i]],
        distance: 100,
        duration: 60,
        steps: [
          const NavigationManeuver(0, 1, 100, 60, 'Synthetic direction.'),
          const NavigationManeuver(1, 1, 0, 0, 'Synthetic arrival.'),
        ],
      ),
  ];
}

/// Rendering fixture only; the separate native-core fixture proves core progress.
/// This viewport uses synthetic geometry/GPS and a local empty style, no network.
class FixtureDriver extends AlternativeNavigationDriver {
  FixtureDriver()
    : super(
        client: FixtureRoutes(),
        tripId: 'map-fixture',
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
      );
  final updates = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get changes => updates.stream;
  @override
  Future<void> initialize(NavigationAppearance? colors) async {}
  @override
  Future<void> start() async {
    updates.add(null);
  }

  @override
  Future<void> stop() async {}
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final googleTargets in [false, true]) {
    testWidgets(
      'alternative native viewport retains controls and follows movement; Google targets=$googleTargets',
      (tester) async {
        final identity = await const MethodChannel(
          'wayday/planning',
        ).invokeMapMethod<String, String>('identity');
        expect(identity!['package'], endsWith('.maptest'));
        final driver = FixtureDriver();
        final base = tripFixture();
        final plan = googleTargets
            ? AcceptedItinerary(
                day: base.day,
                stops: [
                  const ItineraryStop(
                    PlaceIntent(
                      provider: 'google_places_sdk',
                      providerPlaceId: 'fixture-branch',
                    ),
                    ['a', 'b'],
                  ),
                ],
                acceptedAt: base.acceptedAt,
              )
            : base;
        String? cache;
        final resolver = NavigationTargetResolver(
          read: () async => cache,
          write: (v) async => cache = v,
          load: (id, revision) async => {
            'placeId': id,
            'revision': revision,
            'resolved': true,
            'latitude': 14.581,
            'longitude': 121.061,
            'retrievedAtMillis': DateTime.now().millisecondsSinceEpoch,
          },
        );
        if (googleTargets) {
          await resolver.resolve(
            plan.runId,
            remainingWaypoints(plan),
            allowFetch: true,
            stillCurrent: () => true,
          );
        }
        final model = TripSession(
          plan: plan.withNavigationProvider(TripMapProvider.openStreetMap),
          targetResolver: googleTargets ? resolver : null,
          navigation: TripNavigation(
            PlanningBudget(read: () async => null, write: (_) async {}),
            driver: driver,
            provider: TripMapProvider.openStreetMap,
          ),
          acquireLocation: () async =>
              const NavigationCoordinate(latitude: 14.58, longitude: 121.06),
          save: (_) async {},
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: buildTheme(),
              home: TripView(
                initial: model.plan,
                session: model,
                mapBuilder: (_, ready, position) => AlternativeTripMap(
                  model: model,
                  driver: driver,
                  session: model.mapSession,
                  style:
                      '{"version":8,"sources":{},"layers":[{"id":"background","type":"background","paint":{"background-color":"#edf3f7"}}]}',
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 100 && !model.active; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(model.active, isTrue, reason: model.error);
        if (googleTargets) {
          expect(model.current.place.hasCoordinates, isFalse);
          expect(model.current.coordinate!.latitude, 14.581);
        }
        expect(find.text('Your trip'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.byTooltip('Recenter'), findsOneWidget);
        expect(find.text('Geoapify'), findsOneWidget);
        driver.position = const NavigationCoordinate(
          latitude: 14.5805,
          longitude: 121.0605,
        );
        driver.updates.add(null);
        await tester.pump(const Duration(seconds: 1));
        model.cameraGesture();
        expect(model.following, isFalse);
        await tester.tap(find.byTooltip('Recenter'));
        await tester.pump(const Duration(seconds: 1));
        expect(model.following, isTrue);
        await tester.tap(find.text('Whole trip'));
        await tester.pump(const Duration(seconds: 1));
        expect(model.overview, isTrue);
        await tester.tap(find.text('Done'));
        await tester.pump(const Duration(seconds: 1));
        expect(model.plan.completed, contains('a'));
        expect(model.currentErrandId, 'b');
        await binding.convertFlutterSurfaceToImage();
        await tester.pump(const Duration(seconds: 1));
        await File(
          '${Directory.systemTemp.path}/alternative-trip-native-fixture.png',
        ).writeAsBytes(
          await binding.takeScreenshot('alternative-trip-native-fixture'),
        );
        await tester.pumpWidget(const SizedBox());
        await driver.updates.close();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
