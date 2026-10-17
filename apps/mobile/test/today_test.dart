import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/recurring/presentation/recurring_controller.dart';
import 'package:wayday/core/widgets/feedback.dart';

import 'package:wayday/features/today/data/day_repository.dart';
import 'fixtures/example_day.dart';
import 'fixtures/test_map.dart';
import 'fixtures/test_place_search.dart';
import 'package:wayday/features/places/data/place_search_repository.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/data/location_reader.dart';

const captureKey = Key('capture');
Future<ProviderContainer> launch(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  bool empty = false,
  LocationReader? locate,
  PlaceSearchRepository? places,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await (FontLoader(
    'Figtree',
  )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final container = ProviderContainer(
    overrides: [
      placeMapBuilderProvider.overrideWithValue(testMap),
      placeSearchRepositoryProvider.overrideWithValue(
        places ?? const TestPlaceSearch(),
      ),
      locationReaderProvider.overrideWithValue(
        locate ??
            () async => throw const LocationUnavailable(
              'Location permission is unavailable. Move the map to choose your pin.',
            ),
      ),
      dayRepositoryProvider.overrideWithValue(
        MemoryDayRepository(initial: empty ? newDay() : exampleDay()),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const RepaintBoundary(key: captureKey, child: WaydayApp()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['WAYDAY_CAPTURE'] != '1') return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../.impeccable/review')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return;
  }
  await tester.scrollUntilVisible(
    finder,
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> add(WidgetTester tester, String title) async {
  await tester.enterText(find.byKey(const Key('quick-add')), title);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('notes save, cancel, clear and remain independent when copied', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly essentials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock up on groceries'));
    await tester.pumpAndSettle();
    final notes = find.byKey(const Key('errand-notes'));
    expect(
      tester.widget<TextFormField>(notes).controller!.text,
      'Vegetables\nFruits\nMeat',
    );
    await tester.enterText(notes, 'Unsaved shopping list');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      container.read(recurringProvider).first.items.first.notes,
      'Vegetables\nFruits\nMeat',
    );
    await tester.tap(find.text('Stock up on groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(
      notes,
      'Vegetables\nMangoes\nChicken\nAsk about delivery',
    );
    await capture(tester, 'v3-notes');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to Today').first);
    await tester.pumpAndSettle();
    final copy = container.read(todayProvider).errands[5];
    expect(copy.notes, 'Vegetables\nMangoes\nChicken\nAsk about delivery');
    container
        .read(todayProvider.notifier)
        .update(copy.copyWith(notes: 'Buy rice too'));
    expect(
      container.read(recurringProvider).first.items.first.notes,
      isNot(contains('rice')),
    );
    await tester.tap(find.text('Stock up on groceries'));
    await tester.pumpAndSettle();
    await tester.enterText(notes, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).first.items.first.notes, isEmpty);
    expect(container.read(todayProvider).errands[5].notes, 'Buy rice too');
  });

  testWidgets(
    'rapid additions retain input focus and keep the composer visible',
    (tester) async {
      final container = await launch(tester);
      await reveal(tester, find.text('Add errand'));
      await tester.tap(find.text('Add errand'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('quick-add')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
      for (var i = 0; i < 4; i++) {
        await tester.enterText(
          find.byKey(const Key('quick-add')),
          'Quick errand $i',
        );
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.length, 9);
      final input = tester.widget<TextField>(
        find.byKey(const Key('quick-add')),
      );
      expect(input.focusNode!.hasFocus, isTrue);
      expect(input.controller!.text, isEmpty);
      expect(
        tester.getBottomLeft(find.byKey(const Key('quick-add'))).dy,
        lessThan(700),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list disclosure animates, reverses mid-flight and retains errands',
    (tester) async {
      final container = await launch(tester);
      final disclosure = find.byKey(const Key('today-errands-disclosure'));
      final expanded = tester.getSize(disclosure).height;
      await tester.tap(find.text('Errands'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final intermediate = tester.getSize(disclosure).height;
      expect(intermediate, greaterThan(0));
      expect(intermediate, lessThan(expanded));
      await tester.tap(find.text('Errands'));
      await tester.pumpAndSettle();
      expect(tester.getSize(disclosure).height, closeTo(expanded, 1));
      expect(container.read(todayProvider).errands.length, 5);
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      expect(find.text('Stock up on groceries'), findsNothing);
      await capture(tester, 'v3-collapsed');
      await tester.tap(find.text('Weekly essentials'));
      await tester.pumpAndSettle();
      expect(find.text('Stock up on groceries'), findsOneWidget);
    },
  );

  testWidgets(
    'clear feedback times out and new messages replace old feedback',
    (tester) async {
      final container = await launch(tester);
      await tester.tap(find.byKey(const Key('clear-errands')));
      await tester.pumpAndSettle();
      expect(find.text('Errands cleared.'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await capture(tester, 'v3-feedback');
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();
      expect(find.text('Errands cleared.'), findsNothing);
      expect(container.read(todayProvider).errands, isEmpty);
      final context = tester.element(find.text('Today').first);
      showFeedback(context, 'First message');
      await tester.pumpAndSettle();
      showFeedback(context, 'Latest message');
      await tester.pumpAndSettle();
      expect(find.text('First message'), findsNothing);
      expect(find.text('Latest message'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
    },
  );

  testWidgets('remove animations preference makes disclosure immediate', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    await tester.tap(find.text('Errands'));
    await tester.pump();
    expect(
      tester.getSize(find.byKey(const Key('today-errands-disclosure'))).height,
      0,
    );
    await tester.tap(find.text('Errands'));
    await tester.pump();
    expect(find.text('Capstone presentation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single light theme ignores device dark mode and removes appearance controls',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await launch(tester);
      expect(
        Theme.of(tester.element(find.text('Plan my day'))).brightness,
        Brightness.light,
      );
      await capture(tester, 'v2-today');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsNothing);
      expect(find.text('Display mode'), findsNothing);
      await capture(tester, 'v2-settings');
    },
  );
  testWidgets(
    'consecutive quick additions stay Anytime and survive tab changes',
    (tester) async {
      final container = await launch(tester);
      await reveal(tester, find.text('Add errand'));
      await tester.tap(find.text('Add errand'));
      await tester.pumpAndSettle();
      await add(tester, 'Pick up laundry');
      await add(tester, 'Buy flowers');
      expect(container.read(todayProvider).errands.length, 7);
      expect(
        container.read(todayProvider).errands.last.timing,
        TimingRule.anytime,
      );
      await tester.tap(find.text('Done adding'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.last.title, 'Buy flowers');
    },
  );
  testWidgets('draft cancellation and title editing preserve confirmed rules', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.text('Capstone presentation'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('errand-title')), 'Unsaved');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      container.read(todayProvider).errands[1].title,
      'Capstone presentation',
    );
    await tester.tap(find.text('Capstone presentation'));
    await tester.pumpAndSettle();
    await capture(tester, 'v2-errand-editor');
    await tester.enterText(
      find.byKey(const Key('errand-title')),
      'Capstone pitch',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands[1].minute, 660);
    expect(container.read(todayProvider).errands[1].title, 'Capstone pitch');
  });
  testWidgets(
    'numeric time entry validates fields and correctly represents midnight',
    (tester) async {
      final container = await launch(tester);
      await reveal(tester, find.text('Leave'));
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();
      await capture(tester, 'v2-time');
      expect(find.byType(TimePickerDialog), findsNothing);
      await tester.enterText(find.byKey(const Key('time-hour')), '13');
      await tester.enterText(find.byKey(const Key('time-minute')), '65');
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      expect(find.text('Use 1–12'), findsOneWidget);
      expect(find.text('Use 00–59'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('time-hour')), '12');
      await tester.enterText(find.byKey(const Key('time-minute')), '00');
      await tester.tap(find.text('AM'));
      await tester.tap(find.text('Save time'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).departure, 0);
    },
  );
  testWidgets('home deadline before departure is rejected', (tester) async {
    final container = await launch(tester);
    await reveal(tester, find.text('Home by'));
    await tester.tap(find.text('Home by'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('time-hour')), '6');
    await tester.enterText(find.byKey(const Key('time-minute')), '00');
    await tester.tap(find.text('AM'));
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).deadline, 1080);
    expect(
      find.text('Choose a home-by time after your departure.'),
      findsOneWidget,
    );
  });
  testWidgets('manual map selection edits endpoints and errand places', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.byKey(const Key('from-map')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).from, 'Dropped pin');
    expect(container.read(todayProvider).fromPlace.latitude, 14.58);
    await tester.tap(find.text('Capstone presentation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose on map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('test-map-pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands[1].place, 'Dropped pin');
  });
  testWidgets('all five transportation profiles remain selectable', (
    tester,
  ) async {
    final container = await launch(tester);
    for (final profile in TravelProfile.values) {
      await reveal(tester, find.text('Travel'));
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(profile.label).last);
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).profile, profile);
    }
  });
  testWidgets(
    'copying a recurring group prevents duplicates and preserves independent copies',
    (tester) async {
      final container = await launch(tester);
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      await capture(tester, 'v2-recurring');
      await tester.tap(find.text('Weekly essentials'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to Today').first);
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.length, 8);
      final addedButton = find.widgetWithText(TextButton, 'Added to Today');
      expect(tester.widget<TextButton>(addedButton).onPressed, isNull);
      await tester.tap(find.byTooltip('Edit Weekly essentials'));
      await tester.pumpAndSettle();
      await capture(tester, 'v2-group-editor');
      await tester.tap(find.text('Stock up on groceries'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('errand-title')),
        'Template groceries changed',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save list'));
      await tester.pumpAndSettle();
      expect(
        container.read(recurringProvider).first.items.first.title,
        'Template groceries changed',
      );
      expect(
        container.read(todayProvider).errands[5].title,
        'Stock up on groceries',
      );
      container
          .read(todayProvider.notifier)
          .addGroup(
            groupId: 'weekly',
            errands: container.read(recurringProvider).first.items,
          );
      expect(container.read(todayProvider).errands.length, 8);
    },
  );
  testWidgets('new recurring list supports continuous add and validation', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('New recurring list'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    expect(find.text('Give your list a name.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('group-name')),
      'Weekend errands',
    );
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    expect(find.text('Add at least one errand to this list.'), findsOneWidget);
    await tester.tap(find.text('Add errand'));
    await tester.pumpAndSettle();
    await add(tester, 'Pick up supplies');
    await add(tester, 'Get a haircut');
    await tester.tap(find.text('Done adding'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    final group = container.read(recurringProvider).last;
    expect(group.name, 'Weekend errands');
    expect(group.items.length, 2);
    expect(
      group.items.every((item) => item.timing == TimingRule.anytime),
      isTrue,
    );
  });
  testWidgets('cancelling a group draft does not change its saved items', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Weekly essentials'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('group-name')),
      'Unsaved group',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).first.name, 'Weekly essentials');
  });
  testWidgets(
    'removing from the focused editor offers working undo after pop',
    (tester) async {
      final container = await launch(tester);
      await tester.tap(find.text('Capstone presentation'));
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Remove errand'));
      await tester.tap(find.text('Remove errand'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.length, 4);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).errands.length, 5);
    },
  );
  testWidgets('clear and empty state retain undo and disable planning', (
    tester,
  ) async {
    final container = await launch(tester);
    await tester.tap(find.byKey(const Key('clear-errands')));
    await tester.pumpAndSettle();
    expect(
      find.text('Start with one errand. Add details later.'),
      findsOneWidget,
    );
    await capture(tester, 'v2-empty');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNull,
    );
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands.length, 5);
  });
  testWidgets(
    'small phone and larger text retain usable list and trip controls',
    (tester) async {
      final container = await launch(
        tester,
        size: const Size(320, 800),
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'v2-large-text');
      await reveal(tester, find.text('Travel'));
      await tester.tap(find.text('Travel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biking'));
      await tester.pumpAndSettle();
      expect(container.read(todayProvider).profile, TravelProfile.bike);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('recurring rows open focused editing directly', (tester) async {
    final container = await launch(tester);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekly essentials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock up on groceries'));
    await tester.pumpAndSettle();
    expect(find.text('Edit errand'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('errand-title')),
      'My regular groceries',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      container.read(recurringProvider).first.items.first.title,
      'My regular groceries',
    );
  });
  testWidgets('deleting a recurring list has working undo', (tester) async {
    final container = await launch(tester);
    await tester.tap(find.text('Recurring'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Weekly essentials'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete list'));
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).length, 1);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).length, 2);
  });
  testWidgets('planning opens a manual review and Back preserves Today', (
    tester,
  ) async {
    final container = await launch(tester);
    final before = container.read(todayProvider);
    await tester.tap(find.text('Plan my day'));
    await tester.pumpAndSettle();
    expect(find.text('Review your day'), findsOneWidget);
    expect(
      find.textContaining('Travel times and opening hours'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(container.read(todayProvider), same(before));
  });
}
