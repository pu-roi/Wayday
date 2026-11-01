import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// App attestation is acquired only for a requested operation. No HTTP retry.
class GatewayClient {
  GatewayClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment('WAYDAY_GATEWAY_URL'),
    Future<String> Function()? token,
  }) : client = client ?? http.Client(),
       token = token ?? _nativeToken;
  static const enabled = bool.fromEnvironment('WAYDAY_PUBLIC_BUILD');
  static final shared = GatewayClient();
  final http.Client client;
  final String baseUrl;
  final Future<String> Function() token;

  static Future<String> _nativeToken() async =>
      (await const MethodChannel(
        'wayday/gateway',
      ).invokeMethod<String>('token')) ??
      '';

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment ||
        !{'', '/'}.contains(base.path) ||
        !path.startsWith('/v1/')) {
      throw const FormatException('Public service is not configured.');
    }
    final proof = await token().timeout(const Duration(seconds: 12));
    if (proof.isEmpty) {
      throw const FormatException('App verification is unavailable.');
    }
    final request = http.Request('POST', base.resolve(path))
      ..followRedirects = false
      ..headers.addAll({
        'Content-Type': 'application/json',
        'X-Firebase-AppCheck': proof,
      })
      ..body = jsonEncode(body);
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > 1500000) {
        throw const FormatException('Service response is too large.');
      }
      bytes.addAll(chunk);
    }
    return http.Response.bytes(
      bytes,
      response.statusCode,
      headers: response.headers,
    );
  }
}
