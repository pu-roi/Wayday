import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'support/fake_location.dart';

void main() {
  testWidgets(
    'confirmed current location gets a nearby address without changing the fix',
    (tester) async {
      final adapter = _Adapter()..reversePending = Completer();
      final search = CombinedPlaceSearch([
        adapter,
      ], QuotaLedger(read: () async => null, write: (_) async {}));
      final container = ProviderContainer(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          locationPlatformProvider.overrideWithValue(FakeLocationPlatform()),
          placeMapBuilderProvider.overrideWithValue(
            (_) => const SizedBox.expand(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WaydayApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Use my location'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(todayProvider).from, 'Current location');
      expect(adapter.reverseCalls, 1);
      adapter.reversePending!.complete([
        const PlaceSearchResult(
          name: 'C. Santos Street, Murphy',
          latitude: 14.0,
          longitude: 120.0,
          sourceId: 'manual',
          provider: 'geoapify',
        ),
      ]);
      await tester.pump();
      await tester.pump();
      final place = container.read(todayProvider).fromPlace;
      expect(place.label, 'C. Santos Street, Murphy');
      expect(place.latitude, 14.58);
      expect(place.longitude, 121.05);
      expect(place.source, 'device');
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      search.dispose();
    },
  );
  testWidgets(
    'confirming a pin commits its coordinates before the lookup and ignores stale results',
    (tester) async {
      final clock = tester.binding.clock.now;
      final adapter = _Adapter();
      final result = Completer<List<PlaceSearchResult>>();
      adapter.reversePending = result;
      final ledger = QuotaLedger(
        now: clock,
        read: () async => null,
        write: (_) async {},
      );
      final search = CombinedPlaceSearch([adapter], ledger, now: clock);
      final container = ProviderContainer(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          mapPlatformSupportedProvider.overrideWithValue(false),
          placeMapBuilderProvider.overrideWithValue(
            (request) => TextButton(
              onPressed: () => request.onSelect?.call(14.5, 121.5),
              child: const Text('Fixture pin'),
            ),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const WaydayApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture pin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(container.read(todayProvider).fromPlace.latitude, 14.5);
      expect(container.read(todayProvider).from, 'Dropped pin');
      expect(find.text('Finding address…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('clear-errands')));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).from, isEmpty);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).from, 'Dropped pin');
      result.complete([
        const PlaceSearchResult(
          name: 'Old road',
          latitude: 14.5,
          longitude: 121.5,
          sourceId: 'manual',
          provider: 'geoapify',
          attributions: ['Powered by Geoapify'],
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(container.read(todayProvider).from, 'Dropped pin');
      container
          .read(todayProvider.notifier)
          .setEndpoint(
            start: true,
            value: const PlaceIntent(label: 'My replacement'),
          );
      expect(container.read(todayProvider).from, 'My replacement');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('to-map')));
      await tester.tap(find.byKey(const Key('to-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fixture pin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      final to = container.read(todayProvider).toPlace;
      expect(to.label, 'Old road');
      expect(to.latitude, 14.5);
      expect(to.longitude, 121.5);
      expect(to.attributions, contains('Powered by Geoapify'));
      expect(find.text('Powered by Geoapify'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      search.dispose();
    },
  );
  test(
    'reverse geocoding uses nearby street and preserves the pin coordinates',
    () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/v1/geocode/reverse');
        expect(request.url.queryParameters['countrycodes'], 'ph');
        return http.Response(
          jsonEncode({
            'features': [
              {
                'properties': {
                  'country_code': 'ph',
                  'street': 'EDSA',
                  'housenumber': '99',
                  'city': 'Mandaluyong',
                  'distance': 12,
                  'name': 'Nearby store',
                },
                'geometry': {
                  'coordinates': [120.0, 10.0],
                },
              },
            ],
          }),
          200,
        );
      });
      final adapter = HttpSearchAdapter(client, 'geoapify', apiKey: 'fixture');
      final result = (await adapter.reverse(14.58, 121.05)).single;
      expect(result.name, 'EDSA, Mandaluyong');
      expect(result.latitude, 14.58);
      expect(result.longitude, 121.05);
      expect(result.attributions, contains('Powered by Geoapify'));
      client.close();
    },
  );

  test(
    'distant streets use area, and foreign or missing places are rejected',
    () async {
      var features = <Object>[];
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'features': features}), 200),
      );
      final adapter = HttpSearchAdapter(client, 'geoapify', apiKey: 'fixture');
      features = [
        {
          'properties': {
            'country_code': 'ph',
            'street': 'Far road',
            'city': 'Pasig',
            'distance': 500,
          },
        },
      ];
      expect((await adapter.reverse(14, 121)).single.name, 'Pasig');
      features = [
        {
          'properties': {'country_code': 'us', 'city': 'Elsewhere'},
        },
      ];
      expect(await adapter.reverse(14, 121), isEmpty);
      features = [
        {
          'properties': {'country_code': 'ph', 'name': 'Nearby shop'},
        },
      ];
      expect(await adapter.reverse(14, 121), isEmpty);
      client.close();
    },
  );

  test('reverse waits for the existing search flight and shares its quota', () {
    fakeAsync((clock) {
      DateTime now() => DateTime.utc(2026, 10, 29).add(clock.elapsed);
      String? disk;
      final ledger = QuotaLedger(
        now: now,
        read: () async => disk,
        write: (v) async => disk = v,
      );
      final adapter = _Adapter();
      final service = CombinedPlaceSearch([adapter], ledger, now: now);
      service.search(
        Object(),
        PlaceSearchRequest('Cebu'),
        (_, _, _) {},
        immediate: true,
      );
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(adapter.searchCalls, 1);
      final states = <SourcePhase>[];
      service.reverse(
        Object(),
        14,
        121,
        (_, state, _) => states.add(state.phase),
      );
      clock.elapse(const Duration(seconds: 2));
      clock.flushMicrotasks();
      expect(adapter.reverseCalls, 0);
      adapter.pending.complete([]);
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(adapter.reverseCalls, 1);
      expect(states.last, SourcePhase.complete);
      expect(
        ((jsonDecode(disk!) as Map)['starts']['geoapify'] as List).length,
        2,
      );
      service.dispose();
    });
  });

  test('accounting failure prevents the reverse request', () {
    fakeAsync((clock) {
      DateTime now() => DateTime.utc(2026, 10, 29).add(clock.elapsed);
      final ledger = QuotaLedger(
        now: now,
        read: () async => null,
        write: (_) async => throw StateError('storage failed'),
      );
      final adapter = _Adapter();
      final service = CombinedPlaceSearch([adapter], ledger, now: now);
      final states = <SourcePhase>[];
      service.reverse(Object(), 14, 121, (_, s, _) => states.add(s.phase));
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(adapter.reverseCalls, 0);
      expect(states.last, SourcePhase.unavailable);
      service.dispose();
    });
  });

  test(
    'cancelling an in-flight reverse lookup suppresses its late response',
    () {
      fakeAsync((clock) {
        DateTime now() => DateTime.utc(2026, 10, 29).add(clock.elapsed);
        final ledger = QuotaLedger(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final adapter = _Adapter()..reversePending = Completer();
        final service = CombinedPlaceSearch([adapter], ledger, now: now);
        final owner = Object();
        final states = <SourcePhase>[];
        service.reverse(
          owner,
          14,
          121,
          (_, state, _) => states.add(state.phase),
        );
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
        expect(states.last, SourcePhase.loading);
        service.cancel(owner, only: {'geoapify'});
        adapter.reversePending!.complete([]);
        clock.flushMicrotasks();
        expect(states, isNot(contains(SourcePhase.complete)));
        service.dispose();
      });
    },
  );
}

class _Adapter extends SearchAdapter {
  final pending = Completer<List<PlaceSearchResult>>();
  Completer<List<PlaceSearchResult>>? reversePending;
  int searchCalls = 0, reverseCalls = 0;
  @override
  String get id => 'geoapify';
  @override
  String get endpoint => 'https://fixture.invalid';
  @override
  bool get enabled => true;
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) {
    searchCalls++;
    return pending.future;
  }

  @override
  Future<List<PlaceSearchResult>> reverse(
    double latitude,
    double longitude,
  ) async {
    reverseCalls++;
    final pending = reversePending;
    return pending == null ? [] : await pending.future;
  }
}
