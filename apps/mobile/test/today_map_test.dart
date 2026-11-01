import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/presentation/regional_map.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/presentation/today_view.dart';

void main() {
  testWidgets('Today map shows only confirmed places and updates markers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlaceMapRequest? latest;
    final container = ProviderContainer(
      overrides: [
        mapPlatformSupportedProvider.overrideWithValue(true),
        dayRepositoryProvider.overrideWithValue(MemoryDayRepository()),
        placeMapBuilderProvider.overrideWithValue((request) {
          latest = request;
          return const Text('Map fixture');
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const TodayView(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(latest!.philippinesOverview, isTrue);
    expect(latest!.iconOnlyAttribution, isTrue);
    expect(latest!.interactive, isFalse);
    expect(latest!.compactMarkers, isTrue);
    expect(find.text('Map preview'), findsNothing);
    expect(find.text('A From · Z To'), findsNothing);
    expect(latest!.pins, isEmpty);
    final controller = container.read(todayProvider.notifier);
    controller.restore(
      DayPlan(
        from: 'Home',
        fromPlace: const PlaceIntent(
          label: 'Home',
          latitude: 14.5,
          longitude: 121,
        ),
        to: 'Unresolved',
        errands: const [
          Errand(id: 'a', title: 'Unresolved'),
          Errand(
            id: 'b',
            title: 'Shop',
            placeIntent: PlaceIntent(
              label: 'Shop',
              latitude: 10.3,
              longitude: 123.9,
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(latest!.pins.map((pin) => pin.label), ['A', '2']);
    controller.setEndpoint(
      start: false,
      value: const PlaceIntent(label: 'End', latitude: 7.1, longitude: 125.6),
    );
    await tester.pumpAndSettle();
    expect(latest!.pins.map((pin) => pin.label), ['A', '2', 'Z']);
    expect(find.text('Unresolved'), findsWidgets);
    expect(find.text('Plan my day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
