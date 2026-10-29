import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'dart:async';
import 'support/fake_location.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/data/wayday_database.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  testWidgets(
    'provider pin label can be edited and confirmed without moving the pin',
    (tester) async {
      PlaceIntent? chosen;
      const original = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Arellano University',
        latitude: 14.6,
        longitude: 121.0,
        source: 'geoapify',
        provider: 'geoapify',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeMapBuilderProvider.overrideWithValue(
              (_) => const SizedBox.expand(),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    chosen = await Navigator.push<PlaceIntent>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const OnlinePinPicker(initial: original),
                      ),
                    ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open picker'));
      await tester.pumpAndSettle();
      final label = find.widgetWithText(TextFormField, 'Your label');
      expect(label, findsOneWidget);
      expect(
        tester.widget<TextFormField>(label).controller?.text ??
            tester.widget<TextFormField>(label).initialValue,
        'Arellano University',
      );
      await tester.enterText(label, 'My university');
      await tester.pump();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(chosen!.label, 'My university');
      expect(chosen!.latitude, 14.6);
      expect(chosen!.longitude, 121.0);
      expect(chosen!.provider, 'geoapify');
      expect(chosen!.source, 'user');
    },
  );

  testWidgets('Google custom label preserves the place reference and lease', (
    tester,
  ) async {
    PlaceIntent? chosen;
    final lease = GooglePinLease()
      ..latitude = 14.6
      ..longitude = 121.0
      ..acquiredAt = DateTime.now();
    final original = PlaceIntent(
      kind: PlaceKind.providerReference,
      label: 'search text',
      provider: 'google_ui_kit',
      providerPlaceId: 'place-id',
      source: 'google_ui_kit',
      googlePin: lease,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeMapBuilderProvider.overrideWithValue(
            (_) => const SizedBox.expand(),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => chosen = await Navigator.push<PlaceIntent>(
                context,
                MaterialPageRoute(
                  builder: (_) => OnlinePinPicker(initial: original),
                ),
              ),
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Your label'),
      'My meeting place',
    );
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(chosen!.label, 'My meeting place');
    expect(chosen!.providerPlaceId, 'place-id');
    expect(chosen!.googlePin, same(lease));
    expect(chosen!.toJson(), isNot(contains('latitude')));
  });
  testWidgets('zoom label follows the map camera above location control', (
    tester,
  ) async {
    PlaceMapRequest? request;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          placeMapBuilderProvider.overrideWithValue((value) {
            request = value;
            return const SizedBox.expand();
          }),
        ],
        child: const MaterialApp(home: OnlinePinPicker(initial: null)),
      ),
    );
    expect(find.byKey(const Key('map-zoom-label')), findsNothing);
    expect(request!.interactive, isTrue);
    expect(request!.compactMarkers, isFalse);
    request!.onZoomChanged!(4.7);
    await tester.pump();
    expect(find.text('Z: 4.7'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('map-zoom-label'))).width,
      tester.getSize(find.byKey(const Key('map-location-control'))).width,
    );
    expect(
      tester.getBottomLeft(find.byKey(const Key('map-zoom-label'))).dy,
      lessThan(tester.getTopLeft(find.byTooltip('Use my location')).dy),
    );
    request!.onZoomChanged!(12.34);
    await tester.pump();
    expect(find.text('Z: 12.3'), findsOneWidget);
  });

  testWidgets('bookmark saves the selected pin locally', (tester) async {
    final database = WaydayDatabase(NativeDatabase.memory());
    final repositories = await LocalRepositories.open(
      database: database,
      googlePins: GooglePinCache(read: () async => null, write: (_) async {}),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          localRepositoriesProvider.overrideWithValue(repositories),
          placeMapBuilderProvider.overrideWithValue(
            (request) => TextButton(
              onPressed: () => request.onSelect!(10.3, 123.9),
              child: const Text('Move map'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: OnlinePinPicker(initial: PlaceIntent(label: 'Cebu')),
        ),
      ),
    );
    await tester.tap(find.text('Move map'));
    await tester.pump();
    await tester.tap(find.byTooltip('Save to my places'));
    await tester.pumpAndSettle();
    final saved = await repositories.savedPlaces.read();
    expect(saved.single.place.label, 'Cebu');
    expect(saved.single.place.latitude, 10.3);
    await database.close();
  });

  testWidgets('location denial leaves manual selection available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          locationPlatformProvider.overrideWithValue(
            FakeLocationPlatform(access: LocationAccess.denied)
              ..grant = LocationAccess.denied,
          ),
          placeMapBuilderProvider.overrideWithValue(
            (request) => TextButton(
              onPressed: () => request.onSelect!(10.3, 123.9),
              child: const Text('Move map'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: OnlinePinPicker(initial: PlaceIntent(label: 'Cebu')),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Location permission is unavailable'),
      findsOneWidget,
    );
    await tester.tap(find.text('Move map'));
    await tester.pump();
    expect(find.text('Cebu'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'explicit location request focuses the map and can be confirmed once',
    (tester) async {
      PlaceMapRequest? request;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchSourceChoiceProvider.overrideWithValue(
              SearchSourceChoice()..choose(SearchSource.others),
            ),
            locationPlatformProvider.overrideWithValue(
              FakeLocationPlatform(
                reader: () async => const LocationFix(14.5, 121.0, 30),
              ),
            ),
            placeMapBuilderProvider.overrideWithValue((value) {
              request = value;
              return const SizedBox();
            }),
          ],
          child: const MaterialApp(
            home: OnlinePinPicker(initial: PlaceIntent(label: 'Home')),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Use my location'));
      await tester.pumpAndSettle();
      expect(request!.focus!.latitude, 14.5);
      expect(request!.focusZoom, 18);
      expect(request!.animateFocus, isTrue);
      expect(find.textContaining('Accuracy about 30 m'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNotNull,
      );
      expect(request!.focus!.longitude, 121.0);
    },
  );

  testWidgets('map pin confirmation returns chosen coordinates', (
    tester,
  ) async {
    PlaceIntent? chosen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          placeMapBuilderProvider.overrideWithValue(
            (request) => TextButton(
              onPressed: () => request.onSelect!(10.3, 123.9),
              child: const Text('Move map'),
            ),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    chosen = await Navigator.push<PlaceIntent>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnlinePinPicker(
                          initial: PlaceIntent(label: 'Cebu'),
                        ),
                      ),
                    ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Move map'));
    await tester.pump();
    expect(find.byTooltip('Use my location'), findsOneWidget);
    expect(find.byTooltip('Save to my places'), findsOneWidget);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(chosen?.label, 'Cebu');
    expect(chosen?.latitude, 10.3);
    expect(chosen?.longitude, 123.9);
  });

  testWidgets(
    'an existing confirmed place keeps its identity until a user moves the map',
    (tester) async {
      PlaceMapRequest? request;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchSourceChoiceProvider.overrideWithValue(
              SearchSourceChoice()..choose(SearchSource.others),
            ),
            placeMapBuilderProvider.overrideWithValue((value) {
              request = value;
              return const SizedBox();
            }),
          ],
          child: const MaterialApp(
            home: OnlinePinPicker(
              initial: PlaceIntent(
                kind: PlaceKind.specific,
                label: 'Branch',
                latitude: 10.3,
                longitude: 123.9,
                source: 'osm/node/1',
                address: 'Old address',
              ),
            ),
          ),
        ),
      );
      expect(find.text('Old address'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNotNull,
      );
      request!.onMoveStarted!();
      await tester.pump();
      expect(find.text('Positioning pin…'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNull,
      );
      request!.onSelect!(10.4, 123.8);
      await tester.pump();
      expect(find.text('Old address'), findsNothing);
      expect(find.text('Dropped pin'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Branch',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm location'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('map movement leaves an empty search field empty', (
    tester,
  ) async {
    PlaceMapRequest? request;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          placeMapBuilderProvider.overrideWithValue((value) {
            request = value;
            return const SizedBox.expand(key: Key('test-map'));
          }),
        ],
        child: const MaterialApp(home: OnlinePinPicker(initial: null)),
      ),
    );
    request!.onSelect!(14.5, 121);
    await tester.pump();
    final mapHeight = tester.getSize(find.byKey(const Key('test-map'))).height;
    request!.onMoveStarted!();
    await tester.pump();
    expect(tester.getSize(find.byKey(const Key('test-map'))).height, mapHeight);
    expect(find.text('Positioning pin…'), findsNothing);
    request!.onSelect!(14.6, 121.1);
    await tester.pump();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('place-name')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Dropped pin'), findsOneWidget);
  });

  testWidgets('moving the map wins over a late device-location result', (
    tester,
  ) async {
    final fix = Completer<LocationFix>();
    PlaceMapRequest? request;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          locationPlatformProvider.overrideWithValue(
            FakeLocationPlatform(reader: () => fix.future),
          ),
          placeMapBuilderProvider.overrideWithValue((value) {
            request = value;
            return const SizedBox();
          }),
        ],
        child: const MaterialApp(home: OnlinePinPicker(initial: null)),
      ),
    );
    await tester.tap(find.byTooltip('Use my location'));
    await tester.pump();
    request!.onMoveStarted!();
    request!.onSelect!(10.3, 123.9);
    await tester.pump();
    fix.complete(const LocationFix(14.5, 121, 30));
    await tester.pumpAndSettle();
    expect(request!.focus!.latitude, 10.3);
    expect(find.text('Current location'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNotNull,
    );
  });
}
