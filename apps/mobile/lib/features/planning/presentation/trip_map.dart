import 'package:google_navigation_flutter/google_navigation_flutter.dart'
    as nav;
import '../../today/domain/day.dart';
import '../data/trip_navigation.dart';
import '../domain/planning_models.dart';
import 'trip_session.dart';

class GoogleTripMapPort implements TripMapPort {
  GoogleTripMapPort(this.controller);
  final nav.GoogleNavigationViewController controller;
  @override
  Future<nav.LatLng?> location() => controller.getMyLocation();
  @override
  Future<void> enable() async {
    await controller.setMyLocationEnabled(true);
    await controller.setNavigationUIEnabled(true);
    await controller.setForceNightMode(nav.NavigationForceNightMode.auto);
  }

  @override
  Future<void> follow(TravelProfile profile) => controller.followMyLocation(
    profile == TravelProfile.walk
        ? nav.CameraPerspective.topDownNorthUp
        : nav.CameraPerspective.tilted,
  );
  @override
  Future<void> overview(
    List<nav.RouteSegment> segments,
    List<TripWaypoint> points,
  ) async {
    final coordinates = [
      for (final segment in segments)
        ...?segment.latLngs?.whereType<nav.LatLng>(),
    ];
    if (segments.length < points.length || coordinates.isEmpty) {
      throw const PlanningFailure('Remaining road geometry is unavailable.');
    }
    coordinates.addAll(
      points.map(
        (p) => nav.LatLng(
          latitude: p.place.latitude!,
          longitude: p.place.longitude!,
        ),
      ),
    );
    final latitudes = coordinates.map((p) => p.latitude),
        longitudes = coordinates.map((p) => p.longitude);
    double minimum(Iterable<double> values) =>
        values.reduce((a, b) => a < b ? a : b);
    double maximum(Iterable<double> values) =>
        values.reduce((a, b) => a > b ? a : b);
    await controller.moveCamera(
      nav.CameraUpdate.newLatLngBounds(
        nav.LatLngBounds(
          southwest: nav.LatLng(
            latitude: minimum(latitudes) - .0001,
            longitude: minimum(longitudes) - .0001,
          ),
          northeast: nav.LatLng(
            latitude: maximum(latitudes) + .0001,
            longitude: maximum(longitudes) + .0001,
          ),
        ),
        padding: 80,
      ),
    );
  }
}
