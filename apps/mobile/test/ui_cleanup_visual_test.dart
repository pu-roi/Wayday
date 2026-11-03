import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/settings_view.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/app/wayday_app.dart';
import 'package:wayday/features/recurring/presentation/recurring_view.dart';

const preview = Key('ui-cleanup-preview');

/// Keep layout checks independent from fake-clock asset-channel timing while
/// rendering the real bundled notices. Async loading/retry has separate tests.
class _NoticeAssets extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) {
    if (key == 'assets/notices/nsi/LICENSE.txt' ||
        key == 'assets/fonts/OFL.txt') {
      return SynchronousFuture(File(key).readAsStringSync());
    }
    return rootBundle.loadString(key, cache: cache);
  }
}

void main() {
  for (final layout in [
    (name: 'narrow', size: const Size(320, 740), scale: 1.0),
    (name: 'phone', size: const Size(390, 844), scale: 1.0),
    (name: 'tablet', size: const Size(1024, 900), scale: 1.0),
    (name: 'large-text', size: const Size(390, 844), scale: 2.0),
    (name: 'landscape', size: const Size(844, 390), scale: 1.0),
  ]) {
    testWidgets('cleanup screens reflow at ${layout.name}', (tester) async {
      tester.view.physicalSize = layout.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        await (FontLoader(
          'Figtree',
        )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      Future<void> capture(String name) async {
        expect(tester.takeException(), isNull);
        if (Platform.environment['WAYDAY_CAPTURE'] != '1') return;
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(preview),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('../../.impeccable/review/ui-cleanup')
            ..createSync(recursive: true);
          File(
            '${directory.path}/${layout.name}-$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      Future<void> mount(String location, Widget page) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            child: RepaintBoundary(
              key: preview,
              child: MaterialApp(
                theme: buildTheme(),
                debugShowCheckedModeBanner: false,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(layout.scale)),
                  child: child!,
                ),
                home: AppShell(
                  location: location,
                  child: DefaultAssetBundle(
                    bundle: _NoticeAssets(),
                    child: Navigator(
                      onGenerateRoute: (_) =>
                          MaterialPageRoute<void>(builder: (_) => page),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await mount('/recurring', const RecurringView());
      await capture('errands');
      await tester.tap(find.text('Trips'));
      await tester.pumpAndSettle();
      await capture('trips');
      await mount('/settings', const SettingsView());
      await capture('settings');
      await tester.scrollUntilVisible(
        find.text('Map credits and licenses'),
        180,
      );
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
      await tester.drag(find.byType(ListView).last, const Offset(0, -160));
      await tester.pumpAndSettle();
      await capture('license');
    });
  }
}
