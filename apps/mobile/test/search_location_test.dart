import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'support/fake_location.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'quiet first use never prompts; explicit consent then automatic refresh',
    () async {
      final platform = FakeLocationPlatform(access: LocationAccess.denied);
      final c = SearchLocationController(platform);
      addTearDown(c.dispose);
      expect(await c.refresh(), isNull);
      expect(c.phase, LocationPhase.denied);
      expect(platform.prompts, 0);
      expect(await c.refresh(requestPermission: true), isNotNull);
      expect(c.usableFix, isNotNull);
      await c.refresh();
      expect(platform.prompts, 1);
      expect(platform.acquisitions, 2);
    },
  );
  test(
    'shared in-flight acquisition, five-minute fallback and expired fix',
    () async {
      var now = DateTime.utc(2026, 10, 28);
      final platform = FakeLocationPlatform();
      final c = SearchLocationController(platform, now: () => now);
      addTearDown(c.dispose);
      final pending = Completer<LocationFix>();
      platform.reader = () => pending.future;
      final a = c.refresh(), b = c.refresh();
      expect(identical(a, b), isTrue);
      pending.complete(
        const LocationFix(14.58, 121.05, 3000, approximate: true),
      );
      await a;
      expect(platform.acquisitions, 1);
      expect(c.usableFix!.approximate, isTrue);
      now = now.add(const Duration(minutes: 4));
      expect(c.usableFix, isNotNull);
      now = now.add(const Duration(minutes: 2));
      expect(c.usableFix, isNull);
    },
  );
  test(
    'revoked/one-time access clears location; settings stay explicit',
    () async {
      final platform = FakeLocationPlatform();
      final c = SearchLocationController(platform);
      addTearDown(c.dispose);
      await c.refresh();
      platform.access = LocationAccess.permanentlyDenied;
      await c.recheckPermission();
      expect(c.usableFix, isNull);
      expect(c.canOpenSettings, isTrue);
      expect(platform.settingsServices, isNull);
      await c.openSettings();
      expect(platform.settingsServices, false);
      expect(await c.refresh(requestPermission: true), isNull);
      expect(platform.prompts, 0);
      platform.enabled = false;
      await c.refresh();
      expect(c.phase, LocationPhase.servicesOff);
      await c.openSettings();
      expect(platform.settingsServices, true);
    },
  );
  testWidgets('timeout retains recent fallback but never starts a retry loop', (
    tester,
  ) async {
    final platform = FakeLocationPlatform();
    final c = SearchLocationController(platform, now: tester.binding.clock.now);
    addTearDown(c.dispose);
    await c.refresh();
    platform.reader = () => Completer<LocationFix>().future;
    final pending = c.refresh();
    await tester.pump(const Duration(seconds: 15));
    expect(await pending, isNull);
    expect(c.phase, LocationPhase.timeout);
    expect(c.usableFix, isNotNull);
    await tester.pump(const Duration(seconds: 30));
    expect(platform.acquisitions, 2);
  });
  test(
    'background discards callbacks and quiet resume checks revocation',
    () async {
      final pending = Completer<LocationFix>();
      final platform = FakeLocationPlatform(reader: () => pending.future);
      final c = SearchLocationController(platform);
      addTearDown(c.dispose);
      final future = c.refresh();
      await Future<void>.delayed(Duration.zero);
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      pending.complete(const LocationFix(14.58, 121.05, 20));
      expect(await future, isNull);
      expect(c.usableFix, isNull);
      platform.access = LocationAccess.denied;
      c.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(c.phase, LocationPhase.denied);
      expect(platform.prompts, 0);
      expect(platform.acquisitions, 1);
    },
  );
  test('invalid and stale coordinates never become a usable fix', () async {
    final platform = FakeLocationPlatform(
      reader: () async =>
          LocationFix(14, 121, 10, acquiredAt: DateTime.utc(2020)),
    );
    final c = SearchLocationController(platform);
    addTearDown(c.dispose);
    expect(await c.refresh(), isNull);
    expect(c.usableFix, isNull);
    platform.reader = () async => const LocationFix(double.nan, 121, 10);
    expect(await c.refresh(), isNull);
  });
}
