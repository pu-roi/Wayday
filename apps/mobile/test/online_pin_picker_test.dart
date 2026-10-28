import 'dart:async';
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
  testWidgets('bookmark saves the selected pin locally', (tester) async {
    final database = WaydayDatabase(NativeDatabase.memory());
    final repositories = await LocalRepositories.open(database: database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          locationReaderProvider.overrideWithValue(
            () async => throw const LocationUnavailable(
              'Location permission is unavailable. Move the map to choose your pin.',
            ),
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
            locationReaderProvider.overrideWithValue(
              () async => const LocationFix(14.5, 121.0, 30),
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
      expect(find.text('Dropped pin'), findsWidgets);
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

  testWidgets('moving the map wins over a late device-location result', (
    tester,
  ) async {
    final fix = Completer<LocationFix>();
    PlaceMapRequest? request;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationReaderProvider.overrideWithValue(() => fix.future),
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
