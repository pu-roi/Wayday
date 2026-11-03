import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:wayday/features/sharing/share_models.dart';
import 'package:wayday/features/sharing/share_repository.dart';
import 'package:wayday/features/sharing/share_views.dart';
import 'share_repository_test.dart' show snapshot, sharedResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharingChannel, (call) async {
          calls.add(call.method);
          return switch (call.method) {
            'readStorage' => '{}',
            'broadcastStatus' => {'active': false, 'revocationPending': false},
            _ => null,
          };
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(sharingChannel, null);
  });

  for (final (width, scale) in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('sharing preview stays readable at $width / $scale', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var writes = 0;
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          client: MockClient((_) async {
            writes++;
            return http.Response('{}', 500);
          }),
        ),
        readStorage: () async => '{}',
        writeStorage: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => ShareManagementSheet(
                      snapshot: snapshot(),
                      access: null,
                      repository: repo,
                    ),
                  ),
                  child: const Text('Open sharing'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open sharing'));
      await tester.pumpAndSettle();
      expect(find.text('Share trip'), findsOneWidget);
      expect(find.textContaining('Live location is off'), findsOneWidget);
      await tester.ensureVisible(find.text('Create share link'));
      expect(find.text('Create share link'), findsOneWidget);
      expect(writes, 0);
      expect(calls, isNot(contains('startBroadcast')));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'recipient view cannot modify progress or start broadcasting automatically',
    (tester) async {
      final repo = ShareRepository(
        now: () => DateTime.fromMillisecondsSinceEpoch(1793707200 * 1000),
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          client: MockClient((request) async {
            expect(request.method, 'GET');
            return http.Response(jsonEncode(sharedResponse()), 200);
          }),
        ),
        readStorage: () async => '{}',
        writeStorage: (_) async {},
        nativeStatus: () async => {'active': false},
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: SharedTripPage(
            access: ShareAccess(
              id: ShareRepository.operationId(),
              token: ShareRepository.credential(),
              role: 'viewer',
            ),
            repository: repo,
          ),
        ),
      );
      // The HTTP stream completes in a real async turn; freshness uses the
      // widget's controlled clock and does not need a real network request.
      await tester.runAsync(() async => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Buy groceries'), 250);
      expect(find.text('Buy groceries'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
      expect(find.text('Share my live location'), findsNothing);
      expect(calls, isNot(contains('startBroadcast')));
      await tester.pumpWidget(const SizedBox());
    },
  );
}
