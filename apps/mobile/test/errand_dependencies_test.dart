import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';

void main() {
  testWidgets(
    'dependencies are draft choices, preserve missing references, and prevent cycles',
    (tester) async {
      const current = Errand(
        id: 'a',
        title: 'Submit',
        afterErrandIds: ['missing'],
        timing: TimingRule.arriveBy,
        minute: 600,
      );
      const first = Errand(id: 'b', title: 'Collect');
      const second = Errand(id: 'c', title: 'Photocopy');
      const cyclic = Errand(
        id: 'd',
        title: 'Depends on submit',
        afterErrandIds: ['a'],
      );
      ErrandEditResult? saved;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => saved = await editErrand(
                    context,
                    current,
                    errands: [current, first, second, cyclic],
                  ),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('More details'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Errand no longer available'), findsOneWidget);
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('After another errand'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('After another errand'));
      await tester.pumpAndSettle();
      expect(find.text('Would create a circular dependency'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.tap(find.text('Photocopy'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        (saved as SavedErrand).errand.afterErrandIds,
        containsAll(['missing', 'b', 'c']),
      );
      expect((saved as SavedErrand).errand.timing, TimingRule.arriveBy);
      expect((saved as SavedErrand).errand.minute, 600);
    },
  );
}
