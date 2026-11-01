import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('cache updates do not reframe a picker after focusing a place', (
    tester,
  ) async {
    MapLibreMap.useHybridComposition = true;
    final cache = GooglePinCache(read: () async => null, write: (_) async {});
    final focus = ValueNotifier<PlaceIntent?>(null);
    double? latitude, longitude, zoom;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [googlePinCacheProvider.overrideWithValue(cache)],
        child: MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: ValueListenableBuilder<PlaceIntent?>(
              valueListenable: focus,
              builder: (context, place, _) => PlaceMap(
                request: PlaceMapRequest(
                  centerPicker: true,
                  philippinesOverview: true,
                  focus: place,
                  focusRevision: place == null ? 0 : 1,
                  onViewportChanged: (lat, lon, value) {
                    latitude = lat;
                    longitude = lon;
                    zoom = value;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (find.text('Loading map…').evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Loading map…'), findsNothing);
    focus.value = const PlaceIntent(
      label: 'Selected place',
      latitude: 14.5995,
      longitude: 120.9842,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(() => cache.purge());
    await tester.pump(const Duration(seconds: 3));
    expect(latitude, closeTo(14.5995, .01));
    expect(longitude, closeTo(120.9842, .01));
    expect(zoom, closeTo(16, .2));
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    cache.dispose();
  });
  testWidgets('online map loads Cebu and returns a confirmed pin', (
    tester,
  ) async {
    MapLibreMap.useHybridComposition = true;
    PlaceIntent? chosen;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    chosen = await Navigator.push<PlaceIntent>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OnlinePinPicker(
                          initial: PlaceIntent(
                            kind: PlaceKind.specific,
                            label: 'Cebu',
                            latitude: 10.3157,
                            longitude: 123.8854,
                          ),
                        ),
                      ),
                    ),
                child: const Text('Open map'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Loading map…').evaluate().isEmpty) break;
    }
    expect(
      find.text('Loading map…'),
      findsNothing,
      reason: 'Online map did not become ready',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNotNull,
      reason: 'Online map did not become ready',
    );
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(chosen?.latitude, closeTo(10.3157, .001));
    expect(chosen?.longitude, closeTo(123.8854, .001));
  });
  testWidgets('an unresolved label requires an explicit map choice', (
    tester,
  ) async {
    MapLibreMap.useHybridComposition = true;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const OnlinePinPicker(
            initial: PlaceIntent(label: 'Unresolved'),
          ),
        ),
      ),
    );
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    do {
      await tester.pump(const Duration(milliseconds: 250));
    } while (find.text('Loading map…').evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline));
    expect(
      find.text('Loading map…'),
      findsNothing,
      reason: 'Online map did not become ready',
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Use map center'), findsNothing);
    await tester.drag(find.byType(PlaceMap), const Offset(90, -70));
    final moved = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(moved)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm location'),
              )
              .onPressed !=
          null) {
        break;
      }
    }
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
