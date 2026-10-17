import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/presentation/saved_places_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'today_test.dart' as helper;

const testPin = PlaceIntent(
  kind: PlaceKind.specific,
  label: 'Synthetic test place',
  latitude: 14.58,
  longitude: 121.08,
  source: 'test',
);
DayPlan reviewDay() => DayPlan(
  from: 'Start',
  to: 'Finish',
  fromPlace: testPin,
  toPlace: testPin,
  errands: const [
    Errand(
      id: 'a',
      title: 'bili gamot',
      place: 'Branch A',
      placeIntent: testPin,
    ),
    Errand(
      id: 'b',
      title: 'Groceries',
      place: 'Branch B',
      placeIntent: testPin,
    ),
  ],
);

void main() {
  testWidgets(
    'review reorder and priority changes commit only on confirmation',
    (tester) async {
      final container = await helper.launch(tester);
      final today = container.read(todayProvider.notifier);
      today.restore(reviewDay());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.byTooltip('Options for bili gamot'));
      await tester.tap(find.byTooltip('Options for bili gamot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move later'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.first.id, 'a');
      await helper.reveal(tester, find.byTooltip('Options for bili gamot'));
      await tester.tap(find.byTooltip('Options for bili gamot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make optional'));
      await tester.pumpAndSettle();
      await helper.capture(tester, 'm2-review');
      await tester.tap(find.text('Find your way'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.map((e) => e.id), [
        'b',
        'a',
      ]);
      expect(container.read(todayProvider).errands.last.optional, true);
      expect(
        container.read(todayProvider).errands.last.inputText,
        'bili gamot',
      );
    },
  );

  testWidgets(
    'saved branch selection changes only the review until confirmed',
    (tester) async {
      final container = await helper.launch(tester);
      container.read(todayProvider.notifier).restore(reviewDay());
      container
          .read(savedPlacesProvider.notifier)
          .save(
            const PlaceIntent(
              kind: PlaceKind.specific,
              label: 'Saved branch alternative',
              latitude: 14.59,
              longitude: 121.09,
            ),
          );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.text('Branch A'));
      await tester.tap(find.text('Branch A'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.text('Saved branch alternative'));
      await tester.tap(find.text('Saved branch alternative'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.first.place, 'Branch A');
      await tester.tap(find.text('Find your way'));
      await tester.pumpAndSettle();
      expect(
        container.read(todayProvider).errands.first.placeIntent.longitude,
        121.09,
      );
      expect(
        container.read(todayProvider).errands.first.placeIntent.kind,
        PlaceKind.saved,
      );
    },
  );

  testWidgets('a stale review cannot replace newer Today edits', (
    tester,
  ) async {
    final container = await helper.launch(tester);
    container.read(todayProvider.notifier).restore(reviewDay());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();
    container.read(todayProvider.notifier).add('Newer edit');
    await tester.tap(find.text('Find your way'));
    await tester.pumpAndSettle();
    await helper.reveal(tester, find.text('Reload Today'));
    expect(find.textContaining('Today changed'), findsOneWidget);
    expect(container.read(todayProvider).errands.last.title, 'Newer edit');
    await tester.pageBack();
    await tester.pumpAndSettle();
  });

  testWidgets('manual pin needs no custom name or coordinate entry', (
    tester,
  ) async {
    final container = await helper.launch(tester);
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    expect(find.text('Enter coordinates'), findsNothing);
    expect(find.byKey(const Key('place-name')), findsNothing);
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    expect(find.text('14.580000, 121.080000'), findsOneWidget);
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).fromPlace.kind, PlaceKind.specific);
    expect(container.read(todayProvider).from, 'Dropped pin');
  });

  testWidgets('denied location leaves manual pin entry usable', (tester) async {
    await helper.launch(tester);
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    await helper.reveal(tester, find.byTooltip('Use my location'));
    await tester.tap(find.byTooltip('Use my location'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Location permission is unavailable'),
      findsOneWidget,
    );
    await helper.reveal(tester, find.byKey(const Key('test-map-pin')));
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    expect(find.text('14.580000, 121.080000'), findsOneWidget);
  });

  testWidgets(
    'late location result does not overwrite a manually selected pin',
    (tester) async {
      final pending = Completer<LocationFix>();
      await helper.launch(tester, locate: () => pending.future);
      await tester.tap(find.byKey(const Key('from-map')));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.byTooltip('Use my location'));
      await tester.tap(find.byTooltip('Use my location'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.byKey(const Key('test-map-pin')));
      await tester.tap(find.byKey(const Key('test-map-pin')));
      await tester.pump();
      pending.complete(const LocationFix(1, 2, 10));
      await tester.pumpAndSettle();
      expect(find.text('14.580000, 121.080000'), findsOneWidget);
      expect(find.textContaining('Location accuracy'), findsNothing);
    },
  );

  testWidgets(
    'review reflows on a small phone with large text and in landscape',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final container = await helper.launch(
        tester,
        size: const Size(375, 812),
        scale: 1.5,
      );
      container.read(todayProvider.notifier).restore(reviewDay());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plan my day'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.byTooltip('Options for bili gamot'));
      expect(tester.takeException(), isNull);
      await helper.capture(tester, 'm2-review-large-text');
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.textContaining('Home by'));
      expect(tester.takeException(), isNull);
      await helper.capture(tester, 'm2-review-landscape');
    },
  );
}
