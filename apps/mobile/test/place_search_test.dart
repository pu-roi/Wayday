import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/places/data/place_search_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'today_test.dart' as helper;

const synthetic = PlaceResult(
  id: 'osm/node/123',
  name: 'Synthetic school',
  latitude: 14.56,
  longitude: 121.075,
  address: 'Example Street',
  category: 'school',
);

class PendingSearch implements PlaceSearchRepository {
  final requests = <String, Completer<List<PlaceResult>>>{};
  @override
  Future<List<PlaceResult>> search(String query) =>
      (requests[query] = Completer()).future;
  @override
  Future<List<PlaceResult>> nearby(double latitude, double longitude) async =>
      [];
}

class MapPlaces implements PlaceSearchRepository {
  MapPlaces(this.results);
  final Future<List<PlaceResult>> results;
  @override
  Future<List<PlaceResult>> search(String query) async => [];
  @override
  Future<List<PlaceResult>> nearby(double latitude, double longitude) =>
      results;
}

void main() {
  testWidgets(
    'a unique mapped area names the pin and retains selected coordinates',
    (tester) async {
      final places = MapPlaces(
        Future.value([
          const PlaceResult(
            id: 'osm/relation/1',
            name: 'Synthetic mapped campus',
            latitude: 14.58,
            longitude: 121.081,
            matchKind: 'area',
          ),
        ]),
      );
      final container = await helper.launch(tester, places: places);
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-map-pin')));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic mapped campus'), findsOneWidget);
      expect(find.text('Dropped pin'), findsNothing);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      final point = container.read(todayProvider).fromPlace;
      expect(point.label, 'Synthetic mapped campus');
      expect(point.longitude, 121.08);
      expect(point.coordinateKind, 'selected_in_mapped_area');
    },
  );
  testWidgets(
    'nearby places require explicit choice rather than guessing identity',
    (tester) async {
      final container = await helper.launch(
        tester,
        places: MapPlaces(Future.value([synthetic])),
      );
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-map-pin')));
      await tester.pumpAndSettle();
      expect(find.text('Dropped pin'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, synthetic.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).from, synthetic.name);
      expect(
        container.read(todayProvider).fromPlace.longitude,
        synthetic.longitude,
      );
    },
  );
  testWidgets(
    'a late name lookup cannot rename an already confirmed manual pin',
    (tester) async {
      final pending = Completer<List<PlaceResult>>();
      final container = await helper.launch(
        tester,
        places: MapPlaces(pending.future),
      );
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose on map'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('test-map-pin')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      pending.complete([synthetic]);
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).from, 'Dropped pin');
    },
  );
  testWidgets(
    'debounced search ignores late results and selecting keeps canonical name',
    (tester) async {
      final places = PendingSearch();
      final container = await helper.launch(tester, places: places);
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final field = find.byKey(const Key('place-search'));
      await tester.enterText(field, 'ol');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(field, 'new');
      await tester.pump(const Duration(milliseconds: 400));
      places.requests['new']!.complete([synthetic]);
      await tester.pumpAndSettle();
      places.requests['ol']!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text(synthetic.name), findsOneWidget);
      await helper.reveal(tester, find.text(synthetic.name));
      await tester.tap(find.text(synthetic.name));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('place-name')), findsNothing);
      expect(find.text('Enter coordinates'), findsNothing);
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).from, synthetic.name);
      expect(container.read(todayProvider).fromPlace.source, synthetic.id);
      // Resolve the initial query without changing the closed picker.
      for (final request in places.requests.values) {
        if (!request.isCompleted) request.complete([]);
      }
      await tester.pumpAndSettle();
    },
  );
  testWidgets('search outage still allows a manual map pin', (tester) async {
    final places = PendingSearch();
    await helper.launch(tester, places: places);
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(find.byKey(const Key('place-search')), 'school');
    await tester.pump(const Duration(milliseconds: 400));
    places.requests.values.single.completeError(const PlaceSearchUnavailable());
    await tester.pumpAndSettle();
    expect(find.text('Place search is unavailable.'), findsOneWidget);
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    expect(find.text('14.580000, 121.080000'), findsOneWidget);
  });
  testWidgets('location can be cancelled and late fixes cannot move the pin', (
    tester,
  ) async {
    final pending = Completer<LocationFix>();
    await helper.launch(tester, locate: () => pending.future);
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel location'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    pending.complete(const LocationFix(1, 2, 5));
    await tester.pumpAndSettle();
    expect(find.text('14.580000, 121.080000'), findsOneWidget);
    expect(find.textContaining('Accuracy about'), findsNothing);
  });
  testWidgets(
    'whole location wait times out and map remains usable at large text',
    (tester) async {
      final pending = Completer<LocationFix>();
      await helper.launch(
        tester,
        size: const Size(375, 812),
        scale: 1.5,
        locate: () => pending.future,
      );
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byTooltip('Use my location'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 13));
      await tester.pumpAndSettle();
      expect(find.textContaining('No location fix yet.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('test-map-pin')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Confirm location'), findsOneWidget);
      pending.complete(const LocationFix(1, 2, 5));
      await tester.pumpAndSettle();
    },
  );
}
