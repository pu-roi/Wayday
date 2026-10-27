import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/data/local_repositories.dart';
import 'package:wayday/core/widgets/place_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/philippine_place_search.dart';
import 'package:wayday/features/places/data/saved_place_repository.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

http.Response results(String name) => http.Response(
  jsonEncode({
    'features': [
      {
        'properties': {
          'name': name,
          'countrycode': 'PH',
          'osm_type': 'N',
          'osm_id': 123,
          'street': 'Main Street',
        },
        'geometry': {
          'type': 'Point',
          'coordinates': [123.9, 10.3],
        },
      },
    ],
  }),
  200,
);

class Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

Future<void> launch(
  WidgetTester tester, {
  required MockClient client,
  ValueChanged<PlaceIntent?>? returned,
  SavedPlaceRepository? saved,
  ValueChanged<PlaceMapRequest>? map,
  Routes? routes,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        philippinePlaceSearchProvider.overrideWithValue(
          PhilippinePlaceSearch(client, Uri.parse('https://example.test/api')),
        ),
        savedPlaceRepositoryProvider.overrideWithValue(saved),
        placeMapBuilderProvider.overrideWithValue((request) {
          map?.call(request);
          return TextButton(
            onPressed: () {
              request.onMoveStarted?.call();
              request.onSelect?.call(14.5, 121.5);
            },
            child: const Text('Move map'),
          );
        }),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        navigatorObservers: [?routes],
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final place = await choosePlace(
                  context,
                  title: 'Starting point',
                  initial: '',
                );
                returned?.call(place);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'small-phone search and confirmation handle long names at larger text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const name = 'Pambansang Paaralan at Sentro ng Serbisyo sa Barangay';
      await launch(
        tester,
        scale: 1.5,
        client: MockClient((_) async => results(name)),
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Paaralan');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ListTile, name));
      await tester.tap(find.widgetWithText(ListTile, name));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.text('Confirm location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('search and map share one route with one confirmation', (
    tester,
  ) async {
    final client = MockClient((_) async => results('Cebu City'));
    PlaceIntent? selected;
    PlaceMapRequest? map;
    final routes = Routes();
    await launch(
      tester,
      client: client,
      returned: (value) => selected = value,
      map: (value) => map = value,
      routes: routes,
    );
    expect(find.text('Move map'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('Choose on map'), findsNothing);
    expect(find.text('Use map center'), findsNothing);
    await tester.enterText(find.byKey(const Key('place-name')), 'Cebu');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cebu City'));
    await tester.pumpAndSettle();
    expect(routes.pushes, 2);
    expect(map!.focus!.label, 'Cebu City');
    expect(map!.focus!.source, 'osm/node/123');
    expect(find.text('Main Street'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(selected?.label, 'Cebu City');
    expect(selected?.latitude, 10.3);
  });

  testWidgets('panning after search clears old identity and confirms once', (
    tester,
  ) async {
    PlaceIntent? selected;
    await launch(
      tester,
      client: MockClient((_) async => results('Business')),
      returned: (value) => selected = value,
    );
    await tester.enterText(find.byKey(const Key('place-name')), 'Business');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Business'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move map'));
    await tester.pump();
    expect(find.text('Main Street'), findsNothing);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(selected?.label, 'Dropped pin');
    expect(selected?.source, 'manual');
    expect(selected?.address, isNull);
  });

  testWidgets('saved places remain selectable without network search', (
    tester,
  ) async {
    final saved = MemorySavedPlaceRepository();
    await saved.add(
      const SavedPlace(
        id: 'p1',
        place: PlaceIntent(
          kind: PlaceKind.specific,
          label: 'Saved Cebu',
          latitude: 10.3,
          longitude: 123.9,
        ),
      ),
    );
    PlaceIntent? selected;
    await launch(
      tester,
      client: MockClient((_) async => throw StateError('offline')),
      saved: saved,
      returned: (value) => selected = value,
    );
    await tester.tap(find.byKey(const Key('place-name')));
    await tester.pump();
    await tester.tap(find.text('Saved Cebu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(selected?.savedPlaceId, 'p1');
    expect(selected?.latitude, 10.3);
  });

  testWidgets(
    'failed search offers explicit name-only entry with no invented pin',
    (tester) async {
      PlaceIntent? selected;
      await launch(
        tester,
        client: MockClient((_) async => http.Response('', 503)),
        returned: (value) => selected = value,
      );
      await tester.enterText(
        find.byKey(const Key('place-name')),
        'Library entrance',
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Place search is unavailable.'), findsOneWidget);
      await tester.ensureVisible(find.text('Use name only'));
      await tester.tap(find.text('Use name only'));
      await tester.pumpAndSettle();
      expect(find.text('Name only · No map pin'), findsOneWidget);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(selected?.label, 'Library entrance');
      expect(selected?.hasCoordinates, isFalse);
    },
  );

  testWidgets(
    'closing search ignores stale results and Back cancels the picker',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      var returned = false;
      await launch(
        tester,
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
        returned: (value) {
          returned = true;
          expect(value, isNull);
        },
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Cebu');
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Move map'), findsOneWidget);
      pending.complete(results('Old Cebu'));
      await tester.pumpAndSettle();
      expect(find.text('Old Cebu'), findsNothing);
      expect(returned, isFalse);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(returned, isTrue);
    },
  );
}
