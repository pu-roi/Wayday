import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/review_feedback.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('past departure is actionable warning at text $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var dates = 0, departures = 0;
      final theme = buildTheme();
      final background = Color.alphaBlend(
        theme.colorScheme.errorContainer.withValues(alpha: .35),
        WaydayColors.canvas,
      );
      final contrast =
          (background.computeLuminance() + .05) /
          (theme.colorScheme.error.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5));
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: const Key('warning-capture'),
            child: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 740),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: ReviewFeedback(
                    day: fixture().copyWith(date: '2020-01-01'),
                    onDate: () => dates++,
                    onDeparture: () => departures++,
                    onRetrySave: () {},
                    onIssue: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final notice = find.text('Departure has passed: 2020-01-01, 8:30 AM.');
      expect(notice, findsOneWidget);
      expect(tester.widget<Text>(notice).style?.color, theme.colorScheme.error);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('warning-capture')),
              )
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../.tools/ui-refinement')
            ..createSync(recursive: true);
          File(
            '${dir.path}/departure-warning-$scale.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.ensureVisible(find.text('Change date'));
      await tester.tap(find.text('Change date'));
      await tester.ensureVisible(find.text('Change departure'));
      await tester.tap(find.text('Change departure'));
      expect(dates, 1);
      expect(departures, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
