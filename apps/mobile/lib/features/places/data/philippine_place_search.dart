import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';

final philippinePlaceSearchProvider = Provider<PhilippinePlaceSearch>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  const endpoint = String.fromEnvironment(
    'WAYDAY_PLACE_SEARCH_URL',
    defaultValue: 'https://photon.komoot.io/api/',
  );
  return PhilippinePlaceSearch(client, Uri.parse(endpoint));
});

class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable();
}

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sourceId,
    this.address,
  });

  final String name;
  final double latitude;
  final double longitude;
  final String sourceId;
  final String? address;
}

/// Photon-compatible forward search. The public demo is for limited testing.
class PhilippinePlaceSearch {
  PhilippinePlaceSearch(this.client, this.endpoint);

  final http.Client client;
  final Uri endpoint;

  Future<List<PlaceSearchResult>> search(String input) async {
    final query = input.trim();
    if (query.length < 2) return [];
    if (query.length > 100) throw const PlaceSearchUnavailable();
    final uri = endpoint.replace(
      queryParameters: {
        ...endpoint.queryParameters,
        'q': query,
        'countrycode': 'PH',
        'limit': '8',
      },
    );
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 || response.bodyBytes.length > 100000) {
        throw const PlaceSearchUnavailable();
      }
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      if (payload is! Map || payload['features'] is! List) {
        throw const FormatException('Invalid search response');
      }
      final results = <PlaceSearchResult>[];
      for (final feature in payload['features'] as List) {
        if (feature is! Map ||
            feature['properties'] is! Map ||
            feature['geometry'] is! Map) {
          continue;
        }
        final properties = feature['properties'] as Map;
        final geometry = feature['geometry'] as Map;
        final coordinates = geometry['coordinates'];
        final name = properties['name'];
        final country = properties['countrycode'];
        final type = properties['osm_type'];
        final id = properties['osm_id'];
        if (country is! String ||
            country.toUpperCase() != 'PH' ||
            name is! String ||
            name.trim().isEmpty ||
            geometry['type'] != 'Point' ||
            coordinates is! List ||
            coordinates.length < 2 ||
            coordinates[0] is! num ||
            coordinates[1] is! num ||
            type is! String ||
            !{'N', 'W', 'R'}.contains(type.toUpperCase()) ||
            id is! int ||
            id <= 0) {
          continue;
        }
        final lon = (coordinates[0] as num).toDouble();
        final lat = (coordinates[1] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          continue;
        }
        final addressParts = [
          properties['street'],
          properties['city'],
          properties['state'],
        ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
        results.add(
          PlaceSearchResult(
            name: name.trim(),
            latitude: lat,
            longitude: lon,
            sourceId:
                'osm/${{'N': 'node', 'W': 'way', 'R': 'relation'}[type.toUpperCase()]}/$id',
            address: addressParts.isEmpty ? null : addressParts.join(', '),
          ),
        );
        if (results.length == 8) break;
      }
      return results;
    } catch (_) {
      throw const PlaceSearchUnavailable();
    }
  }
}
