import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/presentation/saved_places_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'today_test.dart' as helper;

void main() {
  testWidgets(
    'suggestions require review and title edits preserve accepted details',
    (tester) async {
      final container = await helper.launch(tester);
      final controller = container.read(todayProvider.notifier);
      controller.clear();
      const title =
          'Buy groceries at any Puregold, finish before 5 PM, allow 30 minutes';
      controller.add(title);
      await tester.pumpAndSettle();
      expect(
        container.read(todayProvider).errands.single.timing,
        TimingRule.anytime,
      );
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(
        find.text('15 minutes assumed · adjust for this visit.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Review suggested details'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.text('Use suggested details'));
      await tester.tap(find.text('Use suggested details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final accepted = container.read(todayProvider).errands.single;
      expect(accepted.placeIntent.kind, PlaceKind.search);
      expect(accepted.placeIntent.brand, 'Puregold');
      expect(accepted.minute, 1020);
      expect(accepted.durationMinutes, 30);
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('errand-title')),
        'Groceries, finish before 6 PM, allow 60 minutes',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final edited = container.read(todayProvider).errands.single;
      expect(edited.minute, 1020);
      expect(edited.durationMinutes, 30);
      expect(edited.inputText, title);
      expect(
        edited.confirmedFields,
        containsAll(['place', 'timing', 'duration']),
      );
    },
  );

  testWidgets('legacy saved names survive and can be resolved on map', (
    tester,
  ) async {
    final container = await helper.launch(tester);
    container
        .read(savedPlacesProvider.notifier)
        .save(const PlaceIntent(label: 'My office'));
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    if (find.byTooltip('Clear search').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('My office'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).fromPlace.hasCoordinates, isTrue);
    expect(container.read(savedPlacesProvider).single.place.label, 'My office');
    expect(
      container.read(savedPlacesProvider).single.place.hasCoordinates,
      isFalse,
    );
  });

  testWidgets(
    'invalid visit duration prevents saving and Back discards the draft',
    (tester) async {
      final container = await helper.launch(tester);
      await tester.tap(find.text('Capstone presentation'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.byKey(const Key('errand-duration')));
      await tester.enterText(find.byKey(const Key('errand-duration')), '0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Enter between 1 and 1,440 minutes.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands[1].durationMinutes, 15);
    },
  );
}
