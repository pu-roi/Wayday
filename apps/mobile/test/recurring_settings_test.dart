import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/settings_view.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/reusable_trip_repository.dart';
import 'package:wayday/features/planning/presentation/reusable_trip_controls.dart';
import 'package:wayday/features/recurring/presentation/recurring_view.dart';
import 'package:wayday/features/recurring/presentation/recurring_controller.dart';
import 'package:wayday/features/recurring/data/group_repository.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'helpers/planning_fixtures.dart' as fixtures;

ReusableTrip savedTrip() {
  final day = fixtures.fixture();
  return ReusableTrip(
    id: 'trip',
    name: 'Weekend errands',
    day: day,
    meaning: [
      for (final e in day.errands)
        ErrandNeed(
          id: e.id,
          query: e.title,
          locationIntent: LocationIntent.specific,
        ),
    ],
    choices: {for (final e in day.errands) e.id: e.placeIntent},
  );
}

class ControlledTrips extends MemoryReusableTripRepository {
  Future<List<ReusableTrip>>? nextRead;
  int reads = 0;
  @override
  Future<List<ReusableTrip>> read() {
    reads++;
    return nextRead ?? super.read();
  }
}

void main() {
  testWidgets(
    'Recurring separates errands and trips and retains tab selection',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reusableTripRepositoryProvider.overrideWithValue(
              MemoryReusableTripRepository(),
            ),
          ],
          child: MaterialApp(theme: buildTheme(), home: const RecurringView()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('No recurring lists yet.'), findsOneWidget);
      expect(find.byTooltip('New recurring list'), findsOneWidget);
      expect(
        find.text('Your familiar errands, all in one place.'),
        findsNothing,
      );
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      expect(find.text('No saved trips yet.'), findsOneWidget);
      expect(find.text('No recurring lists yet.'), findsNothing);
      expect(find.byTooltip('New recurring list'), findsNothing);
      await tester.tap(find.text('Errands'));
      await tester.pumpAndSettle();
      expect(find.text('No recurring lists yet.'), findsOneWidget);
    },
  );

  testWidgets('Settings uses the page title and an honest placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const SettingsView()),
    );
    expect(find.text('Settings are not available yet.'), findsOneWidget);
    expect(find.text('Offline Pasig/Ortigas preview'), findsNothing);
    expect(find.textContaining('coming later'), findsNothing);
    final title = tester.widget<Text>(find.text('Settings'));
    expect(title.style?.fontSize, 32);
    expect(tester.widget<AppBar>(find.byType(AppBar)).toolbarHeight, 64);
    await tester.ensureVisible(find.text('Map credits and licenses'));
    expect(find.text('Map credits and licenses'), findsOneWidget);
  });

  testWidgets(
    'populated tabs preserve disclosures, scroll, and independent copies',
    (tester) async {
      final trips = MemoryReusableTripRepository();
      await trips.save(savedTrip());
      final container = ProviderContainer(
        overrides: [
          reusableTripRepositoryProvider.overrideWithValue(trips),
          groupRepositoryProvider.overrideWithValue(
            MemoryGroupRepository(
              initialData: [
                for (var i = 0; i < 10; i++)
                  ErrandGroup(
                    id: 'group-$i',
                    name: 'Routine $i',
                    items: [
                      Errand(
                        id: 'item-$i',
                        title: 'Errand $i',
                        notes: 'Independent note',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: buildTheme(), home: const RecurringView()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Today').first);
      await tester.pumpAndSettle();
      expect(
        container.read(todayProvider).errands.single.notes,
        'Independent note',
      );
      expect(
        container.read(recurringProvider).first.items.single.title,
        'Errand 0',
      );
      await tester.tap(find.text('Routine 0'));
      await tester.pumpAndSettle();
      expect(find.text('Errand 0'), findsNothing);
      final errands = find.byKey(const PageStorageKey('recurring-errands'));
      await tester.drag(errands, const Offset(0, -250));
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find.descendant(of: errands, matching: find.byType(Scrollable)).first,
      );
      final offset = scroll.position.pixels;
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekend errands'));
      await tester.pumpAndSettle();
      expect(find.text('Use trip'), findsOneWidget);
      await tester.tap(find.text('Errands'));
      await tester.pumpAndSettle();
      expect(scroll.position.pixels, offset);
      await tester.drag(errands, const Offset(0, 900));
      await tester.pumpAndSettle();
      expect(find.text('Errand 0'), findsNothing);
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      expect(find.text('Use trip'), findsOneWidget);
      await tester.tap(find.text('Use trip'));
      await tester.pumpAndSettle();
      expect(find.byType(ReuseTripSheet), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await trips.read(), hasLength(1));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete').last);
      await tester.pumpAndSettle();
      expect(await trips.read(), isEmpty);
      expect(find.text('No saved trips yet.'), findsOneWidget);
    },
  );

  testWidgets('Trips loads lazily and failed reads wait for explicit retry', (
    tester,
  ) async {
    final pending = Completer<List<ReusableTrip>>();
    final trips = ControlledTrips()..nextRead = pending.future;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reusableTripRepositoryProvider.overrideWithValue(trips)],
        child: MaterialApp(theme: buildTheme(), home: const RecurringView()),
      ),
    );
    await tester.pumpAndSettle();
    expect(trips.reads, 0);
    await tester.tap(find.text('Trips'));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    pending.completeError(StateError('Fixture read failed'));
    await tester.pumpAndSettle();
    expect(find.text('Saved trips could not load. Retry'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    expect(trips.reads, 1);
    trips.nextRead = null;
    await tester.tap(find.text('Saved trips could not load. Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No saved trips yet.'), findsOneWidget);
    expect(trips.reads, 2);
  });
}
