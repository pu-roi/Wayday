import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';

/// Actual MapLibre/free basemap, memory repositories and no paid providers/GPS.
void main() {
  MapLibreMap.useHybridComposition = true;
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Today map survives tabs with its camera and markers', (
    tester,
  ) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity!['package'], endsWith('.maptest'));
    final container = ProviderContainer(
      overrides: [
        dayRepositoryProvider.overrideWithValue(MemoryDayRepository()),
        itineraryRepositoryProvider.overrideWithValue(
          MemoryItineraryRepository(),
        ),
        combinedPlaceSearchProvider.overrideWithValue(
          CombinedPlaceSearch(
            [],
            QuotaLedger(read: () async => null, write: (_) async {}),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const WaydayApp()),
    );
    Future<void> revealMap() async {
      await tester.scrollUntilVisible(
        find.byType(PlaceMap),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    await revealMap();
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (find.text('Loading map…').evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Loading map…'), findsNothing);
    expect(find.textContaining('Map unavailable or slow'), findsNothing);
    final nativeId = tester
        .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
        .controller
        .viewId;
    final channel = MethodChannel('plugins.flutter.io/maplibre_gl_$nativeId');
    await channel.invokeMethod<bool>('camera#move', {
      'cameraUpdate': CameraUpdate.newLatLngZoom(
        const LatLng(14.58, 121.06),
        12,
      ).toJson(),
    });
    await tester.pump(const Duration(seconds: 2));
    final camera = await channel.invokeMethod<Object?>(
      'map#queryCameraPosition',
    );
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    Future<void> capture(String suffix) async {
      await File(
        '${Directory.systemTemp.path}/today-tab-$suffix.png',
      ).writeAsBytes(await binding.takeScreenshot('today-tab-$suffix'));
    }

    await capture('before');
    for (var pass = 0; pass < 3; pass++) {
      for (final name in ['Recurring', 'Profile', 'Settings']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(name),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(PlaceMap), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Today'),
          ),
        );
        await tester.pump();
        expect(find.text('Loading map…'), findsNothing);
        expect(
          tester
              .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
              .controller
              .viewId,
          nativeId,
        );
        expect(
          await channel.invokeMethod<Object?>('map#queryCameraPosition'),
          camera,
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }
    await capture('returned');
    container
        .read(todayProvider.notifier)
        .setEndpoint(
          start: true,
          value: const PlaceIntent(
            label: 'Synthetic start',
            latitude: 14.58,
            longitude: 121.06,
          ),
        );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
          .controller
          .viewId,
      nativeId,
    );
    expect(
      tester.widget<PlaceMap>(find.byType(PlaceMap)).request.pins.single.label,
      'A',
    );
    // GeoJSON update and native source rendering finish after the Flutter frame.
    // Wait for observable source content, rather than assuming a pump awaited it.
    List<Object?> features = [];
    final markerDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (features.isEmpty && DateTime.now().isBefore(markerDeadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      final reply = await channel.invokeMapMethod<String, Object?>(
        'map#querySourceFeatures',
        {'sourceId': 'wayday-stops'},
      );
      features = (reply!['features'] as List).cast<Object?>();
    }
    expect(features, isNotEmpty);
    await capture('markers');
    debugPrint(
      'WAYDAY_TODAY_TAB_RETENTION_PASSED nativeView=$nativeId switches=9',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
