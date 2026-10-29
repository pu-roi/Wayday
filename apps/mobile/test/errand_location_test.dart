import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'support/fake_location.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

class _ReverseAdapter extends SearchAdapter {
  Completer<List<PlaceSearchResult>>? pending;
  @override
  String get id => 'geoapify';
  @override
  String get endpoint => 'fixture';
  @override
  bool get enabled => true;
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) async => [
    const PlaceSearchResult(
      name: 'Arellano University - Andres Bonifacio Campus',
      latitude: 14.57,
      longitude: 121.06,
      sourceId: 'fixture',
      provider: 'geoapify',
    ),
  ];
  @override
  Future<List<PlaceSearchResult>> reverse(
    double latitude,
    double longitude,
  ) async => pending == null
      ? [
          PlaceSearchResult(
            name: 'San Agustin Avenue, Pinagbuhatan',
            latitude: latitude,
            longitude: longitude,
            sourceId: 'fixture',
            provider: 'geoapify',
          ),
        ]
      : pending!.future;
}

void main() {
  testWidgets('confirmed current location uses a nearby address in Where', (
    tester,
  ) async {
    final search = CombinedPlaceSearch([
      _ReverseAdapter(),
    ], QuotaLedger(read: () async => null, write: (_) async {}));
    addTearDown(search.dispose);
    Errand errand = const Errand(id: 'device', title: 'Pick up');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          locationPlatformProvider.overrideWithValue(FakeLocationPlatform()),
          placeMapBuilderProvider.overrideWithValue(
            (_) => const SizedBox.expand(),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(find.text('San Agustin Avenue, Pinagbuhatan'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.placeIntent.latitude, 14.58);
    expect(errand.placeIntent.longitude, 121.05);
    expect(errand.placeIntent.source, 'device');
  });
  testWidgets('a moved pin survives confirmation, saving, and reopening', (
    tester,
  ) async {
    Errand errand = const Errand(id: '1', title: 'Pick up');
    PlaceMapRequest? map;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeMapBuilderProvider.overrideWithValue((request) {
            map = request;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    map!.onMoveStarted!();
    map!.onSelect!(14.5995, 120.9842);
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(find.text('Dropped pin'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.placeIntent.latitude, 14.5995);
    expect(errand.placeIntent.longitude, 120.9842);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    expect(map!.focus!.latitude, 14.5995);
    expect(map!.focus!.longitude, 120.9842);
  });

  testWidgets('a confirmed errand pin receives its nearby address', (
    tester,
  ) async {
    final search = CombinedPlaceSearch([
      _ReverseAdapter(),
    ], QuotaLedger(read: () async => null, write: (_) async {}));
    addTearDown(search.dispose);
    Errand errand = const Errand(id: '2', title: 'Pick up');
    PlaceMapRequest? map;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          placeMapBuilderProvider.overrideWithValue((request) {
            map = request;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    map!.onSelect!(14.5995, 120.9842);
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(find.text('San Agustin Avenue, Pinagbuhatan'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.placeIntent.latitude, 14.5995);
    expect(errand.placeIntent.longitude, 120.9842);
    expect(errand.place, 'San Agustin Avenue, Pinagbuhatan');
  });

  testWidgets('existing Google pins retain their label in the row', (
    tester,
  ) async {
    Errand errand = const Errand(
      id: '3',
      title: 'Pick up',
      place: 'arellano',
      placeIntent: PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'arellano',
        provider: 'google_ui_kit',
        providerPlaceId: 'fixture-id',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('arellano'), findsOneWidget);
    expect(find.text('Google place'), findsNothing);
    expect(find.text('Name this location'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.placeIntent.providerPlaceId, 'fixture-id');
    expect(errand.placeIntent.label, 'arellano');
    expect(errand.placeIntent.toJson().containsKey('latitude'), isFalse);
  });

  testWidgets('Where selects an Other sources result and displays its name', (
    tester,
  ) async {
    final choice = SearchSourceChoice();
    final search = CombinedPlaceSearch([
      _ReverseAdapter(),
    ], QuotaLedger(read: () async => null, write: (_) async {}));
    addTearDown(search.dispose);
    addTearDown(choice.dispose);
    PlaceMapRequest? map;
    Errand errand = const Errand(id: '5', title: 'Pick up');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          searchSourceChoiceProvider.overrideWithValue(choice),
          placeMapBuilderProvider.overrideWithValue((request) {
            map = request;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    expect(find.text('Errand location'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('place-name')), 'arellano');
    await tester.pump();
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Other sources'), findsOneWidget);
    await tester.tap(find.text('Other sources'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(choice.value, SearchSource.others);
    const name = 'Arellano University - Andres Bonifacio Campus';
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    expect(map!.focus!.latitude, 14.57);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(find.text(name), findsOneWidget);
    expect(find.text('Google place'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.place, name);
    expect(errand.placeIntent.longitude, 121.06);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    expect(map!.focus!.latitude, 14.57);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(errand.place, name);
  });

  testWidgets('a late address does not replace a newer pin', (tester) async {
    final adapter = _ReverseAdapter()..pending = Completer();
    final search = CombinedPlaceSearch([
      adapter,
    ], QuotaLedger(read: () async => null, write: (_) async {}));
    addTearDown(search.dispose);
    PlaceMapRequest? map;
    Errand errand = const Errand(id: '4', title: 'Pick up');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          combinedPlaceSearchProvider.overrideWithValue(search),
          placeMapBuilderProvider.overrideWithValue((request) {
            map = request;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final result = await editErrand(context, errand);
                  if (result is SavedErrand) errand = result.errand;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    map!.onSelect!(14.5995, 120.9842);
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Finding address…'));
    await tester.pumpAndSettle();
    map!.onSelect!(10.3, 123.9);
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pump();
    adapter.pending!.complete([
      const PlaceSearchResult(
        name: 'Old road',
        latitude: 14.5995,
        longitude: 120.9842,
        sourceId: 'fixture',
        provider: 'geoapify',
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    expect(find.text('Old road'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(errand.placeIntent.latitude, 10.3);
    expect(errand.placeIntent.longitude, 123.9);
  });
}
