import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/sharing/share_models.dart';
import 'package:wayday/features/sharing/share_repository.dart';
import 'trip_view_test.dart' show mountTrip;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sources = <String?>[];
  setUp(() {
    sources.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharingChannel, (call) async {
          if (call.method == 'navigationSource') {
            sources.add((call.arguments as Map)['source'] as String?);
          }
          return switch (call.method) {
            'readStorage' => '{}',
            'broadcastStatus' => {'active': false},
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharingChannel, null);
  });
  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
      'Your trip keeps Share, Whole trip and Done accessible at $width / $scale',
      (tester) async {
        await mountTrip(tester, size: Size(width, 844), textScale: scale);
        if (sharingEnabled) {
          expect(sources.take(2), ['handoff', 'google']);
        }
        expect(
          find.byTooltip('Share trip'),
          sharingEnabled ? findsOneWidget : findsNothing,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                (widget is Tooltip && widget.message == 'Whole trip') ||
                (widget is Text && widget.data == 'Whole trip'),
          ),
          findsOneWidget,
        );
        expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
        if (sharingEnabled) {
          await tester.tap(find.byTooltip('Share trip'));
          await tester.pumpAndSettle();
          expect(find.text('Share trip'), findsOneWidget);
          expect(
            find.textContaining('original planned route is unavailable'),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
