import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../domain/place_search.dart';
import '../domain/search_terms.dart';

abstract class SearchAdapter {
  String get id;
  String get endpoint;
  bool get enabled;
  bool get categories => true;
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request);
}

class HttpSearchAdapter extends SearchAdapter {
  HttpSearchAdapter(this.client, this.id, {this.apiKey = '', String? endpoint})
    : endpoint =
          endpoint ??
          switch (id) {
            'geoapify' => 'https://api.geoapify.com',
            'locationiq' => 'https://api.locationiq.com/v1',
            _ => 'https://photon.komoot.io/api/',
          };
  final http.Client client;
  @override
  final String id, endpoint;
  final String apiKey;
  @override
  bool get enabled => id == 'photon' || apiKey.isNotEmpty;
  @override
  bool get categories => id != 'photon';
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) async {
    final area = request.area;
    final category = request.category;
    final brand = request.interpretation.brand;
    final nearbyBrand =
        !request.useOriginal &&
        category == null &&
        area != null &&
        brand != null &&
        brand.qualifiers.isEmpty &&
        !brand.brand.landmark &&
        brand.brand.geoCategories.isNotEmpty;
    final parameters = <String, String>{};
    var path = endpoint;
    if (id == 'geoapify') {
      path += category == null && !nearbyBrand
          ? '/v1/geocode/autocomplete'
          : '/v2/places';
      parameters.addAll({
        'apiKey': apiKey,
        'limit': category == null && !nearbyBrand ? '8' : '20',
        'filter': 'countrycode:ph',
      });
      if (nearbyBrand) {
        parameters['name'] = brand.brand.name;
        parameters['categories'] = brand.brand.geoCategories;
        parameters['filter'] =
            'countrycode:ph|circle:${area.longitude},${area.latitude},5000';
        parameters['bias'] = 'proximity:${area.longitude},${area.latitude}';
      } else if (category == null) {
        parameters['text'] = request.providerText;
        if (area != null) {
          parameters['bias'] = 'proximity:${area.longitude},${area.latitude}';
        }
      } else {
        if (area == null) throw const SearchFailure(SearchFailureKind.invalid);
        parameters['categories'] = category.geoapify;
        parameters['filter'] =
            'countrycode:ph|circle:${area.longitude},${area.latitude},5000';
        parameters['bias'] = 'proximity:${area.longitude},${area.latitude}';
      }
    } else if (id == 'locationiq') {
      path += category == null ? '/autocomplete' : '/nearby';
      parameters.addAll({
        'key': apiKey,
        'format': 'json',
        'limit': category == null ? '8' : '20',
      });
      if (category == null) {
        parameters.addAll({
          'q': request.providerText,
          'countrycodes': 'ph',
          'addressdetails': '1',
        });
        if (area != null) {
          // A viewbox biases results without restricting nationwide name lookup.
          parameters['viewbox'] =
              '${area.longitude - .05},${area.latitude + .05},${area.longitude + .05},${area.latitude - .05}';
          parameters['bounded'] = '0';
          if (brandOnlyQuery(request.providerText)) {
            parameters['importancesort'] = '0';
          }
        }
      } else {
        if (area == null) throw const SearchFailure(SearchFailureKind.invalid);
        parameters.addAll({
          'lat': '${area.latitude}',
          'lon': '${area.longitude}',
          'tag': category.locationIq,
          'radius': '5000',
        });
      }
    } else {
      parameters.addAll({
        'q': request.providerText,
        'countrycode': 'PH',
        'limit': '8',
      });
      if (area != null) {
        parameters.addAll({
          'lat': '${area.latitude}',
          'lon': '${area.longitude}',
          'zoom': '${area.zoom}',
        });
      }
    }
    // Exceptions never include the URL, provider response, or credential.
    http.Response response;
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 5), () {
      if (!abort.isCompleted) abort.complete();
    });
    try {
      final base = Uri.parse(path);
      final uri = base.replace(
        queryParameters: {...base.queryParameters, ...parameters},
      );
      response = await http.Response.fromStream(
        await client.send(
          http.AbortableRequest('GET', uri, abortTrigger: abort.future),
        ),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      throw const SearchFailure(SearchFailureKind.temporary);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SearchFailure(SearchFailureKind.access);
    }
    if (response.statusCode == 429) {
      final daily =
          id == 'locationiq' && response.body.toLowerCase().contains('day');
      final header = response.headers['retry-after'];
      final seconds = int.tryParse(header ?? '');
      final date = header == null ? null : DateTime.tryParse(header);
      if (daily) throw const SearchFailure(SearchFailureKind.daily);
      throw SearchFailure(
        daily ? SearchFailureKind.daily : SearchFailureKind.rate,
        retryAt: seconds != null && seconds >= 0
            ? DateTime.now().toUtc().add(Duration(seconds: seconds))
            : date ?? parseHttpDate(header),
      );
    }
    if (response.statusCode == 404 && id == 'locationiq') {
      try {
        final payload = jsonDecode(response.body);
        if (payload is Map &&
            '${payload['error']}'.toLowerCase().contains('unable to geocode')) {
          return [];
        }
      } catch (_) {
        /* Invalid response remains a failure. */
      }
    }
    if (response.statusCode >= 500) {
      throw const SearchFailure(SearchFailureKind.temporary);
    }
    if (response.statusCode != 200 || response.bodyBytes.length > 1000000) {
      throw const SearchFailure(SearchFailureKind.invalid);
    }
    try {
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final entries = id == 'locationiq'
          ? payload
          : (payload as Map)['features'];
      if (entries is! List) throw const FormatException();
      final found = <PlaceSearchResult>[];
      for (final entry in entries) {
        if (entry is! Map) continue;
        final properties = id == 'locationiq' ? entry : entry['properties'];
        if (properties is! Map) continue;
        final address = properties['address'] is Map
            ? properties['address'] as Map
            : const <String, dynamic>{};
        final country = id == 'locationiq'
            ? address['country_code']
            : properties[id == 'photon' ? 'countrycode' : 'country_code'];
        if ('$country'.toUpperCase() != 'PH') continue;
        final geometry = entry['geometry'];
        final coords = geometry is Map ? geometry['coordinates'] : null;
        final lat = id == 'locationiq'
            ? double.tryParse('${entry['lat']}')
            : coords is List && coords.length >= 2
            ? (coords[1] as num?)?.toDouble()
            : null;
        final lon = id == 'locationiq'
            ? double.tryParse('${entry['lon']}')
            : coords is List && coords.length >= 2
            ? (coords[0] as num?)?.toDouble()
            : null;
        if (lat == null ||
            lon == null ||
            !lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          continue;
        }
        if ((category != null || (id == 'geoapify' && nearbyBrand)) &&
            area != null &&
            distanceMeters(area.latitude, area.longitude, lat, lon) > 5000) {
          continue;
        }
        final raw =
            properties['datasource'] is Map &&
                properties['datasource']['raw'] is Map
            ? properties['datasource']['raw'] as Map
            : const <String, dynamic>{};
        final type = '${properties['osm_type'] ?? raw['osm_type'] ?? ''}'
            .toLowerCase();
        final osmType = {
          'n': 'node',
          'w': 'way',
          'r': 'relation',
          'node': 'node',
          'way': 'way',
          'relation': 'relation',
        }[type];
        final osmNumber = properties['osm_id'] ?? raw['osm_id'];
        final osm = osmType != null && int.tryParse('$osmNumber') != null
            ? 'osm/$osmType/$osmNumber'
            : null;
        final recordedName =
            properties['name'] ??
            properties['display_place'] ??
            address['name'];
        final name =
            (category != null
                    ? recordedName ?? '${category.label} (name not recorded)'
                    : recordedName ??
                          properties['street'] ??
                          address['road'] ??
                          properties['formatted'] ??
                          properties['display_name'])
                ?.toString()
                .trim();
        if (name == null || name.isEmpty) continue;
        final source =
            osm ??
            '$id/${properties['place_id'] ?? '${lat.toStringAsFixed(6)},${lon.toStringAsFixed(6)}/$name'}';
        final description =
            properties['address_line2'] ??
            properties['display_address'] ??
            [
              properties['street'] ?? address['road'],
              properties['city'] ?? address['city'] ?? address['town'],
              properties['state'] ?? address['state'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
        found.add(
          PlaceSearchResult(
            name: name,
            latitude: lat,
            longitude: lon,
            sourceId: source,
            osmId: osm,
            provider: id,
            address: '$description'.isEmpty ? null : '$description',
            rank: found.length,
            brand: (properties['brand'] ?? raw['brand'])?.toString(),
            alternateNames: [
              properties['alt_name'],
              raw['alt_name'],
              properties['name:en'],
            ].whereType<String>().expand((v) => v.split(';')).toList(),
            locality:
                (properties['city'] ??
                        address['city'] ??
                        address['town'] ??
                        properties['district'])
                    ?.toString(),
            category: category?.name,
            street:
                properties['osm_key'] == 'highway' ||
                properties['class'] == 'highway' ||
                properties['type'] == 'street' ||
                properties['result_type'] == 'street',
            retrievedAt: DateTime.now().toUtc(),
            attributions: [
              '© OpenStreetMap contributors',
              if (id == 'geoapify') 'Powered by Geoapify',
              if (id == 'locationiq') 'Search by LocationIQ.com',
            ],
          ),
        );
        if (found.length >= (category == null ? 8 : 20)) break;
      }
      return found;
    } catch (_) {
      throw const SearchFailure(SearchFailureKind.invalid);
    }
  }
}

DateTime? parseHttpDate(String? value) {
  if (value == null) return null;
  // RFC 7231 IMF-fixdate: Wed, 21 Oct 2015 07:28:00 GMT.
  final match = RegExp(
    r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
  ).firstMatch(value);
  if (match == null) return null;
  final month =
      [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ].indexOf(match[2]!) +
      1;
  if (month == 0) return null;
  return DateTime.utc(
    int.parse(match[3]!),
    month,
    int.parse(match[1]!),
    int.parse(match[4]!),
    int.parse(match[5]!),
    int.parse(match[6]!),
  );
}
