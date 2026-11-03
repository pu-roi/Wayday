import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/alternative_navigation_driver.dart';
import 'package:wayday/features/planning/data/alternative_route_client.dart';
import 'package:wayday/features/planning/data/trip_navigation.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';
import 'alternative_route_test.dart' as fixture;

class Routes extends AlternativeRouteClient {
  int calls = 0;
  Completer<List<NavigationLeg>>? pending;
  bool fail = false;
  @override
  Future<List<NavigationLeg>> route(
    List<NavigationCoordinate> points,
    TravelProfile profile,
  ) async {
    calls++;
    if (fail) throw StateError('provider down');
    return pending == null
        ? AlternativeRouteClient.decode(routeFixture(), 1)
        : pending!.future;
  }

  Map<String, dynamic> routeFixture() => fixture.route();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fixture/alternative');
  final nativeCalls = <MethodCall>[];
  late String session;
  setUp(() {
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'initialize') {
            session = (call.arguments as Map)['session'] as String;
          }
          return call.method == 'voice' ? false : null;
        });
  });
  Future<void> event(String kind, {String? id}) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('event', {
              'session': id ?? session,
              'kind': kind,
              'latitude': 14.5,
              'longitude': 121.0,
            }),
          ),
          (_) {},
        );
    await Future<void>.delayed(Duration.zero);
  }

  AlternativeNavigationDriver driver(Routes routes, DateTime Function() now) =>
      AlternativeNavigationDriver(
        client: routes,
        acquireLocation: () async =>
            const NavigationCoordinate(latitude: 14.5, longitude: 121),
        tripId: 'trip',
        channel: channel,
        now: now,
      );
  test(
    'GPS movement does not route, off-route coalesces and dispatches at most once per fifteen seconds',
    () async {
      var clock = DateTime(2026, 11, 2);
      final routes = Routes(), service = driver(Routes(), () => clock);
      // Use one exact route-client instance so dispatched calls are observable.
      final actual = driver(routes, () => clock);
      await actual.initialize(null);
      await actual.destinations([
        TripWaypoint(pin, ['a']),
      ], TravelProfile.walk);
      await actual.start();
      for (var i = 0; i < 10; i++) {
        await event('location');
      }
      expect(routes.calls, 1);
      routes.pending = Completer();
      await event('offRoute');
      await event('offRoute');
      expect(routes.calls, 2);
      routes.pending!.complete(
        AlternativeRouteClient.decode(fixture.route(), 1),
      );
      await Future<void>.delayed(Duration.zero);
      await event('offRoute');
      expect(routes.calls, 2);
      routes.pending = null;
      clock = clock.add(const Duration(seconds: 15));
      await event('offRoute');
      expect(routes.calls, 3);
      final oldSession = session;
      await actual.stop();
      await service.initialize(null);
      expect(session, isNot(oldSession));
      var events = 0;
      final sub = service.events.listen((_) => events++);
      await event('failure', id: oldSession);
      expect(events, 0);
      await sub.cancel();
      await service.stop();
    },
  );
  test('failed rerouting remains explicit and never auto-retries', () async {
    final routes = Routes();
    final actual = driver(routes, DateTime.now);
    await actual.initialize(null);
    await actual.destinations([
      TripWaypoint(pin, ['a']),
    ], TravelProfile.walk);
    await actual.start();
    routes.fail = true;
    final failures = <NavigationSignal>[];
    final sub = actual.events.listen(failures.add);
    await event('offRoute');
    await event('offRoute');
    expect(routes.calls, 2);
    expect(
      failures.where((e) => e.kind == NavigationSignalKind.failure).length,
      1,
    );
    await actual.stop();
    await sub.cancel();
  });
}
