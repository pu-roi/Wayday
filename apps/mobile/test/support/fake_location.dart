import 'package:wayday/features/maps/data/location_reader.dart';

class FakeLocationPlatform extends LocationPlatform {
  FakeLocationPlatform({this.access = LocationAccess.allowed, this.reader});
  LocationAccess access;
  LocationAccess grant = LocationAccess.allowed;
  LocationReader? reader;
  bool enabled = true;
  int prompts = 0, acquisitions = 0, checks = 0;
  bool? settingsServices;
  @override
  Future<bool> servicesEnabled() async => enabled;
  @override
  Future<LocationAccess> checkPermission() async {
    checks++;
    return access;
  }

  @override
  Future<LocationAccess> requestPermission() async {
    prompts++;
    return access = grant;
  }

  @override
  Future<LocationFix> acquire() async {
    acquisitions++;
    return reader == null
        ? const LocationFix(14.58, 121.05, 30)
        : await reader!();
  }

  @override
  Future<void> openSettings({required bool services}) async {
    settingsServices = services;
  }
}
