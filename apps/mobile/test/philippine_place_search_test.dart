import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/features/places/data/philippine_place_search.dart';

Map<String, Object> feature(String country, List<Object> coordinates) => {
  'type': 'Feature',
  'properties': {
    'name': 'Example',
    'countrycode': country,
    'osm_type': 'N',
    'osm_id': 123,
  },
  'geometry': {'type': 'Point', 'coordinates': coordinates},
};

void main() {
  test(
    'filters foreign and malformed results and sends a country restriction',
    () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['countrycode'], 'PH');
        expect(request.url.queryParameters['q'], 'Cebu');
        return http.Response(
          jsonEncode({
            'features': [
              feature('PH', [123.9, 10.3]),
              feature('SG', [103.8, 1.3]),
              feature('', [120, 14]),
              feature('PH', [500, 14]),
            ],
          }),
          200,
        );
      });
      final result = await PhilippinePlaceSearch(
        client,
        Uri.parse('https://example.test/api'),
      ).search(' Cebu ');
      expect(result, hasLength(1));
      expect(result.single.sourceId, 'osm/node/123');
      expect(result.single.latitude, 10.3);
      expect(result.single.longitude, 123.9);
    },
  );

  test('distinguishes empty results from an unavailable provider', () async {
    final empty = PhilippinePlaceSearch(
      MockClient((_) async => http.Response('{"features": []}', 200)),
      Uri.parse('https://example.test/api'),
    );
    expect(await empty.search('Cebu'), isEmpty);
    final unavailable = PhilippinePlaceSearch(
      MockClient((_) async => http.Response('error', 503)),
      Uri.parse('https://example.test/api'),
    );
    await expectLater(
      unavailable.search('Cebu'),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
  });
}
