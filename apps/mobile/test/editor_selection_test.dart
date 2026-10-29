import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';
import 'package:wayday/features/recurring/data/group_repository.dart';
import 'package:wayday/features/recurring/domain/errand_group.dart';
import 'package:wayday/features/recurring/presentation/group_editor.dart';
import 'package:wayday/features/recurring/presentation/recurring_controller.dart';

const _errand = Errand(
  id: 'selection-item',
  title: 'My errand',
  notes: 'Keep these notes',
  timing: TimingRule.at,
  minute: 600,
  optional: true,
);

class _TestGroupRepository implements GroupRepository {
  _TestGroupRepository(this.groups);
  List<ErrandGroup> groups;
  @override
  List<ErrandGroup> read() => groups;
  @override
  Future<void> save(List<ErrandGroup> groups) async => this.groups = groups;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<List<ErrandEditResult?>> _openErrand(WidgetTester tester) async {
  final results = <ErrandEditResult?>[];
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  results.add(await editErrand(context, _errand)),
              child: const Text('Open errand'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open errand'));
  await tester.pumpAndSettle();
  return results;
}

Future<ProviderContainer> _openGroup(
  WidgetTester tester, {
  RepeatPattern repeat = RepeatPattern.weekly,
  int day = 2,
  int itemCount = 1,
}) async {
  final group = ErrandGroup(
    id: 'selection-group',
    name: 'My recurring list',
    items: [
      _errand,
      for (var index = 1; index < itemCount; index++)
        Errand(id: 'extra-$index', title: 'Additional errand $index'),
    ],
    repeat: repeat,
    day: day,
  );
  final container = ProviderContainer(
    overrides: [
      groupRepositoryProvider.overrideWithValue(_TestGroupRepository([group])),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => GroupEditor(group: group)),
              ),
              child: const Text('Open list'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open list'));
  await tester.pumpAndSettle();
  await _tap(tester, find.text('Repeat'));
  return container;
}

Finder _sheetText(String label) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label));

void main() {
  testWidgets('timing radio choices preserve time and other draft details', (
    tester,
  ) async {
    final results = await _openErrand(tester);
    expect(find.byType(DropdownButtonFormField<TimingRule>), findsNothing);
    for (final rule in TimingRule.values) {
      await _tap(tester, find.text(rule.label));
      final row = find.ancestor(
        of: find.text(rule.label),
        matching: find.byType(RadioListTile<TimingRule>),
      );
      expect(tester.widget<RadioListTile<TimingRule>>(row).selected, isTrue);
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = (results.single as SavedErrand).errand;
    expect(saved.timing, TimingRule.finishBefore);
    expect(saved.minute, 600);
    expect(saved.optional, isTrue);
    expect(saved.notes, _errand.notes);
  });

  testWidgets('Anytime clears time only on Save and Back discards changes', (
    tester,
  ) async {
    final results = await _openErrand(tester);
    await _tap(tester, find.text('Anytime'));
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(results.single, isNull);
    expect(_errand.minute, 600);
    await tester.tap(find.text('Open errand'));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('Anytime'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((results.last as SavedErrand).errand.minute, isNull);
  });

  testWidgets('weekday sheet changes only the group draft until Save list', (
    tester,
  ) async {
    final container = await _openGroup(tester);
    await tester.enterText(find.byKey(const Key('group-name')), 'Draft name');
    await _tap(tester, find.byKey(const Key('repeat-weekday')));
    await tester.tap(_sheetText('Friday'));
    await tester.tap(_sheetText('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Tuesday'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('repeat-weekday')));
    await tester.tap(_sheetText('Sunday'));
    await tester.tap(_sheetText('Done'));
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).single.day, 2);
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    final saved = container.read(recurringProvider).single;
    expect(saved.day, 7);
    expect(saved.name, 'Draft name');
    expect(saved.items.single.notes, _errand.notes);
  });

  testWidgets('all repeat choices stay metadata and group Back cancels edits', (
    tester,
  ) async {
    final container = await _openGroup(tester);
    expect(find.byType(DropdownButtonFormField<RepeatPattern>), findsNothing);
    for (final pattern in RepeatPattern.values) {
      await _tap(tester, find.text(pattern.label));
      expect(
        find.textContaining('It won’t be added automatically.'),
        findsOneWidget,
      );
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      container.read(recurringProvider).single.repeat,
      RepeatPattern.weekly,
    );
    expect(container.read(recurringProvider).single.day, 2);
  });

  testWidgets('monthly day rejects invalid input and accepts both boundaries', (
    tester,
  ) async {
    final container = await _openGroup(tester, repeat: RepeatPattern.monthly);
    final field = find.byKey(const Key('repeat-month-day'));
    for (final value in ['', '0', '32']) {
      await tester.enterText(field, value);
      await tester.tap(find.text('Save list'));
      await tester.pumpAndSettle();
      expect(find.text('Use a day from 1 to 31.'), findsOneWidget);
      expect(container.read(recurringProvider).single.day, 2);
    }
    await tester.enterText(field, '1');
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    expect(container.read(recurringProvider).single.day, 1);
    await _openGroup(tester, repeat: RepeatPattern.monthly);
    await tester.enterText(field, '31');
    await tester.tap(find.text('Save list'));
    await tester.pumpAndSettle();
    final current = ProviderScope.containerOf(
      tester.element(find.text('Open list')),
    );
    expect(current.read(recurringProvider).single.day, 31);
  });

  testWidgets(
    'invalid monthly day expands a collapsed Repeat section on Save',
    (tester) async {
      final container = await _openGroup(tester, repeat: RepeatPattern.monthly);
      final field = find.byKey(const Key('repeat-month-day'));
      await tester.enterText(field, '0');
      await _tap(tester, find.text('Repeat'));
      await tester.tap(find.text('Save list'));
      await tester.pumpAndSettle();
      expect(find.text('Use a day from 1 to 31.'), findsOneWidget);
      expect(tester.getSize(field).height, greaterThan(0));
      final input = tester.widget<TextField>(
        find.descendant(of: field, matching: find.byType(TextField)),
      );
      expect(input.focusNode!.hasFocus, isTrue);
      expect(container.read(recurringProvider).single.day, 2);
    },
  );

  testWidgets(
    'offscreen monthly text is validated after its field is disposed',
    (tester) async {
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final invalid in ['', '32']) {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: invalid == '32');
        final container = await _openGroup(
          tester,
          repeat: RepeatPattern.monthly,
          itemCount: 40,
        );
        final field = find.byKey(const Key('repeat-month-day'));
        await tester.enterText(field, invalid);
        await _tap(tester, find.text('Repeat'));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();
        expect(field, findsNothing);
        await tester.tap(find.text('Save list'));
        await tester.pumpAndSettle();
        expect(find.text('Use a day from 1 to 31.'), findsOneWidget);
        expect(container.read(recurringProvider).single.day, 2);
        final input = tester.widget<TextField>(
          find.descendant(of: field, matching: find.byType(TextField)),
        );
        expect(input.focusNode!.hasFocus, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'repeat changes normalize monthly days and discard invalid text',
    (tester) async {
      final container = await _openGroup(
        tester,
        repeat: RepeatPattern.monthly,
        day: 31,
      );
      await _tap(tester, find.text('Weekly'));
      expect(find.text('Saturday'), findsOneWidget);
      await _tap(tester, find.text('Monthly'));
      final field = find.byKey(const Key('repeat-month-day'));
      expect(tester.widget<TextFormField>(field).controller!.text, '6');
      await tester.enterText(field, '0');
      await _tap(tester, find.text('Every 2 weeks'));
      await _tap(tester, find.text('Monthly'));
      expect(tester.widget<TextFormField>(field).controller!.text, '6');
      await tester.tap(find.text('Save list'));
      await tester.pumpAndSettle();
      expect(container.read(recurringProvider).single.day, 6);
    },
  );

  testWidgets(
    'editor selections remain usable on a small phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _openGroup(tester);
      for (var count = 0; count < 3; count++) {
        await _tap(tester, find.byKey(const Key('repeat-weekday')));
        await tester.ensureVisible(_sheetText('Sunday'));
        await tester.tap(_sheetText('Sunday'));
        await tester.ensureVisible(_sheetText('Done'));
        await tester.tap(_sheetText('Done'));
        await tester.pumpAndSettle();
      }
      await _tap(tester, find.text('Monthly'));
      await tester.enterText(find.byKey(const Key('repeat-month-day')), '15');
      await _tap(tester, find.text('Weekly'));
      expect(tester.takeException(), isNull);
    },
  );
}
