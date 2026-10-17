import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../domain/place_intent.dart';

class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable();
}

class PlaceResult {
  const PlaceResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.category = '',
    this.sourceDate = '',
    this.coordinateKind = 'mapped_point',
    this.distanceMetres,
    this.matchKind = 'nearby',
  });
  final String id, name, category, sourceDate, coordinateKind;
  final String? address;
  final double latitude, longitude;
  final double? distanceMetres;
  final String matchKind;
  PlaceIntent get intent => PlaceIntent(
    kind: PlaceKind.specific,
    label: name,
    latitude: latitude,
    longitude: longitude,
    source: id,
    address: address,
    sourceDate: sourceDate,
    coordinateKind: coordinateKind,
  );
  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    final result = PlaceResult(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
      category: json['category'] as String,
      sourceDate: json['source_date'] as String,
      coordinateKind: json['coordinate_kind'] as String,
      distanceMetres: (json['distance_metres'] as num?)?.toDouble(),
      matchKind: json['match_kind'] as String? ?? 'nearby',
    );
    if (!result.intent.hasCoordinates || result.name.trim().isEmpty) {
      throw const FormatException('Invalid place result');
    }
    return result;
  }
}

abstract class PlaceSearchRepository {
  Future<List<PlaceResult>> search(String query);
  Future<List<PlaceResult>> nearby(double latitude, double longitude);
}

class ApiPlaceSearchRepository implements PlaceSearchRepository {
  ApiPlaceSearchRepository(this.client, this.baseUrl);
  final http.Client client;
  final String baseUrl;
  Future<List<PlaceResult>> _get(String path, Map<String, String> query) async {
    try {
      final uri = Uri.parse(
        baseUrl,
      ).replace(path: path, queryParameters: query);
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200 || response.bodyBytes.length > 100000) {
        throw const PlaceSearchUnavailable();
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (data['places'] as List<dynamic>)
          .take(12)
          .map((p) => PlaceResult.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const PlaceSearchUnavailable();
    }
  }

  @override
  Future<List<PlaceResult>> search(String query) =>
      _get('/v1/places', {'q': query, 'limit': '8'});
  @override
  Future<List<PlaceResult>> nearby(double latitude, double longitude) =>
      _get('/v1/places/nearby', {'lat': '$latitude', 'lon': '$longitude'});
}

final placeSearchRepositoryProvider = Provider<PlaceSearchRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  const override = String.fromEnvironment('WAYDAY_API_URL');
  final base = override.isNotEmpty
      ? override
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8780'
      : 'http://127.0.0.1:8780';
  return ApiPlaceSearchRepository(client, base);
});
