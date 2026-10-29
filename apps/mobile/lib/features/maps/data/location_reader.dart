import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix(
    this.latitude,
    this.longitude,
    this.accuracy, {
    this.acquiredAt,
    this.approximate = false,
  });
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime? acquiredAt;
  final bool approximate;
}

class LocationUnavailable implements Exception {
  const LocationUnavailable(this.message);
  final String message;
}

typedef LocationReader = Future<LocationFix> Function();

final locationReaderProvider = Provider<LocationReader>(
  (ref) => () async {
    final fix = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    final accuracy = await Geolocator.getLocationAccuracy();
    return LocationFix(
      fix.latitude,
      fix.longitude,
      fix.accuracy,
      acquiredAt: fix.timestamp,
      approximate: accuracy == LocationAccuracyStatus.reduced,
    );
  },
);

enum LocationAccess { allowed, denied, permanentlyDenied }

enum LocationPhase {
  idle,
  loading,
  available,
  denied,
  permanentlyDenied,
  servicesOff,
  timeout,
}

/// Platform details and permission prompts stay outside search widgets.
abstract class LocationPlatform {
  Future<bool> servicesEnabled();
  Future<LocationAccess> checkPermission();
  Future<LocationAccess> requestPermission();
  Future<LocationFix> acquire();
  Future<void> openSettings({required bool services});
}

class GeolocatorPlatform extends LocationPlatform {
  GeolocatorPlatform(this.reader);
  final LocationReader reader;
  LocationAccess _access(LocationPermission value) => switch (value) {
    LocationPermission.always ||
    LocationPermission.whileInUse => LocationAccess.allowed,
    LocationPermission.deniedForever => LocationAccess.permanentlyDenied,
    _ => LocationAccess.denied,
  };
  @override
  Future<bool> servicesEnabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationAccess> checkPermission() async =>
      _access(await Geolocator.checkPermission());
  @override
  Future<LocationAccess> requestPermission() async =>
      _access(await Geolocator.requestPermission());
  @override
  Future<LocationFix> acquire() => reader();
  @override
  Future<void> openSettings({required bool services}) async {
    if (services) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

final locationPlatformProvider = Provider<LocationPlatform>(
  (ref) => GeolocatorPlatform(ref.read(locationReaderProvider)),
);
final searchLocationProvider = Provider<SearchLocationController>((ref) {
  final controller = SearchLocationController(
    ref.read(locationPlatformProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

class SearchLocationController extends ChangeNotifier
    with WidgetsBindingObserver {
  SearchLocationController(this.platform, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    WidgetsBinding.instance.addObserver(this);
  }
  final LocationPlatform platform;
  final DateTime Function() now;
  LocationPhase phase = LocationPhase.idle;
  LocationFix? _fix;
  LocationAccess _access = LocationAccess.denied;
  Future<LocationFix?>? _flight;
  int _epoch = 0;
  bool _disposed = false,
      _background = false,
      _checked = false,
      _requestOnFlight = false;
  LocationFix? get usableFix {
    final fix = _fix;
    if (!_checked ||
        _access != LocationAccess.allowed ||
        fix?.acquiredAt == null) {
      return null;
    }
    final age = now().difference(fix!.acquiredAt!);
    return age >= Duration.zero && age <= const Duration(minutes: 5)
        ? fix
        : null;
  }

  String? get message => switch (phase) {
    LocationPhase.denied =>
      'Location permission is unavailable. Choose an area on the map instead.',
    LocationPhase.permanentlyDenied =>
      'Location access is disabled. Open settings or choose an area on the map.',
    LocationPhase.servicesOff =>
      'Location is off. Turn it on or choose an area on the map.',
    LocationPhase.timeout =>
      'No location fix yet. Try again or choose an area on the map.',
    _ => null,
  };
  bool get canOpenSettings =>
      phase == LocationPhase.permanentlyDenied ||
      phase == LocationPhase.servicesOff;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<LocationFix?> refresh({bool requestPermission = false}) {
    if (_disposed || _background) return Future.value(null);
    if (_flight != null) {
      _requestOnFlight = _requestOnFlight || requestPermission;
      return _flight!;
    }
    _requestOnFlight = requestPermission;
    final epoch = _epoch;
    final flight = _read(epoch);
    _flight = flight;
    flight.whenComplete(() {
      if (identical(_flight, flight)) _flight = null;
    });
    return flight;
  }

  bool _current(int epoch) => !_disposed && !_background && epoch == _epoch;
  Future<LocationFix?> _read(int epoch) async {
    _checked = false;
    phase = LocationPhase.loading;
    _notify();
    try {
      final enabled = await platform.servicesEnabled();
      if (!_current(epoch)) return null;
      if (!enabled) {
        _fix = null;
        phase = LocationPhase.servicesOff;
        return null;
      }
      var access = await platform.checkPermission();
      if (!_current(epoch)) return null;
      if (access == LocationAccess.denied && _requestOnFlight) {
        access = await platform.requestPermission();
      }
      if (!_current(epoch)) return null;
      _access = access;
      _checked = true;
      if (access != LocationAccess.allowed) {
        _fix = null;
        phase = access == LocationAccess.permanentlyDenied
            ? LocationPhase.permanentlyDenied
            : LocationPhase.denied;
        return null;
      }
      if (usableFix != null) _notify();
      final value = await platform.acquire().timeout(
        const Duration(seconds: 15),
      );
      if (!_current(epoch)) return null;
      if (!value.latitude.isFinite ||
          !value.longitude.isFinite ||
          value.latitude.abs() > 90 ||
          value.longitude.abs() > 180 ||
          !value.accuracy.isFinite ||
          value.accuracy < 0) {
        throw const LocationUnavailable('Invalid location');
      }
      final timestamp = value.acquiredAt ?? now();
      final age = now().difference(timestamp);
      if (age.isNegative || age > const Duration(minutes: 5)) {
        throw const LocationUnavailable('Stale location');
      }
      _fix = LocationFix(
        value.latitude,
        value.longitude,
        value.accuracy,
        acquiredAt: timestamp,
        approximate: value.approximate,
      );
      phase = LocationPhase.available;
      return _fix;
    } catch (_) {
      if (_current(epoch)) phase = LocationPhase.timeout;
      return null;
    } finally {
      if (_current(epoch)) _notify();
    }
  }

  Future<void> recheckPermission() async {
    final epoch = _epoch;
    try {
      final access = await platform.checkPermission();
      final enabled = await platform.servicesEnabled();
      if (!_current(epoch)) return;
      _access = access;
      _checked = true;
      if (!enabled || access != LocationAccess.allowed) {
        _fix = null;
        phase = !enabled
            ? LocationPhase.servicesOff
            : access == LocationAccess.permanentlyDenied
            ? LocationPhase.permanentlyDenied
            : LocationPhase.denied;
      }
      _notify();
    } catch (_) {
      /* No permission prompt during a quiet check. */
    }
  }

  Future<void> openSettings() =>
      platform.openSettings(services: phase == LocationPhase.servicesOff);
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _background = true;
      _checked = false;
      _epoch++;
      _flight = null;
      if (phase == LocationPhase.loading) phase = LocationPhase.idle;
    } else if (state == AppLifecycleState.resumed) {
      _background = false;
      recheckPermission();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
