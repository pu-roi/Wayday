import 'package:wayday/features/places/data/google_search.dart';
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
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
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
        searchSourceChoiceProvider.overrideWithValue(
          SearchSourceChoice()..choose(SearchSource.others),
        ),
        combinedPlaceSearchProvider.overrideWith((ref) {
          final service = CombinedPlaceSearch(
            [
              HttpSearchAdapter(
                client,
                'photon',
                endpoint: 'https://example.test/api',
              ),
            ],
            QuotaLedger(
              read: () async => null,
              write: (_) async {},
              now: tester.binding.clock.now,
            ),
            now: tester.binding.clock.now,
          );
          ref.onDispose(service.dispose);
          return service;
        }),
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
    'system Back hides the keyboard and preserves search until explicitly closed',
    (tester) async {
      var returned = false;
      var calls = 0;
      await launch(
        tester,
        client: MockClient((_) async {
          calls++;
          return results('Cebu City');
        }),
        returned: (_) => returned = true,
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Cebu');
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(find.byKey(const Key('place-search-results')), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Cebu',
      );
      expect(returned, isFalse);
      // Back delivered after Android has already hidden the IME also stays in search.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-search-results')), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-search-results')), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Cebu',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(returned, isTrue);
    },
  );
  testWidgets(
    'keyboard dismissal and inset changes keep query and results open',
    (tester) async {
      var calls = 0;
      addTearDown(tester.view.resetViewInsets);
      await launch(
        tester,
        client: MockClient((_) async {
          calls++;
          return results('Cebu City');
        }),
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Cebu');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-search-results')), findsOneWidget);
      expect(find.text('Cebu City'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Cebu',
      );
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      // The field remains editable after the phone keyboard is shown again.
      await tester.showKeyboard(find.byKey(const Key('place-name')));
      await tester.pumpAndSettle();
      expect(find.text('Cebu City'), findsOneWidget);
      expect(calls, 1);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-search-results')), findsNothing);
    },
  );

  testWidgets('hiding the keyboard preserves an in-flight search response', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    addTearDown(tester.view.resetViewInsets);
    await launch(tester, client: MockClient((_) => pending.future));
    await tester.enterText(find.byKey(const Key('place-name')), 'Cebu');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pump(const Duration(milliseconds: 1500));
    tester.testTextInput.hide();
    tester.view.viewInsets = const FakeViewPadding();
    await tester.pump();
    pending.complete(results('Cebu City'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(find.text('Cebu City'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('place-name')))
          .controller!
          .text,
      'Cebu',
    );
  });
  testWidgets(
    'category navigation preserves text and waits for Search this area',
    (tester) async {
      var calls = 0;
      PlaceMapRequest? map;
      await launch(
        tester,
        client: MockClient((_) async {
          calls++;
          return results('Market');
        }),
        map: (value) => map = value,
      );
      map!.onViewportChanged!(14.5, 121, 12);
      await tester.enterText(find.byKey(const Key('place-name')), 'palengke');
      await tester.pump();
      await tester.tap(find.text('Find markets in this area'));
      await tester.pump(const Duration(seconds: 2));
      // The fixture only enables Photon, which deliberately does not serve categories.
      expect(calls, 0);
      await tester.ensureVisible(find.text('Back to map'));
      await tester.tap(find.text('Back to map'));
      await tester.pump();
      expect(find.text('Search this area'), findsOneWidget);
      map!.onViewportChanged!(14.6, 121, 12);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 0);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'palengke',
      );
      await tester.tap(find.text('Search this area'));
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 0);
    },
  );
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
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
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
    await tester.pump(const Duration(milliseconds: 1500));
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
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('place-search-results')),
        matching: find.text('Business'),
      ),
    );
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
      await tester.pump(const Duration(milliseconds: 1500));
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
      await tester.pump(const Duration(milliseconds: 1500));
      expect(calls, 1);
      await tester.tap(find.byTooltip('Close search'));
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
