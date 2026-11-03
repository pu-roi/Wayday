import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/map_credits_page.dart';
import 'package:wayday/features/maps/presentation/bundled_license_notice.dart';

class NoticeBundle extends CachingAssetBundle {
  int reads = 0;
  Future<String>? response;
  @override
  Future<String> loadString(String key, {bool cache = true}) {
    reads++;
    return response ?? Future.value('Copyright test\n\nComplete notice.');
  }

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();
}

void main() {
  testWidgets(
    'credits group providers and disclose complete readable notices',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(theme: buildTheme(), home: const MapCreditsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Online maps'), findsOneWidget);
      expect(find.textContaining('Offline map'), findsNothing);
      expect(find.textContaining('Redistribution and use'), findsNothing);
      final notice = find.text('Name Suggestion Index · BSD 3-Clause');
      await tester.scrollUntilVisible(notice, 300);
      await tester.pumpAndSettle();
      await tester.tap(notice);
      await tester.pumpAndSettle();
      final text = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .map((widget) => widget.data ?? '')
          .join('\n');
      final source = await rootBundle.loadString(
        'assets/notices/nsi/LICENSE.txt',
      );
      String words(String value) =>
          value.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(words(text), contains(words(source.replaceFirst('## ', ''))));
      expect(text, isNot(contains('##')));
      expect(tester.takeException(), isNull);
    },
  );

  test('both notices retain every substantive word and punctuation', () async {
    for (final asset in [
      'assets/fonts/OFL.txt',
      'assets/notices/nsi/LICENSE.txt',
    ]) {
      final source = File(asset).readAsStringSync();
      final expected = source
          .split('\n')
          .where((line) => !RegExp(r'^-{3,}$').hasMatch(line.trim()))
          .join(' ')
          .replaceAll('## ', '');
      String words(String value) =>
          value.replaceAll(RegExp(r'\s+'), ' ').trim();
      final formatted = formatBundledNotice(source);
      expect(words(formatted), words(expected));
      expect(formatted, isNot(contains('-----')));
      expect(formatted, isNot(contains('## ')));
    }
  });

  testWidgets('notice load survives rebuilds and retry is explicit', (
    tester,
  ) async {
    final pending = Completer<String>();
    final bundle = NoticeBundle()..response = pending.future;
    Widget page(double scale) => DefaultAssetBundle(
      bundle: bundle,
      child: MaterialApp(
        theme: buildTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: BundledLicenseNotice(
              title: 'Test notice',
              asset: 'test-notice',
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(page(1));
    await tester.tap(find.text('Test notice'));
    await tester.pumpAndSettle();
    expect(find.text('Loading license…'), findsOneWidget);
    pending.completeError(StateError('Asset unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('This license could not load.'), findsOneWidget);
    await tester.pumpWidget(page(1.5));
    await tester.pumpAndSettle();
    expect(bundle.reads, 1);
    bundle.response = null;
    await tester.tap(find.text('Retry loading license'));
    await tester.pumpAndSettle();
    expect(find.text('Copyright test\n\nComplete notice.'), findsOneWidget);
    expect(bundle.reads, 2);
    await tester.tap(find.text('Test notice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test notice'));
    await tester.pumpAndSettle();
    expect(bundle.reads, 2);
  });

  testWidgets('provider links open their source and explain browser failure', (
    tester,
  ) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final urls = <String>[];
    var succeeds = true;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'launch') {
        urls.add((call.arguments as Map)['url'] as String);
        return succeeds;
      }
      return false;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const MapCreditsPage()),
    );
    await tester.tap(find.text('© OpenStreetMap contributors'));
    await tester.pumpAndSettle();
    expect(urls, ['https://www.openstreetmap.org/copyright']);
    succeeds = false;
    await tester.tap(find.text('© OpenStreetMap contributors'));
    await tester.pumpAndSettle();
    expect(find.text('This link could not open. Try again.'), findsOneWidget);
  });
}
