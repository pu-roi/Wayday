import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/maps/presentation/map_platform.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('isolated native recurring, settings and credits cleanup', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [mapPlatformSupportedProvider.overrideWithValue(false)],
    );
    addTearDown(container.dispose);
    container.read(routerProvider).go('/recurring');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const WaydayApp()),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      final folder = Directory('${Directory.systemTemp.path}/ui-cleanup-native')
        ..createSync();
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(await binding.takeScreenshot(name));
    }

    expect(find.text('No recurring lists yet.'), findsOneWidget);
    await capture('errands');
    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('No saved trips yet.'), findsOneWidget);
    await capture('trips');
    final bar = find.byType(NavigationBar);
    await tester.tap(find.descendant(of: bar, matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings are not available yet.'), findsOneWidget);
    expect(find.text('Offline Pasig/Ortigas preview'), findsNothing);
    await capture('settings');
    await tester.scrollUntilVisible(find.text('Map credits and licenses'), 180);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Map credits and licenses'));
    await tester.pumpAndSettle();
    await capture('credits');
    final notice = find.text('Name Suggestion Index · BSD 3-Clause');
    await tester.scrollUntilVisible(
      notice,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(notice);
    await tester.pumpAndSettle();
    expect(find.textContaining('Redistribution and use'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -180));
    await tester.pumpAndSettle();
    await capture('license');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: bar, matching: find.text('Recurring')),
    );
    await tester.pumpAndSettle();
    expect(find.text('No saved trips yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
