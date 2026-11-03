import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/core/network/gateway_client.dart';
import 'package:wayday/features/sharing/share_models.dart';
import 'package:wayday/features/sharing/share_repository.dart';

SharedSnapshot snapshot() => SharedSnapshot(
  sourceId: 'fixture-source',
  route: [
    [14.5, 121.0],
    [14.6, 121.1],
  ],
  stops: const [ShareStop('one', 'Buy groceries', 'Market', 14.55, 121.05)],
  start: [14.5, 121],
  destination: [14.6, 121.1],
);

Map<String, dynamic> sharedResponse({Map<String, dynamic>? overrides}) => {
  'snapshot': snapshot().toJson(),
  'expiresAt': 1793707200 + 7200,
  'revision': 0,
  'broadcastRevision': 0,
  'ownerSharing': false,
  'broadcasting': false,
  ...?overrides,
};

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1793707200 * 1000);
  test(
    'offline native revocation keeps durable intent to end link access',
    () async {
      String? persisted;
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          token: () async => 'proof',
          client: MockClient((request) async {
            if (request.url.path == '/v1/shares') {
              final body = jsonDecode(request.body) as Map;
              return http.Response(
                jsonEncode({
                  'shareId': body['operationId'],
                  'expiresAt': 1793714400,
                }),
                201,
              );
            }
            throw http.ClientException('offline');
          }),
        ),
        now: () => now,
        readStorage: () async => persisted,
        writeStorage: (v) async => persisted = v,
        nativeStatus: () async => {
          'shareId': (jsonDecode(persisted!) as Map)['owner']['id'],
        'role': 'owner',
        },
        stopNative: () async =>
            throw http.ClientException('offline revocation'),
      );
      final access = await repo.create(snapshot());
      await expectLater(repo.end(access), throwsA(anything));
      expect(
        ((jsonDecode(persisted!) as Map)['owner'] as Map)['revocationPending'],
        isTrue,
      );
    },
  );
  test(
    'uncertain pairing checks the same saved credential instead of replacing it',
    () async {
      String? persisted;
      String? acceptedToken;
      var pairs = 0;
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          token: () async => 'proof',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/pair')) {
              pairs++;
              acceptedToken =
                  (jsonDecode(request.body) as Map)['recipientToken'] as String;
              throw http.ClientException('response lost');
            }
            expect(request.headers['Authorization'], 'Bearer $acceptedToken');
            return http.Response(jsonEncode(sharedResponse()), 200);
          }),
        ),
        now: () => now,
        readStorage: () async => persisted,
        writeStorage: (v) async => persisted = v,
      );
      final invitation = ShareAccess(
        id: ShareRepository.operationId(),
        token: ShareRepository.credential(),
        role: 'invitation',
      );
      await expectLater(
        repo.pair(invitation),
        throwsA(isA<http.ClientException>()),
      );
      final paired = await repo.pair(invitation);
      expect(paired.token, acceptedToken);
      expect(pairs, 1);
    },
  );
  test(
    'credentials and links use fragment without leaking into request URL',
    () async {
      String? persisted;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(
          persisted,
          isNotNull,
          reason: 'Management credentials must be durable before dispatch',
        );
        final body = jsonDecode(request.body) as Map;
        expect(body['ownerToken'], matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
        expect(body['viewerToken'], isNot(body['ownerToken']));
        return http.Response(
          jsonEncode({
            'shareId': body['operationId'],
            'expiresAt': 1793707200 + 7200,
          }),
          201,
        );
      });
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          client: client,
          token: () async => 'proof',
        ),
        now: () => now,
        readStorage: () async => persisted,
        writeStorage: (v) async => persisted = v,
      );
      final access = await repo.create(snapshot());
      final link = Uri.parse(repo.link(access));
      expect(link.path, '/share/');
      expect(link.query, isEmpty);
      expect(link.fragment, '${access.id}.${access.token}');
      expect(requests.single.url.toString(), 'https://share.example/v1/shares');
      expect(requests.single.headers['X-Firebase-AppCheck'], 'proof');
      expect(repo.parseLink(link.toString())?.id, access.id);
      expect(
        repo.parseLink(link.replace(host: 'evil.example').toString()),
        isNull,
      );
    },
  );
  test(
    'uncertain create reuses operation and credentials rather than creating another share',
    () async {
      String? persisted;
      final bodies = <String>[];
      final client = MockClient((request) async {
        bodies.add(request.body);
        if (bodies.length == 1) throw http.ClientException('offline');
        final body = jsonDecode(request.body) as Map;
        return http.Response(
          jsonEncode({
            'shareId': body['operationId'],
            'expiresAt': 1793707200 + 7200,
          }),
          201,
        );
      });
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          client: client,
          token: () async => 'proof',
        ),
        now: () => now,
        readStorage: () async => persisted,
        writeStorage: (v) async => persisted = v,
      );
      await expectLater(
        repo.create(snapshot()),
        throwsA(isA<http.ClientException>()),
      );
      await repo.create(snapshot());
      expect(bodies[0], bodies[1]);
    },
  );
  test(
    'recipient view is read-only and needs no App Check or location permission',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['X-Firebase-AppCheck'], isNull);
        expect(request.headers['Authorization'], startsWith('Bearer '));
        return http.Response(jsonEncode(sharedResponse()), 200);
      });
      final repo = ShareRepository(
        gateway: GatewayClient(
          baseUrl: 'https://share.example',
          client: client,
          token: () async => throw StateError('must not attest read'),
        ),
        now: () => now,
      );
      final shared = await repo.read(
        ShareAccess(
          id: ShareRepository.operationId(),
          token: ShareRepository.credential(),
          role: 'viewer',
        ),
      );
      expect(shared.snapshot.stops.single.title, 'Buy groceries');
      expect(shared.broadcasting, isFalse);
    },
  );
  test('expired shared response never remains viewable', () async {
    final repo = ShareRepository(
      gateway: GatewayClient(
        baseUrl: 'https://share.example',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(sharedResponse(overrides: {'expiresAt': 1793707200})),
            200,
          ),
        ),
      ),
      now: () => now,
    );
    await expectLater(
      repo.read(
        ShareAccess(
          id: ShareRepository.operationId(),
          token: ShareRepository.credential(),
          role: 'viewer',
        ),
      ),
      throwsA(
        isA<SharingFailure>().having((e) => e.unavailable, 'unavailable', true),
      ),
    );
  });
  test(
    'fresh fixes require valid coordinates and disappear after 45 seconds',
    () {
      final fix = {
        'latitude': 14.5,
        'longitude': 121.0,
        'accuracy': 30.0,
        'recordedAt': 1793707200.0,
        'receivedAt': 1793707200.0,
      };
      expect(
        SharedTrip.fresh(fix, now.add(const Duration(seconds: 45))),
        isTrue,
      );
      expect(
        SharedTrip.fresh(fix, now.add(const Duration(seconds: 46))),
        isFalse,
      );
      expect(SharedTrip.fresh({...fix, 'latitude': 91.0}, now), isFalse);
      expect(SharedTrip.fresh({...fix, 'accuracy': -1.0}, now), isFalse);
    },
  );
  test('the exact route is preserved and oversized geometry is rejected', () {
    final value = snapshot();
    expect(SharedSnapshot.fromJson(value.toJson()).route, value.route);
    expect(
      () => SharedSnapshot(
        sourceId: 'large',
        route: List.generate(1601, (i) => [14.5, 121.0]),
        stops: value.stops,
        start: value.start,
        destination: value.destination,
      ),
      throwsA(isA<SharingFailure>()),
    );
  });
}
