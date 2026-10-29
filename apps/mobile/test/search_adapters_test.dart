import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  test(
    'Jolibee typo uses one canonical request per provider and preserves input/qualifiers',
    () async {
      for (final id in ['geoapify', 'locationiq', 'photon']) {
        for (final query in ['jolibee', 'jolibee Shangri-La']) {
          var calls = 0;
          final adapter = HttpSearchAdapter(
            MockClient((request) async {
              calls++;
              final p = request.url.queryParameters;
              expect(
                p[id == 'geoapify' ? (query == 'jolibee' ? 'name' : 'text') : 'q'],
                query == 'jolibee' ? 'Jollibee' : 'Jollibee Shangri-La',
              );
              if (id == 'locationiq') {
                expect(p['importancesort'], query == 'jolibee' ? '0' : isNull);
                expect(p['bounded'], '0');
              }
              return http.Response(
                id == 'locationiq' ? '[]' : '{"features":[]}',
                200,
              );
            }),
            id,
            apiKey: 'fixture-key',
          );
          final search = PlaceSearchRequest(
            query,
            origin: const SearchOrigin.device(14.58, 121.05),
          );
          await adapter.search(search);
          expect(calls, 1);
          expect(search.text, query);
        }
      }
      expect(
        PlaceSearchRequest('jolibee').key,
        PlaceSearchRequest('Jollibee').key,
      );
      expect(PlaceSearchRequest('Jolibee Laundry').text, 'Jolibee Laundry');
      expect(PlaceSearchRequest('Rizal Street').providerText, 'Rizal Street');
    },
  );
  test(
    'all providers receive device bias; LocationIQ distance ordering is brand-only',
    () async {
      for (final id in ['geoapify', 'locationiq', 'photon']) {
        for (final query in ['McDonald’s', 'Megamall']) {
          final adapter = HttpSearchAdapter(
            MockClient((request) async {
              final p = request.url.queryParameters;
              if (id == 'geoapify') {
                expect(p['bias'], 'proximity:121.05,14.58');
              } else if (id == 'locationiq') {
                expect(p['viewbox'], isNotNull);
                expect(p['bounded'], '0');
                expect(
                  p['importancesort'],
                  query == 'McDonald’s' ? '0' : isNull,
                );
              } else {
                expect(p['lat'], '14.58');
                expect(p['lon'], '121.05');
                expect(p['zoom'], '12.0');
                expect(p.containsKey('location_bias_scale'), isFalse);
              }
              return http.Response(
                id == 'locationiq' ? '[]' : '{"features":[]}',
                200,
              );
            }),
            id,
            apiKey: 'fixture-key',
          );
          await adapter.search(
            PlaceSearchRequest(
              query,
              origin: const SearchOrigin.device(14.58, 121.05),
            ),
          );
        }
      }
    },
  );
  test(
    'Geoapify normalizes identity, filters PH and preserves its record',
    () async {
      final adapter = HttpSearchAdapter(
        MockClient((request) async {
          expect(request.url.path, '/v1/geocode/autocomplete');
          expect(request.url.queryParameters['filter'], 'countrycode:ph');
          expect(request.url.queryParameters['limit'], '8');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {
                    'name': 'Branch',
                    'country_code': 'ph',
                    'address_line2': 'Cebu',
                    'datasource': {
                      'raw': {'osm_id': 123, 'osm_type': 'n'},
                    },
                  },
                  'geometry': {
                    'coordinates': [123.9, 10.3],
                  },
                },
                {
                  'properties': {'name': 'Foreign', 'country_code': 'us'},
                  'geometry': {
                    'coordinates': [-75, 40],
                  },
                },
              ],
            }),
            200,
          );
        }),
        'geoapify',
        apiKey: 'fixture-key',
      );
      final result = (await adapter.search(
        PlaceSearchRequest('Branch'),
      )).single;
      expect(result.sourceId, 'osm/node/123');
      expect(result.address, 'Cebu');
      expect(result.provider, 'geoapify');
      expect(result.attributions, contains('Powered by Geoapify'));
    },
  );
  test(
    'category uses bounded circle and LocationIQ OSM tag, excludes foreign and distant points',
    () async {
      for (final id in ['geoapify', 'locationiq']) {
        final adapter = HttpSearchAdapter(
          MockClient((request) async {
            expect(request.url.queryParameters['limit'], '20');
            if (id == 'geoapify') {
              expect(
                request.url.queryParameters['categories'],
                'commercial.marketplace',
              );
              expect(
                request.url.queryParameters['filter'],
                contains('circle:'),
              );
              return http.Response('{"features":[]}', 200);
            }
            expect(request.url.queryParameters['tag'], 'amenity:marketplace');
            expect(request.url.queryParameters['radius'], '5000');
            return http.Response(
              jsonEncode([
                {
                  'place_id': '1',
                  'display_place': 'Market',
                  'lat': '14.5',
                  'lon': '121',
                  'address': {'country_code': 'ph'},
                },
                {
                  'place_id': '2',
                  'display_place': 'Far',
                  'lat': '10.3',
                  'lon': '123.9',
                  'address': {'country_code': 'ph'},
                },
                {
                  'place_id': '3',
                  'display_place': 'Foreign',
                  'lat': '14.5',
                  'lon': '121',
                  'address': {'country_code': 'us'},
                },
              ]),
              200,
            );
          }),
          id,
          apiKey: 'fixture-key',
        );
        final found = await adapter.search(
          PlaceSearchRequest(
            'palengke',
            category: SearchCategory.marketplace,
            area: const SearchArea(14.5, 121, 12),
          ),
        );
        expect(found.length, id == 'geoapify' ? 0 : 1);
      }
    },
  );
  test(
    'LocationIQ errors are typed, documented no-results is empty, Retry-After supports both forms',
    () async {
      for (final status in [401, 403, 429, 500, 404]) {
        final adapter = HttpSearchAdapter(
          MockClient(
            (_) async => http.Response(
              status == 404
                  ? '{"error":"Unable to geocode"}'
                  : '{"error":"Rate Limited Day"}',
              status,
            ),
          ),
          'locationiq',
          apiKey: 'fixture-key',
        );
        final request = PlaceSearchRequest('Library');
        if (status == 404) {
          expect(await adapter.search(request), isEmpty);
        } else {
          await expectLater(
            adapter.search(request),
            throwsA(
              isA<SearchFailure>().having(
                (e) => e.kind,
                'kind',
                status == 429
                    ? SearchFailureKind.daily
                    : status >= 500
                    ? SearchFailureKind.temporary
                    : SearchFailureKind.access,
              ),
            ),
          );
        }
      }
      expect(
        parseHttpDate('Wed, 21 Oct 2026 07:28:00 GMT'),
        DateTime.utc(2026, 10, 21, 7, 28),
      );
      final a = HttpSearchAdapter(
        MockClient(
          (_) async => http.Response('', 429, headers: {'retry-after': '120'}),
        ),
        'geoapify',
        apiKey: 'fixture-key',
      );
      await expectLater(
        a.search(PlaceSearchRequest('Cebu')),
        throwsA(
          isA<SearchFailure>().having(
            (e) => e.retryAt!.difference(DateTime.now()).inSeconds,
            'retry',
            inInclusiveRange(118, 120),
          ),
        ),
      );
    },
  );
  test('malformed provider payload becomes sanitized failure', () async {
    final adapter = HttpSearchAdapter(
      MockClient((_) async => http.Response('{broken', 200)),
      'geoapify',
      apiKey: 'fixture-key',
    );
    await expectLater(
      adapter.search(PlaceSearchRequest('Cebu')),
      throwsA(isA<SearchFailure>()),
    );
  });
  test('new metadata roundtrips and old saved places remain readable', () {
    const place = PlaceIntent(
      kind: PlaceKind.specific,
      label: 'Market',
      latitude: 14.5,
      longitude: 121,
      source: 'osm/node/1',
      provider: 'geoapify',
      attributions: ['Powered by Geoapify'],
    );
    final saved = SavedPlace(
      id: 'saved',
      place: PlaceIntent.fromJson(place.toJson()),
    );
    expect(saved.intent.provider, 'geoapify');
    expect(saved.intent.attributions, ['Powered by Geoapify']);
    final old = place.toJson()
      ..remove('provider')
      ..remove('attributions');
    expect(PlaceIntent.fromJson(old).attributions, isEmpty);
  });
}
