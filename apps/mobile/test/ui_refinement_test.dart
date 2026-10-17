import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/profile/presentation/profile_view.dart';
import 'package:wayday/features/recurring/presentation/recurring_view.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/core/widgets/section_surface.dart';

import 'today_test.dart' as helper;

Finder tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  testWidgets(
    'fresh Today has a compact left-aligned prompt and no demo controls',
    (tester) async {
      final container = await helper.launch(tester, empty: true);
      expect(container.read(todayProvider).errands, isEmpty);
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.byKey(const Key('clear-errands')), findsNothing);
      final prompt = find.byKey(const Key('today-empty-prompt'));
      expect(
        tester.getTopLeft(prompt).dx,
        tester.getTopLeft(find.byType(SectionSurface).first).dx + 20,
      );
      expect(tester.widget<Text>(prompt).style!.fontSize, 14);
      expect(find.text('What’s on your way today?'), findsNothing);
      await helper.capture(tester, 'v5-today-empty');
      await tester.tap(tab('Settings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('example'), findsNothing);
      expect(find.text('Asia/Manila'), findsOneWidget);
      await helper.capture(tester, 'v5-settings');
    },
  );

  testWidgets('clear has a visible action and Undo restores the exact day', (
    tester,
  ) async {
    final container = await helper.launch(tester);
    final before = container.read(todayProvider);
    await tester.tap(find.byKey(const Key('clear-errands')));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(
      container.read(todayProvider).errands.map((e) => e.id),
      before.errands.map((e) => e.id),
    );
    await helper.capture(tester, 'v5-today-populated');
  });

  testWidgets('Today to Recurring animates within the stationary app shell', (
    tester,
  ) async {
    final container = await helper.launch(tester, empty: true);
    final before = tester.getTopLeft(find.byType(NavigationBar));
    await helper.reveal(tester, find.text('Add from a recurring list'));
    await tester.tap(find.text('Add from a recurring list'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/recurring',
    );
    expect(find.byType(RecurringView), findsOneWidget);
    final fades = tester.widgetList<FadeTransition>(
      find.byKey(const Key('module-transition')),
    );
    expect(
      fades.any((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    expect(tester.getTopLeft(find.byType(NavigationBar)), before);
    await tester.pumpAndSettle();
    await helper.capture(tester, 'v5-recurring');
    await tester.tap(tab('Today'));
    await tester.pumpAndSettle();
    expect(container.read(todayProvider).errands, isEmpty);
  });

  testWidgets('module transitions respect Remove animations', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await helper.launch(tester, empty: true);
    await tester.tap(tab('Recurring'));
    await tester.pumpAndSettle();
    expect(find.byType(RecurringView), findsOneWidget);
    expect(find.byKey(const Key('module-transition')), findsNothing);
  });

  testWidgets(
    'Profile identifies the local sample without invented contact details',
    (tester) async {
      await helper.launch(tester, size: const Size(375, 812), scale: 1.3);
      await tester.tap(tab('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.text('Jace Bellen'), findsOneWidget);
      expect(find.text('Sample profile'), findsOneWidget);
      expect(find.text('Not added'), findsNWidgets(3));
      expect(find.text('Edit profile'), findsNothing);
      expect(find.textContaining('nothing is shared'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await helper.capture(tester, 'v5-profile-large-text');
    },
  );

  testWidgets(
    'Profile scrolls in landscape and uses the rail on wide layouts',
    (tester) async {
      await helper.launch(tester, size: const Size(844, 390));
      expect(find.byType(NavigationRail), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await helper.reveal(tester, find.text('When you share a trip'));
      expect(find.text('When you share a trip'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await helper.capture(tester, 'v5-profile-landscape');
    },
  );
}
