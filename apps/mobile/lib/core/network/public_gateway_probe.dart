import 'dart:convert';
import 'dart:math';
import 'gateway_client.dart';

enum GatewayProbeResult { verified, verifiedWithoutBudget, denied, unavailable }

/// A read-only preflight: never reserves funds or dispatches provider work.
class PublicGatewayProbe {
  PublicGatewayProbe(this.gateway);
  final GatewayClient gateway;

  Future<GatewayProbeResult> check() async {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
    try {
      final response = await gateway.post('/v1/usage/check', {
        'requestId': id,
        'sku': 'routes_preflight',
        'units': 1,
      });
      if (response.statusCode == 401 || response.statusCode == 403) {
        return GatewayProbeResult.denied;
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return GatewayProbeResult.unavailable;
      if (response.statusCode == 200 && body.isEmpty) {
        return GatewayProbeResult.verified;
      }
      if (response.statusCode == 429 &&
          body['error'] is Map &&
          body['error']['code'] == 'testing_budget') {
        return GatewayProbeResult.verifiedWithoutBudget;
      }
    } catch (_) {
      // Do not expose tokens, SDK exception messages or upstream response text.
    }
    return GatewayProbeResult.unavailable;
  }
}
