import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:google_navigation_flutter/src/google_navigation_flutter_platform_interface.dart';
import 'package:google_navigation_flutter/src/method_channel/method_channel.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/plan_map.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

class MapAPI extends MapViewAPIImpl {
  List<nav.MarkerOptions> markers = [];
  List<nav.PolylineOptions> lines = [];
  int lineClears = 0;
  @override
  Future<void> setTrafficEnabled({
    required int viewId,
    required bool enabled,
  }) async {}
  @override
  Future<void> clearMarkers({required int viewId}) async {
    markers = [];
  }

  @override
  Future<void> clearPolylines({required int viewId}) async {
    lineClears++;
    lines = [];
  }

  @override
  Future<List<nav.Marker>> addMarkers({
    required int viewId,
    required List<nav.MarkerOptions> markerOptions,
  }) async {
    markers = markerOptions;
    return [
      for (var i = 0; i < markers.length; i++)
        nav.Marker(markerId: 'm$i', options: markers[i]),
    ];
  }

  @override
  Future<List<nav.Polyline?>> addPolylines({
    required int viewId,
    required List<nav.PolylineOptions> polylineOptions,
  }) async {
    lines = polylineOptions;
    return [];
  }

  @override
  Future<void> moveCamera({
    required int viewId,
    required nav.CameraUpdate cameraUpdate,
  }) async {}
}

class Images extends ImageRegistryAPIImpl {
  @override
  Future<nav.ImageDescriptor> registerBitmapImage({
    required Uint8List bitmap,
    required double imagePixelRatio,
    double? width,
    double? height,
  }) async => const nav.ImageDescriptor(registeredImageId: 'test-marker');
  @override
  Future<void> unregisterImage({
    required nav.ImageDescriptor imageDescriptor,
  }) async {}
}

class Platform extends GoogleMapsNavigationPlatform {
  Platform(MapAPI map)
    : super(NavigationSessionAPIImpl(), map, Images(), AutoMapViewAPIImpl());
  @override
  Widget buildMapView({
    required nav.MapViewInitializationOptions initializationOptions,
    required PlatformViewCreatedCallback onPlatformViewCreated,
    required MapReadyCallback onMapReady,
  }) => const SizedBox();
  @override
  Widget buildNavigationView({
    required nav.MapViewInitializationOptions initializationOptions,
    required PlatformViewCreatedCallback onPlatformViewCreated,
    required MapReadyCallback onMapReady,
  }) => const SizedBox();
}

void main() {
  testWidgets(
    'one native map clears obsolete geometry and draws the replacement route',
    (tester) async {
      final api = MapAPI();
      GoogleMapsNavigationPlatform.instance = Platform(api);
      Widget map(double end, List<List<List<double>>> geometry) => MaterialApp(
        theme: buildTheme(),
        home: PlanMap(
          key: const ValueKey('stable-map'),
          places: [
            const PlaceIntent(
              kind: PlaceKind.specific,
              label: 'Start',
              latitude: 14.5,
              longitude: 121,
            ),
            PlaceIntent(
              kind: PlaceKind.specific,
              label: 'Stop',
              latitude: end,
              longitude: 121.1,
            ),
          ],
          geometry: geometry,
          onSelect: (_) {},
        ),
      );
      await tester.pumpWidget(
        map(14.6, [
          [
            [14.5, 121],
            [14.6, 121.1],
          ],
        ]),
      );
      final dynamic state = tester.state(find.byType(PlanMap));
      await tester.runAsync(
        () => state.created(nav.GoogleMapViewController(1)) as Future<void>,
      );
      expect(api.lines.single.points!.last.latitude, 14.6);
      await tester.pumpWidget(map(14.7, []));
      await tester.runAsync(() => state.synchronize() as Future<void>);
      expect(tester.state(find.byType(PlanMap)), same(state));
      expect(api.lines, isEmpty);
      expect(api.markers.last.position.latitude, 14.7);
      await tester.pumpWidget(
        map(14.7, [
          [
            [14.5, 121],
            [14.7, 121.1],
          ],
        ]),
      );
      await tester.runAsync(() => state.synchronize() as Future<void>);
      expect(api.lines.single.points!.last.latitude, 14.7);
      expect(api.lineClears, 3);
      expect(tester.takeException(), isNull);
    },
  );
}
