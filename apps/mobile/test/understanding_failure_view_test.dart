import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/understanding_failure_view.dart';

void main() {
  for (final variant in [
    (390.0, 1.0),
    (320.0, 2.0),
    (768.0, 1.0),
    (1024.0, 1.0),
    (1440.0, 1.0),
  ]) {
    testWidgets(
      'understanding failure actions at ${variant.$1} scale ${variant.$2}',
      (tester) async {
        tester.view.physicalSize = Size(variant.$1, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = variant.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await (FontLoader(
            'Figtree',
          )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        var saved = 0, retries = 0;
        const boundary = Key('failure-preview');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              theme: buildTheme(),
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                appBar: AppBar(title: const Text('Plan my day')),
                body: UnderstandingFailureView(
                  failure: const PlanningFailure(
                    'Provider limited',
                    kind: 'quota',
                  ),
                  onSaved: () {
                    saved++;
                  },
                  onRetry: () {
                    retries++;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final filled = find.byType(FilledButton),
            outlined = find.byType(OutlinedButton);
      expect(find.text('Gemini is temporarily limited'), findsOneWidget);
        await tester.scrollUntilVisible(filled, 160);
        await tester.scrollUntilVisible(outlined, 120);
        await tester.ensureVisible(filled);
        final primary = tester.getRect(filled),
            secondary = tester.getRect(outlined);
        expect(primary.width, secondary.width);
        expect(primary.width, lessThanOrEqualTo(520));
        expect(primary.height, greaterThanOrEqualTo(56));
        expect(secondary.height, greaterThanOrEqualTo(56));
        if (variant.$2 == 1) expect(primary.height, secondary.height);
        final context = tester.element(filled), theme = Theme.of(context);
        expect(
          (theme.filledButtonTheme.style!.shape!.resolve({})
                  as RoundedRectangleBorder)
              .borderRadius,
          (theme.outlinedButtonTheme.style!.shape!.resolve({})
                  as RoundedRectangleBorder)
              .borderRadius,
        );
        expect(
          theme.outlinedButtonTheme.style!.foregroundColor!.resolve({}),
          theme.colorScheme.secondary,
        );
        await tester.tap(filled);
        expect(saved, 1);
        expect(retries, 0);
        await tester.ensureVisible(outlined);
        await tester.tap(outlined);
        expect(retries, 1);
        expect(tester.takeException(), isNull);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final render = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(boundary),
            );
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('../../.impeccable/review')
              ..createSync(recursive: true);
            File(
              '${dir.path}/understanding-actions-${variant.$1.toInt()}-${variant.$2}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
  testWidgets('both actions are reachable with the keyboard', (tester) async {
    var saved = 0, retry = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: UnderstandingFailureView(
            onSaved: () {
              saved++;
            },
            onRetry: () {
              retry++;
            },
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(saved, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(retry, 1);
  });
}
