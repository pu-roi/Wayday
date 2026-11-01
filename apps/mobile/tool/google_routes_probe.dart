import 'dart:convert';

import 'package:http/http.dart' as http;

/// Small, explicit live qualification; not a production routing adapter.
/// Results deliberately exclude response bodies, coordinates, keys, and URLs.
class GoogleRoutesProbe {
  GoogleRoutesProbe(
    this.client, {
    required this.apiKey,
    required this.packageName,
    required String certificate,
    this.timeout = const Duration(seconds: 5),
    this.pause = const Duration(milliseconds: 1100),
  }) : certificate = certificate.replaceAll(':', '').toUpperCase() {
    if (apiKey.isEmpty ||
        packageName.isEmpty ||
        !RegExp(r'^[A-F0-9]{40}$').hasMatch(this.certificate)) {
      throw ArgumentError(
        'Missing key, package, or valid signing fingerprint.',
      );
    }
  }

  final http.Client client;
  final String apiKey;
  final String packageName;
  final String certificate;
  final Duration timeout;
  final Duration pause;

  // Public test landmarks; never use a person's location or saved errands.
  static const _origin = {'address': 'SM Megamall, Mandaluyong, Philippines'};
  static const _destination = {
    'address': 'Shangri-La Plaza, Mandaluyong, Philippines',
  };

  Future<Map<String, Object?>> run() async {
    final checks = <Map<String, Object?>>[];
    var passed = true;
    for (final check in [
      'route_correct_identity',
      'route_wrong_package',
      'route_wrong_certificate',
      'matrix_correct_identity',
    ]) {
      if (checks.isNotEmpty) await Future<void>.delayed(pause);
      final row = await _check(check);
      checks.add(row);
      if (row['passed'] != true) {
        passed = false;
        break; // No retries or extra calls after any failed qualification.
      }
    }
    return {
      'passed': passed,
      'requests_started': checks.length,
      'route_requests_started': checks
          .where((row) => row['operation'] == 'computeRoutes')
          .length,
      'matrix_elements_requested': checks
          .where((row) => row['operation'] == 'computeRouteMatrix')
          .length,
      'checks': checks,
    };
  }

  Future<Map<String, Object?>> _check(String check) async {
    final matrix = check == 'matrix_correct_identity';
    final wrongPackage = check == 'route_wrong_package';
    final wrongCertificate = check == 'route_wrong_certificate';
    final expectsRejection = wrongPackage || wrongCertificate;
    final watch = Stopwatch()..start();
    final row = <String, Object?>{
      'check': check,
      'operation': matrix ? 'computeRouteMatrix' : 'computeRoutes',
      'passed': false,
    };
    try {
      final response = await client
          .post(
            Uri.https(
              'routes.googleapis.com',
              matrix
                  ? '/distanceMatrix/v2:computeRouteMatrix'
                  : '/directions/v2:computeRoutes',
            ),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': apiKey,
              'X-Android-Package': wrongPackage
                  ? '$packageName.rejected'
                  : packageName,
              'X-Android-Cert': wrongCertificate
                  ? (certificate == '0' * 40 ? '1' * 40 : '0' * 40)
                  : certificate,
              'X-Goog-FieldMask': matrix
                  ? 'originIndex,destinationIndex,status,condition,distanceMeters,duration'
                  : 'routes.duration,routes.distanceMeters',
            },
            body: jsonEncode({
              if (matrix) ...{
                'origins': [
                  {'waypoint': _origin},
                ],
                'destinations': [
                  {'waypoint': _destination},
                ],
              } else ...{
                'origin': _origin,
                'destination': _destination,
              },
              'travelMode': 'DRIVE',
              'routingPreference': 'TRAFFIC_AWARE',
            }),
          )
          .timeout(timeout);
      row['http_status'] = response.statusCode;
      final Object? decoded = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final reason = _errorReason(decoded);
        row['reason'] = reason;
        // A generic service/key/billing denial doesn't prove app enforcement.
        row['passed'] =
            expectsRejection &&
            response.statusCode == 403 &&
            reason == 'API_KEY_ANDROID_APP_BLOCKED';
      } else {
        row['passed'] = !expectsRejection && _hasRoute(decoded, matrix);
        row['reason'] = expectsRejection
            ? 'incorrect_identity_accepted'
            : row['passed'] == true
            ? 'usable_route'
            : 'unusable_response';
      }
    } catch (_) {
      // Exceptions can contain credentials, URLs, or upstream response bodies.
      row['reason'] = 'transport_timeout_or_invalid_response';
    }
    row['milliseconds'] = watch.elapsedMilliseconds;
    return row;
  }

  static bool _hasRoute(Object? value, bool matrix) {
    Object? first;
    if (matrix && value is List && value.length == 1) {
      first = value.first;
    } else if (!matrix && value is Map) {
      final routes = value['routes'];
      if (routes is List && routes.isNotEmpty) first = routes.first;
    }
    if (first is! Map || (matrix && first['condition'] != 'ROUTE_EXISTS')) {
      return false;
    }
    final distance = first['distanceMeters'];
    final duration = first['duration'];
    return distance is int &&
        distance >= 0 &&
        duration is String &&
        RegExp(r'^\d+(\.\d+)?s$').hasMatch(duration);
  }

  static String _errorReason(Object? value) {
    if (value is Map && value['error'] is Map) {
      final details = (value['error'] as Map)['details'];
      if (details is List) {
        for (final detail in details) {
          if (detail is Map &&
              detail['@type'] == 'type.googleapis.com/google.rpc.ErrorInfo') {
            final reason = detail['reason'];
            if (reason is String &&
                RegExp(r'^[A-Z][A-Z0-9_]{0,99}$').hasMatch(reason)) {
              return reason;
            }
          }
        }
      }
    }
    return 'upstream_denial';
  }
}
