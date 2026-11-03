import 'dart:ui' show Color;
import '../../places/domain/place_intent.dart';

enum TripMapProvider { google, openStreetMap }

class NavigationCoordinate {
  const NavigationCoordinate({required this.latitude, required this.longitude});
  final double latitude, longitude;
  bool get valid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  List<double> toJson() => [latitude, longitude];
}

class NavigationLeg {
  const NavigationLeg(
    this.coordinates, {
    this.steps = const [],
    this.distance = 0,
    this.duration = 0,
  });
  final List<NavigationCoordinate> coordinates;
  final List<NavigationManeuver> steps;
  final double distance, duration;
  Map<String, Object> toJson() => {
    'coordinates': coordinates.map((p) => p.toJson()).toList(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'distance': distance,
    'duration': duration,
  };
}

class NavigationManeuver {
  const NavigationManeuver(
    this.from,
    this.to,
    this.distance,
    this.duration,
    this.instruction, {
    this.maneuver = 'None',
  });
  final int from, to;
  final double distance, duration;
  final String instruction;
  final String maneuver;
  Map<String, Object> toJson() => {
    'from': from,
    'to': to,
    'distance': distance,
    'duration': duration,
    'instruction': instruction,
    'maneuver': maneuver,
  };
}

class NavigationProgress {
  const NavigationProgress({
    required this.position,
    required this.instruction,
    required this.distance,
    required this.duration,
    this.bearing = 0,
    this.accuracy = 0,
    this.step = 0,
  });
  final NavigationCoordinate position;
  final String instruction;
  final double distance, duration, bearing, accuracy;
  final int step;
}

String? alternativeDestinationIssue(Iterable<PlaceIntent> places) {
  for (final place in places) {
    if (!place.hasCoordinates) {
      return 'A remaining destination has an expired or unavailable location. Google is retained.';
    }
    if (place.usesGoogleSdk) {
      return 'A remaining destination comes from Google Places and can only be used with Google navigation. This version keeps that exact destination and retains Google.';
    }
    // UI Kit has separate non-Google display permission. It is deliberately
    // not treated as standard SDK content. Third-party routing export remains
    // unavailable until that separate permission is qualified.
    if (place.provider == 'google_ui_kit' ||
        place.source.startsWith('google_ui_kit')) {
      return 'This Places UI Kit destination is not yet supported by alternative routing. Google is retained.';
    }
    if (place.provider?.startsWith('google') == true) {
      return 'This destination has unsupported Google provenance. Google navigation is retained.';
    }
  }
  return null;
}

class NavigationAppearance {
  const NavigationAppearance({
    required this.backgroundColor,
    required this.titleColor,
    required this.mainTextColor,
    required this.acceptButtonTextColor,
    required this.cancelButtonTextColor,
  });
  final Color backgroundColor,
      titleColor,
      mainTextColor,
      acceptButtonTextColor,
      cancelButtonTextColor;
}
