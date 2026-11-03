import 'package:flutter_test/flutter_test.dart';
import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import 'package:wayday/features/planning/presentation/trip_map.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class CaptureCamera extends nav.GoogleNavigationViewController {
  CaptureCamera() : super(99);
  nav.CameraUpdate? update;
  nav.CameraPerspective? perspective;
  double? zoom;
  @override
  Future<void> moveCamera(nav.CameraUpdate value) async {
    update = value;
  }

  @override
  Future<void> followMyLocation(
    nav.CameraPerspective value, {
    double? zoomLevel,
  }) async {
    perspective = value;
    zoom = zoomLevel;
  }
}

void main() {
  test(
    'whole-trip camera includes every road segment, not only the next leg',
    () async {
      final controller = CaptureCamera();
      final map = GoogleTripMapPort(controller);
      final segments = [
        for (final latitude in [13.5, 15.6])
          NavigationLeg([
            NavigationCoordinate(latitude: latitude, longitude: 121.0),
          ]),
      ];
      await map.overview(segments, [
        TripWaypoint(pin, ['a']),
        TripWaypoint(pin, []),
      ]);
      expect(controller.update!.bounds!.southwest.latitude, lessThan(13.5));
      expect(controller.update!.bounds!.northeast.latitude, greaterThan(15.6));
      expect(controller.update!.type, nav.CameraUpdateType.latLngBounds);
    },
  );
  test(
    'missing road geometry cannot become a fabricated straight-line route',
    () async {
      final controller = CaptureCamera();
      await expectLater(
        GoogleTripMapPort(controller).overview([], [
          TripWaypoint(pin, ['a']),
        ]),
        throwsA(anything),
      );
      expect(controller.update, isNull);
    },
  );
  test(
    'walking uses top-down, driving tilted, both preserve SDK adaptive zoom',
    () async {
      final controller = CaptureCamera(),
          map = GoogleTripMapPort(CaptureCamera());
      await map.follow(TravelProfile.walk);
      final actual = GoogleTripMapPort(controller);
      await actual.follow(TravelProfile.walk);
      expect(controller.perspective, nav.CameraPerspective.topDownNorthUp);
      await actual.follow(TravelProfile.motor);
      expect(controller.perspective, nav.CameraPerspective.tilted);
      expect(controller.zoom, isNull);
    },
  );
}
