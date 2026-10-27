import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated Android app opens and can add an errand', (
    tester,
  ) async {
    await app.main();
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (find.text('Add errand').evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Add errand'), findsOneWidget);
    await tester.tap(find.text('Add errand'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('quick-add')),
      'Isolated test errand',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Isolated test errand'), findsOneWidget);
  });
}
