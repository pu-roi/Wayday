import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/trip_provider_sheet.dart';
import 'trip_navigation_test.dart';
import 'trip_session_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'provider sheet retains the existing style and scrolls at 320 / $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final model = tripSession(FakeNavigationDriver());
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(
                key: const ValueKey('provider-capture'),
                child: child!,
              ),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showTripProviders(
                    context,
                    model,
                    alternativeEnabled: false,
                  ),
                  child: const Text('Options'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Options'));
        await tester.pumpAndSettle();
        expect(find.text('Google'), findsOneWidget);
        expect(find.text('OpenStreetMap'), findsOneWidget);
        expect(
          find.textContaining('not available in this build'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('provider-capture')),
            );
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(
              '../../.tools/navigation-core-reference',
            ).create(recursive: true);
            await File(
              '../../.tools/navigation-core-reference/provider-sheet-$scale.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('Map & navigation'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
