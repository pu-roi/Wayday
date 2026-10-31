import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

/// Actual MapLibre/free basemap only. No Google, Gemini, GPS or personal storage.
void main() {
  MapLibreMap.useHybridComposition = true;
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('warm native picker pan and zoom profile', (tester) async {
    expect(kProfileMode, isTrue);
    var builds = 0;
    final frames = <ui.FrameTiming>[];
    void timing(List<ui.FrameTiming> values) => frames.addAll(values);
    final start = DateTime.now();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeMapBuilderProvider.overrideWithValue((request) {
            builds++;
            return PlaceMap(request: request);
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const OnlinePinPicker(
            initial: PlaceIntent(
              label: 'Profile test',
              source: 'manual',
              latitude: 14.58,
              longitude: 121.06,
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
    expect(find.textContaining('Map unavailable or slow'), findsNothing);
    expect(find.byKey(const Key('map-zoom-label')), findsOneWidget);
    final loadMs = DateTime.now().difference(start).inMilliseconds;
    // Warm the visible area before collecting interaction frame data.
    await tester.pump(const Duration(seconds: 3));
    String? zoomLabel() => tester
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const Key('map-zoom-label')),
                matching: find.byType(Text),
              )
              .first,
        )
        .data;
    final initialZoom = zoomLabel();
    final initialBuilds = builds;
    final nativeId = tester
        .widget<AndroidViewSurface>(find.byType(AndroidViewSurface))
        .controller
        .viewId;
    final nativeCamera = MethodChannel(
      'plugins.flutter.io/maplibre_gl_$nativeId',
    );
    SchedulerBinding.instance.addTimingsCallback(timing);
    final map = find.byType(PlaceMap);
    for (var i = 0; i < 6; i++) {
      await tester.timedDrag(
        map,
        Offset(i.isEven ? 80 : -80, 30),
        const Duration(milliseconds: 500),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final center = tester.getCenter(map);
      final a = await tester.startGesture(
        center + const Offset(-25, 0),
        pointer: 10,
      );
      final b = await tester.startGesture(
        center + const Offset(25, 0),
        pointer: 11,
      );
      for (var step = 1; step <= 15; step++) {
        await a.moveTo(center + Offset(-25 - step * 2, 0));
        await b.moveTo(center + Offset(25 + step * 2, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await a.up();
      await b.up();
      await tester.pump(const Duration(milliseconds: 500));
      // Drive the pinned native camera too: injected test pointer scaling is
      // inconsistent across emulator images. This still exercises real native
      // camera callbacks, rendering and the picker's zoom-update hot path.
      await nativeCamera.invokeMethod<bool>('camera#animate', {
        'cameraUpdate': CameraUpdate.zoomTo(i.isEven ? 16 : 17).toJson(),
        'duration': 500,
      });
      await tester.pump(const Duration(milliseconds: 750));
    }
    await tester.pump(const Duration(seconds: 1));
    SchedulerBinding.instance.removeTimingsCallback(timing);
    expect(
      zoomLabel(),
      isNot(initialZoom),
      reason: 'The native map must actually receive the pinch gestures.',
    );
    double percentile(Iterable<Duration> durations) {
      final values = durations.map((d) => d.inMicroseconds / 1000).toList()
        ..sort();
      return values.isEmpty ? 0 : values[((values.length - 1) * .95).round()];
    }

    binding.reportData = {
      'variant': const String.fromEnvironment('WAYDAY_PROFILE_VARIANT'),
      'screen': tester.view.physicalSize.toString(),
      'zoomStart': initialZoom,
      'zoomEnd': zoomLabel(),
      'loadMs': loadMs,
      'pickerMapBuilds': builds - initialBuilds,
      'frames': frames.length,
      'buildP95Ms': percentile(frames.map((f) => f.buildDuration)),
      'rasterP95Ms': percentile(frames.map((f) => f.rasterDuration)),
      'over16ms': frames
          .where((f) => f.totalSpan.inMicroseconds > 16667)
          .length,
    };
    await tester.pumpWidget(const SizedBox());
  });
}
