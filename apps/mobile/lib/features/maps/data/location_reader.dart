import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix(this.latitude, this.longitude, this.accuracy);
  final double latitude;
  final double longitude;
  final double accuracy;
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;
}

typedef LocationReader = Future<LocationFix> Function();

final locationReaderProvider = Provider<LocationReader>(
  (ref) => () async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationUnavailable(
        'Location is off. Turn it on or choose a pin manually.',
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationUnavailable(
        'Location permission is unavailable. Move the map to choose your pin.',
      );
    }
    final fix = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return LocationFix(fix.latitude, fix.longitude, fix.accuracy);
  },
);
