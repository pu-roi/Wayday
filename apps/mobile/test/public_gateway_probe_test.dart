import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:wayday/core/network/public_gateway_probe.dart';
import 'package:wayday/main_public_test.dart';

void main() {
  testWidgets(
    'connection checks require a tap and prevent concurrent requests',
    (tester) async {
      var calls = 0;
      final pending = Completer<GatewayProbeResult>();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicGatewayTestScreen(
            check: () {
              calls++;
              return pending.future;
            },
          ),
        ),
      );
      expect(calls, 0);
      await tester.tap(find.text('Check connection'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.complete(GatewayProbeResult.verifiedWithoutBudget);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('App verification and gateway access passed.'),
        findsOneWidget,
      );
      expect(calls, 1);
    },
  );

  testWidgets('connection failures show safe text without retrying', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PublicGatewayTestScreen(
          check: () async {
            calls++;
            throw StateError('private-error-canary');
          },
        ),
      ),
    );
    await tester.tap(find.text('Check connection'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No automatic retry will run.'), findsOneWidget);
    expect(find.textContaining('private-error-canary'), findsNothing);
    expect(calls, 1);
  });

  test('verification uses one read-only accounting preflight', () async {
    var calls = 0;
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'test-proof',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/v1/usage/check');
          expect(request.headers['X-Firebase-AppCheck'], 'test-proof');
          final body = jsonDecode(request.body) as Map;
          expect(body['sku'], 'routes_preflight');
          expect(body['units'], 1);
          expect(
            body['requestId'],
            matches(
              RegExp(
                r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
              ),
            ),
          );
          return http.Response('{"error":{"code":"testing_budget"}}', 429);
        }),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.verifiedWithoutBudget);
    expect(calls, 1);
  });

  test('unrelated rate limits do not count as app verification', () async {
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'test-proof',
        client: MockClient(
          (_) async => http.Response('{"error":{"code":"other"}}', 429),
        ),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.unavailable);
  });

  test('successful gateway preflight uses the actual status envelope', () async {
    var calls = 0;
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'test-proof',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"status":"ok"}', 200);
        }),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.verified);
    expect(calls, 1);
  });

  test('empty successful response does not establish verification', () async {
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'test-proof',
        client: MockClient((_) async => http.Response('{}', 200)),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.unavailable);
  });

  test('denied verification never retries', () async {
    var calls = 0;
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'test-proof',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"error":{"code":"access"}}', 401);
        }),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.denied);
    expect(calls, 1);
  });

  test('token acquisition failure dispatches no gateway request', () async {
    var calls = 0;
    final probe = PublicGatewayProbe(
      GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => throw StateError('fixture failure'),
        client: MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      ),
    );
    expect(await probe.check(), GatewayProbeResult.unavailable);
    expect(calls, 0);
  });
}
