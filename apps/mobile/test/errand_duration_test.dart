import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';

void main() {
  testWidgets('visit duration is editable and saved as a confirmed value', (
    tester,
  ) async {
    ErrandEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result = await editErrand(
                context,
                const Errand(id: 'a', title: 'Buy'),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('errand-duration')));
    await tester.enterText(find.byKey(const Key('errand-duration')), '30');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((result as SavedErrand).errand.durationMinutes, 30);
    expect((result as SavedErrand).errand.durationConfirmed, isTrue);
  });
}
