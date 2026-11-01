import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/errands/presentation/errand_editor.dart';

void main() {
  testWidgets('details reverses motion and retains the duration draft', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const ErrandEditor(
            errand: Errand(id: 'a', title: 'Errand'),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('More details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    final arrow = find.byKey(const Key('errand-details-arrow'));
    final header = find.ancestor(
      of: find.text('More details'),
      matching: find.byType(ListTile),
    );
    expect(
      tester
          .getSemantics(header)
          .getSemanticsData()
          .flagsCollection
          .isExpanded
          .toBoolOrNull(),
      isFalse,
    );
    await tester.tap(find.text('More details'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(tester.widget<AnimatedRotation>(arrow).turns, .5);
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedRotation>(arrow).turns, 0);
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(header)
          .getSemanticsData()
          .flagsCollection
          .isExpanded
          .toBoolOrNull(),
      isTrue,
    );
    await tester.ensureVisible(find.byKey(const Key('errand-duration')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('errand-duration')), '27');
    await tester.ensureVisible(find.text('More details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('errand-duration')), findsNothing);
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('errand-duration')))
          .controller!
          .text,
      '27',
    );
    semantics.dispose();
  });

  testWidgets('details respects reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: const ErrandEditor(
            errand: Errand(id: 'a', title: 'Errand'),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('More details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pump();
    expect(
      tester
          .widget<AnimatedRotation>(
            find.byKey(const Key('errand-details-arrow')),
          )
          .duration,
      Duration.zero,
    );
    expect(find.byKey(const Key('errand-duration')), findsOneWidget);
  });

  testWidgets('details fits a small screen with larger text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const ErrandEditor(
            errand: Errand(id: 'a', title: 'Errand'),
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('More details'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.text('After another errand'), findsOneWidget);
    final viewport = tester.getRect(find.byType(Scrollable).first);
    final lastRow = tester.getRect(
      find.ancestor(
        of: find.text('After another errand'),
        matching: find.byType(ListTile),
      ),
    );
    expect(lastRow.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(
      tester.getTopLeft(find.byKey(const Key('errand-duration'))).dy,
      greaterThanOrEqualTo(viewport.top),
    );
    expect(tester.takeException(), isNull);
  });
}
