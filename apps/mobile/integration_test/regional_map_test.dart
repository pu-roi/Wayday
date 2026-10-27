// Test-only native harness: never calls the application's SQLite bootstrap.
// Every edit below is isolated in memory; public verification markers are removed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/maps/data/regional_map_repository.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/recurring/data/group_repository.dart';
import 'package:wayday/features/recurring/presentation/recurring_controller.dart';

class _MissingBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Missing test map');
}

Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition,
  String description,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(condition(), isTrue, reason: description);
}

Future<void> useLabel(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('place-name')),
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.enterText(find.byKey(const Key('place-name')), label);
  await tester.ensureVisible(find.text('Use name only'));
  await tester.tap(find.text('Use name only'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm location'));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('actual bundled map renders offline and preserves manual drafts', (
    tester,
  ) async {
    MapLibreMapController? native;
    var ready = false;
    var idleCount = 0;
    final container = ProviderContainer(
      overrides: [
        placeMapBuilderProvider.overrideWithValue(
          (_) => const Text('Online map unavailable while offline'),
        ),
        dayRepositoryProvider.overrideWithValue(
          MemoryDayRepository(
            initialData: DayPlan(
              from: 'Test start',
              to: 'Test end',
              errands: [
                const Errand(
                  id: 'native-test',
                  title: 'Native map draft check',
                  place: 'Original errand',
                ),
              ],
            ),
          ),
        ),
        groupRepositoryProvider.overrideWithValue(MemoryGroupRepository()),
        regionalMapRendererProvider.overrideWithValue(
          (context, package, onReady) => NativeRegionalMap(
            package: package,
            onReady: () {
              ready = true;
              onReady();
            },
            onCreated: (controller) {
              native = controller;
              ready = false;
            },
            onIdle: () => idleCount++,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const WaydayApp()),
    );
    await tester.pumpAndSettle();
    final started = DateTime.now();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Offline Pasig/Ortigas preview'));
    await tester.tap(find.text('Offline Pasig/Ortigas preview'));
    await tester.pumpAndSettle();
    await waitFor(
      tester,
      () => ready,
      'Production readiness requires actual roads and labels, not idle alone.',
    );
    final map = native!;
    final mapSize = tester.getSize(
      find.byKey(const Key('native-regional-map')),
    );
    final ratio = tester.view.devicePixelRatio;
    final rect =
        Offset.zero & Size(mapSize.width * ratio, mapSize.height * ratio);
    final roads = await map.queryRenderedFeaturesInRect(rect, [
      'roads',
      'major-roads',
    ], null);
    final labels = await map.queryRenderedFeaturesInRect(rect, [
      'road-labels',
      'place-labels',
      'poi-labels',
    ], null);
    expect(roads, isNotEmpty);
    expect(labels, isNotEmpty);
    debugPrint(
      'WAYDAY_MAP_EVIDENCE readyMs=${DateTime.now().difference(started).inMilliseconds} roads=${roads.length} labels=${labels.length} idle=$idleCount',
    );
    expect(
      find.text('© OpenStreetMap contributors · Protomaps'),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.text('© OpenStreetMap contributors · Protomaps'),
    );
    await tester.tap(find.text('© OpenStreetMap contributors · Protomaps'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Noto-OFL.txt'), findsOneWidget);
    expect(find.textContaining('Tangram-Icons-MIT.txt'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('native-regional-map')));
    final beforePan = map.cameraPosition!;
    await tester.drag(
      find.byKey(const Key('native-regional-map')),
      const Offset(65, 35),
    );
    await tester.pumpAndSettle();
    await waitFor(
      tester,
      () => map.cameraPosition!.target != beforePan.target,
      'Native pan changes camera.',
    );
    final center = map.cameraPosition!.target;
    await map.moveCamera(CameraUpdate.newLatLngZoom(center, 14));
    await waitFor(
      tester,
      () => (map.cameraPosition!.zoom - 14).abs() < .1,
      'Native zoom changes camera.',
    );
    await map.addGeoJsonSource('verification-marker', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'Point',
            'coordinates': [center.longitude, center.latitude],
          },
        },
      ],
    });
    await map.addCircleLayer(
      'verification-marker',
      'verification-marker-layer',
      const CircleLayerProperties(circleRadius: 10, circleColor: '#285C86'),
    );
    await tester.pump(const Duration(seconds: 1));
    final featuresWithMarker = await map.queryRenderedFeaturesInRect(rect, [
      'verification-marker-layer',
    ], null);
    expect(featuresWithMarker, hasLength(1));
    expect(featuresWithMarker.single['geometry']['type'], 'Point');
    await map.removeLayer('verification-marker-layer');
    await map.removeSource('verification-marker');
    expect(
      await map.getLayerIds(),
      isNot(contains('verification-marker-layer')),
    );
    debugPrint(
      'WAYDAY_MAP_EVIDENCE pan=true zoom=${map.cameraPosition!.zoom} temporaryMarker=true',
    );

    // Back discards the endpoint draft, then a separate confirmation commits only a label.
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('place-name')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const Key('place-name')),
      'Canceled start',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).from, 'Test start');
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    await useLabel(tester, 'Confirmed manual start');
    expect(container.read(todayProvider).from, 'Confirmed manual start');

    // Confirming within the nested picker remains an errand draft until Save.
    await tester.tap(find.text('Native map draft check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await useLabel(tester, 'Canceled errand draft');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      container.read(todayProvider).errands.single.place,
      'Original errand',
    );
    await tester.tap(find.text('Native map draft check'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await useLabel(tester, 'Confirmed manual errand');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(todayProvider).errands.single.place,
      'Confirmed manual errand',
    );
    debugPrint(
      'WAYDAY_MAP_EVIDENCE endpointCancelSave=true errandDraftCancelSave=true',
    );

    // A new isolated container supplies a missing package. No personal repository is opened.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    final missingContainer = ProviderContainer(
      overrides: [
        dayRepositoryProvider.overrideWithValue(MemoryDayRepository()),
        groupRepositoryProvider.overrideWithValue(MemoryGroupRepository()),
        regionalMapRepositoryProvider.overrideWithValue(
          RegionalMapRepository(bundle: _MissingBundle()),
        ),
      ],
    );
    addTearDown(missingContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: missingContainer,
        child: const WaydayApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Offline Pasig/Ortigas preview'));
    await tester.tap(find.text('Offline Pasig/Ortigas preview'));
    await tester.pumpAndSettle();
    expect(find.text('Map unavailable'), findsOneWidget);
    expect(find.byKey(const Key('native-regional-map')), findsNothing);
    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    await useLabel(tester, 'Manual without package');
    expect(missingContainer.read(todayProvider).from, 'Manual without package');
    expect(tester.takeException(), isNull);
    debugPrint('WAYDAY_MAP_EVIDENCE unavailableManualSave=true');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
