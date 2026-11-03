import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';

const _original = Errand(id: 'a', title: 'Grocery');
const _other = Errand(id: 'b', title: 'Collect a parcel');
const _suggestion = ErrandNeed(
  id: 'a',
  query: 'grocery store',
  timing: 'at',
  minute: 600,
  optional: true,
  after: ['b'],
);

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _dependencies(WidgetTester tester) async {
  await _show(tester, find.text('More details'));
  await tester.tap(find.text('More details'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('After another errand'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('After another errand'));
  await tester.pumpAndSettle();
}

Future<Errand> _saveAfter(
  WidgetTester tester,
  Future<void> Function() interact, {
  Errand original = _original,
}) async {
  ErrandEditResult? result;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await editErrand(
                context,
                original,
                errands: [original, _other],
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  await interact();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
  expect(result, isA<SavedErrand>());
  return (result as SavedErrand).errand;
}

Future<void> _duration(WidgetTester tester) async {
  await _show(tester, find.text('More details'));
  await tester.tap(find.text('More details'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const Key('errand-duration')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'explicit Anytime confirmation survives applying other model suggestions',
    (tester) async {
      final saved = await _saveAfter(tester, () async {
        await _show(tester, find.text('When'));
        await tester.tap(find.text('When'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      });
      final applied = _suggestion.apply(saved);
      expect(applied.timing, TimingRule.anytime);
      expect(applied.minute, isNull);
      expect(saved.confirmedFields, contains('timing'));
    },
  );

  testWidgets(
    'switching optional on and back off explicitly keeps this errand required',
    (tester) async {
      final saved = await _saveAfter(tester, () async {
        await _show(tester, find.byType(SwitchListTile));
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
      });
      expect(saved.optional, isFalse);
      expect(_suggestion.apply(saved).optional, isFalse);
      expect(saved.confirmedFields, contains('optional'));
    },
  );

  testWidgets(
    'confirming no prerequisites survives applying other model suggestions',
    (tester) async {
      final saved = await _saveAfter(tester, () async {
        await _dependencies(tester);
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      });
      expect(saved.afterErrandIds, isEmpty);
      expect(_suggestion.apply(saved).afterErrandIds, isEmpty);
      expect(saved.confirmedFields, contains('dependencies'));
    },
  );

  testWidgets('cancelling When leaves timing unconfirmed and unchanged', (
    tester,
  ) async {
    final saved = await _saveAfter(tester, () async {
      await _show(tester, find.text('When'));
      await tester.tap(find.text('When'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrive by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
    expect(saved.timing, TimingRule.anytime);
    expect(saved.minute, isNull);
    expect(saved.confirmedFields, isNot(contains('timing')));
    expect(_suggestion.apply(saved).timing, TimingRule.at);
  });

  testWidgets('dismissing the clock does not confirm a new timing rule', (
    tester,
  ) async {
    final saved = await _saveAfter(tester, () async {
      await _show(tester, find.text('When'));
      await tester.tap(find.text('When'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Arrive by'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    });
    expect(saved.timing, TimingRule.anytime);
    expect(saved.minute, isNull);
    expect(saved.confirmedFields, isNot(contains('timing')));
  });

  testWidgets('cancelling dependencies discards the temporary selection', (
    tester,
  ) async {
    final saved = await _saveAfter(tester, () async {
      await _dependencies(tester);
      await tester.tap(find.text(_other.title));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
    expect(saved.afterErrandIds, isEmpty);
    expect(saved.confirmedFields, isNot(contains('dependencies')));
    expect(_suggestion.apply(saved).afterErrandIds, ['b']);
  });

  testWidgets('saving an untouched editor does not confirm default values', (
    tester,
  ) async {
    final saved = await _saveAfter(tester, () async {});
    expect(saved.confirmedFields, isEmpty);
    expect(saved.durationConfirmed, isFalse);
    final applied = _suggestion.apply(saved);
    expect(applied.timing, TimingRule.at);
    expect(applied.optional, isTrue);
    expect(applied.afterErrandIds, ['b']);
  });

  for (final value in ['', '0', '-1', '1.5', 'abc', '1441']) {
    for (final collapsed in [false, true]) {
      testWidgets(
        'rejects duration "$value" with details ${collapsed ? 'collapsed' : 'open'}',
        (tester) async {
          final saved = await _saveAfter(tester, () async {
            await _duration(tester);
            await tester.enterText(
              find.byKey(const Key('errand-duration')),
              value,
            );
            if (collapsed) {
              await tester.ensureVisible(find.text('More details'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('More details'));
              await tester.pumpAndSettle();
              expect(find.byKey(const Key('errand-duration')), findsNothing);
            }
            await tester.tap(find.text('Save'));
            await tester.pumpAndSettle();
            expect(find.text('Edit errand'), findsOneWidget);
            expect(find.byKey(const Key('errand-duration')), findsOneWidget);
            expect(
              find.text('Enter between 1 and 1,440 minutes.'),
              findsOneWidget,
            );
            await tester.ensureVisible(
              find.byKey(const Key('errand-duration')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('errand-duration')),
              '30',
            );
          });
          expect(saved.durationMinutes, 30);
          expect(saved.durationConfirmed, isTrue);
        },
      );
    }
  }

  for (final minutes in [1, 15, 1440]) {
    testWidgets('accepts and confirms duration $minutes', (tester) async {
      final saved = await _saveAfter(tester, () async {
        await _duration(tester);
        if (minutes == 15) {
          await tester.enterText(find.byKey(const Key('errand-duration')), '');
        }
        await tester.enterText(
          find.byKey(const Key('errand-duration')),
          '$minutes',
        );
      });
      expect(saved.durationMinutes, minutes);
      expect(saved.durationConfirmed, isTrue);
      expect(saved.confirmedFields, contains('duration'));
      expect(
        const ErrandNeed(
          id: 'a',
          query: 'grocery',
          durationMinutes: 99,
        ).apply(saved).durationMinutes,
        minutes,
      );
    });
  }

  testWidgets('changing a timed errand to Anytime clears its saved clock', (
    tester,
  ) async {
    final saved = await _saveAfter(
      tester,
      () async {
        await _show(tester, find.text('When'));
        await tester.tap(find.text('When'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anytime'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('errand-time')), findsNothing);
      },
      original: const Errand(
        id: 'a',
        title: 'Grocery',
        timing: TimingRule.at,
        minute: 600,
      ),
    );
    expect(saved.timing, TimingRule.anytime);
    expect(saved.minute, isNull);
    expect(saved.confirmedFields, contains('timing'));
    expect(_suggestion.apply(saved).timing, TimingRule.anytime);
    expect(_suggestion.apply(saved).minute, isNull);
  });
}
