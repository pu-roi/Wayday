import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/widgets/build_identity.dart';

void main() {
  testWidgets(
    'About identifies the installed package without provider requests',
    (tester) async {
      var calls = 0;
      const channel = MethodChannel('wayday/gateway');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'buildInfo');
            calls++;
            return {
              'channel': 'Wayday Test',
              'version': '0.1.0',
              'versionCode': '102801',
            };
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BuildIdentity())),
      );
      await tester.pump();
      expect(
        find.textContaining('Wayday Test · 0.1.0 (102801)'),
        findsOneWidget,
      );
      await tester.pump();
      expect(calls, 1);
    },
  );
}
