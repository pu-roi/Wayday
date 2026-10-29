// Explicit, bounded live qualification only. Never run from flutter test.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'google_routes_probe.dart';

Future<void> main(List<String> args) async {
  if (!args.contains('--live') ||
      !args.any((arg) => arg.startsWith('--sha1='))) {
    stdout.writeln(
      'Usage from apps/mobile: dart run tool/qualify_google_routes.dart '
      '--live --sha1=<debug-certificate-SHA1>\n'
      'Consumes up to three Compute Routes starts and one matrix element. '
      'Stops on the first failure. Never pass a key on the command line.',
    );
    exitCode = 64;
    return;
  }
  final certificate = args
      .firstWhere((arg) => arg.startsWith('--sha1='))
      .substring('--sha1='.length);
  final environment = File('../../.env.local');
  var apiKey = '';
  if (await environment.exists()) {
    for (final line in await environment.readAsLines()) {
      final match = RegExp(
        r'''^\s*GOOGLE_ROUTES_API_KEY\s*=\s*(.*?)\s*$''',
      ).firstMatch(line);
      if (match != null) {
        apiKey = match[1]!.replaceAll(RegExp('^["\']|["\']\$'), '');
      }
    }
  }
  if (apiKey.isEmpty ||
      !RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(certificate.replaceAll(':', ''))) {
    stderr.writeln('Missing Routes key or valid signing fingerprint.');
    exitCode = 64;
    return;
  }
  final client = http.Client();
  try {
    final checkedAt = DateTime.now().toUtc();
    final report = <String, Object?>{
      'checked_at_utc': checkedAt.toIso8601String(),
      'sample': 'SM Megamall to Shangri-La Plaza, Mandaluyong',
      'scope': 'DRIVE with TRAFFIC_AWARE; no polyline or navigation request',
      ...await GoogleRoutesProbe(
        client,
        apiKey: apiKey,
        packageName: 'dev.wayday.wayday',
        certificate: certificate,
      ).run(),
    };
    final manilaDay = checkedAt
        .add(const Duration(hours: 8))
        .toIso8601String()
        .substring(0, 10);
    final reportBase =
        '../../docs/wayday/evidence/google-routes-qualification-$manilaDay';
    var output = File('$reportBase.json');
    if (await output.exists()) {
      output = File('$reportBase-${checkedAt.microsecondsSinceEpoch}.json');
    }
    await output.writeAsString(
      '${const JsonEncoder.withIndent('  ').convert(report)}\n',
    );
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
    if (report['passed'] != true) exitCode = 1;
  } finally {
    client.close();
  }
}
