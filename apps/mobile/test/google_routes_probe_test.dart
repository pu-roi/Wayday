import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../tool/google_routes_probe.dart';

const _key = 'fixture-only-key-never-log';
final _certificate = 'A1' * 20;

http.Response _route() => http.Response(
  jsonEncode({
    'routes': [
      {'duration': '120s', 'distanceMeters': 500},
    ],
  }),
  200,
);

http.Response _denial(String reason) => http.Response(
  jsonEncode({
    'error': {
      'message': 'Do not log this message: $_key',
      'details': [
        {
          '@type': 'type.googleapis.com/google.rpc.ErrorInfo',
          'reason': reason,
          'metadata': {'private': _key},
        },
      ],
    },
  }),
  403,
);

GoogleRoutesProbe _probe(http.Client client) => GoogleRoutesProbe(
  client,
  apiKey: _key,
  packageName: 'dev.wayday.wayday',
  certificate: _certificate,
  pause: Duration.zero,
);

void main() {
  test(
    'qualifies both identities and a one-element matrix within four starts',
    () async {
      final requests = <http.Request>[];
      final report = await _probe(
        MockClient((request) async {
          requests.add(request);
          expect(request.url.query, isEmpty);
          expect(request.headers['X-Goog-Api-Key'], _key);
          final body = jsonDecode(request.body) as Map;
          expect(body['travelMode'], 'DRIVE');
          expect(body['routingPreference'], 'TRAFFIC_AWARE');
          expect(
            request.headers['X-Goog-FieldMask'],
            isNot(contains('polyline')),
          );
          if (requests.length == 2) {
            expect(request.headers['X-Android-Package'], endsWith('.rejected'));
            expect(request.headers['X-Android-Cert'], _certificate);
            return _denial('API_KEY_ANDROID_APP_BLOCKED');
          }
          if (requests.length == 3) {
            expect(request.headers['X-Android-Package'], 'dev.wayday.wayday');
            expect(request.headers['X-Android-Cert'], '0' * 40);
            return _denial('API_KEY_ANDROID_APP_BLOCKED');
          }
          expect(request.headers['X-Android-Package'], 'dev.wayday.wayday');
          expect(request.headers['X-Android-Cert'], _certificate);
          if (requests.length == 4) {
            expect(body['origins'], hasLength(1));
            expect(body['destinations'], hasLength(1));
            return http.Response(
              jsonEncode([
                {
                  'condition': 'ROUTE_EXISTS',
                  'duration': '120s',
                  'distanceMeters': 500,
                },
              ]),
              200,
            );
          }
          return _route();
        }),
      ).run();
      expect(report['passed'], true);
      expect(report['requests_started'], 4);
      expect(report['route_requests_started'], 3);
      expect(report['matrix_elements_requested'], 1);
      expect(jsonEncode(report), isNot(contains(_key)));
      expect(jsonEncode(report), isNot(contains('routes.googleapis.com')));
      expect(jsonEncode(report), isNot(contains('distanceMeters')));
    },
  );

  test(
    'does not mistake a generic service denial for app enforcement',
    () async {
      var starts = 0;
      final report = await _probe(
        MockClient(
          (_) async =>
              ++starts == 1 ? _route() : _denial('API_KEY_SERVICE_BLOCKED'),
        ),
      ).run();
      expect(report['passed'], false);
      expect(starts, 2);
      expect(jsonEncode(report), isNot(contains(_key)));
    },
  );

  test('stops if an incorrect identifier is accepted', () async {
    var starts = 0;
    final report = await _probe(
      MockClient((_) async {
        starts++;
        return _route();
      }),
    ).run();
    expect(report['passed'], false);
    expect(starts, 2);
    expect(jsonEncode(report), contains('incorrect_identity_accepted'));
  });

  test(
    'stops on an initial access denial without resetting restrictions',
    () async {
      var starts = 0;
      final report = await _probe(
        MockClient((_) async {
          starts++;
          return _denial('API_KEY_ANDROID_APP_BLOCKED');
        }),
      ).run();
      expect(report['passed'], false);
      expect(starts, 1);
    },
  );

  test(
    'sanitizes transport exceptions without retrying',
    () async {
      var starts = 0;
      final report = await _probe(
        MockClient((_) async {
          starts++;
          throw http.ClientException('sensitive $_key');
        }),
      ).run();
      expect(report['passed'], false);
      expect(starts, 1);
      expect(jsonEncode(report), isNot(contains(_key)));
    },
  );

  test(
    'does not accept an empty successful response as a usable route',
    () async {
      final report = await _probe(
        MockClient((_) async => http.Response('{"routes":[]}', 200)),
      ).run();
      expect(report['passed'], false);
      expect(report['requests_started'], 1);
    },
  );
}
