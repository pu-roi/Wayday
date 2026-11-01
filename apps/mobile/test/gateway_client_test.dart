import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/road_estimates.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/today/domain/day.dart';

void main() {
  test(
    'public search and reverse use the gateway without embedded provider keys',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final gateway = GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'proof',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/search/geoapify');
          expect(request.body, isNot(contains('private-canary')));
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"features":[]}', 200);
        }),
      );
      final direct = MockClient(
        (_) async => throw StateError(
          'Public search must not call the provider directly',
        ),
      );
      final adapter = HttpSearchAdapter(
        direct,
        'geoapify',
        apiKey: 'private-canary',
        gateway: gateway,
      );
      expect(adapter.enabled, true);
      expect(
        await adapter.search(PlaceSearchRequest('grocery store')),
        isEmpty,
      );
      expect(await adapter.reverse(14.58, 121.05), isEmpty);
      expect(bodies.map((b) => b['path']), [
        '/v1/geocode/autocomplete',
        '/v1/geocode/reverse',
      ]);
    },
  );
  test(
    'public route seed needs no device REST key and reuses an unchanged response',
    () async {
      var calls = 0;
      final gateway = GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'proof',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/v1/routes/computeRoutes');
          expect(
            (jsonDecode(request.body) as Map)['fieldMask'],
            'routes.polyline.encodedPolyline',
          );
          return http.Response(
            '{"routes":[{"polyline":{"encodedPolyline":"_t~wAoqyaVo}@o}@"}}]}',
            200,
          );
        }),
      );
      final roads = PlanningRoads(
        MockClient((_) async => throw StateError('Direct REST is forbidden')),
        PublicPlanningBudget(gateway: gateway),
        gateway: gateway,
        identity: () async =>
            throw StateError('No private signing-header path'),
      );
      final day = DayPlan(errands: const [], profile: TravelProfile.walk);
      const points = [
        PlanCandidate(
          key: 'from',
          place: PlaceIntent(
            label: 'Start fixture',
            latitude: 14.58,
            longitude: 121.05,
          ),
          errandIds: {},
        ),
        PlanCandidate(
          key: 'to',
          place: PlaceIntent(
            label: 'End fixture',
            latitude: 14.59,
            longitude: 121.06,
          ),
          errandIds: {},
        ),
      ];
      expect(await roads.discoveryRoute(day, points), '_t~wAoqyaVo}@o}@');
      expect(await roads.discoveryRoute(day, points), '_t~wAoqyaVo}@o}@');
      expect(calls, 1);
    },
  );
  test(
    'public calls use attestation, bounded approved origin and no provider credential',
    () async {
      var requests = 0;
      final client = GatewayClient(
        baseUrl: 'https://wayday.example',
        token: () async => 'fixture-proof',
        client: MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://wayday.example/v1/routes/computeRoutes',
          );
          expect(request.headers['X-Firebase-AppCheck'], 'fixture-proof');
          expect(request.headers.containsKey('X-Goog-Api-Key'), false);
          return http.Response('{}', 200);
        }),
      );
      expect(
        (await client.post('/v1/routes/computeRoutes', {})).statusCode,
        200,
      );
      expect(requests, 1);
    },
  );
  test(
    'invalid configuration and missing attestation never dispatch',
    () async {
      var requests = 0;
      final transport = MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      });
      for (final url in [
        'http://example.org',
        'https://example.org/path',
        'https://user:password@example.org',
        'https://example.org?key=value',
      ]) {
        await expectLater(
          GatewayClient(
            baseUrl: url,
            token: () async => 'proof',
            client: transport,
          ).post('/v1/usage/check', {}),
          throwsFormatException,
        );
      }
      await expectLater(
        GatewayClient(
          baseUrl: 'https://example.org',
          token: () async => '',
          client: transport,
        ).post('/v1/usage/check', {}),
        throwsFormatException,
      );
      expect(requests, 0);
    },
  );
  test('failed requests are not automatically retried', () async {
    var requests = 0;
    final client = GatewayClient(
      baseUrl: 'https://example.org',
      token: () async => 'proof',
      client: MockClient((_) async {
        requests++;
        return http.Response('{"error":{"code":"provider_http_429"}}', 429);
      }),
    );
    expect((await client.post('/v1/interpretations', {})).statusCode, 429);
    expect(requests, 1);
  });
  test(
    'public budget does not read or clone private allocations and avoids double REST charges',
    () async {
      final calls = <String>[];
      final bodies = <Map<String, dynamic>>[];
      final gateway = GatewayClient(
        baseUrl: 'https://example.org',
        token: () async => 'proof',
        client: MockClient((r) async {
          calls.add(r.url.path);
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response('{}', 200);
        }),
      );
      final budget = PublicPlanningBudget(gateway: gateway);
      await budget.google('routes_DRIVE', 1, 10000);
      expect(calls, isEmpty);
      await budget.google('routes_preflight', 100, 15000, checkOnly: true);
      await budget.google('navigation', 3, 25000);
      await budget.google('navigation', 3, 25000, release: true);
      expect(calls, [
        '/v1/usage/check',
        '/v1/usage/reserve',
        '/v1/usage/release',
      ]);
      expect(bodies[1]['requestId'], bodies[2]['requestId']);
      expect(bodies[0].containsKey('limitMicros'), false);
    },
  );
}
