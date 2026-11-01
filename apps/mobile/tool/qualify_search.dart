// Deliberate live qualification only. Never run from the automated test suite.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/domain/place_search.dart';

Future<void> main() async {
  final keys = <String, String>{};
  final environment = File('../../.env.local');
  if (await environment.exists()) {
    for (final line in await environment.readAsLines()) {
      final match = RegExp(
        r'^\s*(GEOAPIFY_API_KEY|LOCATIONIQ_API_KEY)\s*=\s*(.*?)\s*$',
      ).firstMatch(line);
      if (match != null) keys[match[1]!] = match[2]!;
    }
  }
  final client = http.Client();
  final adapters = [
    HttpSearchAdapter(
      client,
      'geoapify',
      apiKey: keys['GEOAPIFY_API_KEY'] ?? '',
    ),
    HttpSearchAdapter(
      client,
      'locationiq',
      apiKey: keys['LOCATIONIQ_API_KEY'] ?? '',
    ),
    HttpSearchAdapter(client, 'photon'),
  ];
  final samples = <String, SearchArea>{
    'Taft Avenue Manila': const SearchArea(14.56, 120.99, 13),
    'SM Megamall': const SearchArea(14.585, 121.057, 13),
    'Jollibee Cubao': const SearchArea(14.62, 121.05, 13),
    'Carbon Public Market Cebu': const SearchArea(10.292, 123.898, 13),
    'Osmena Boulevard Cebu': const SearchArea(10.31, 123.895, 13),
    'Metro Supermarket Colon Cebu': const SearchArea(10.296, 123.899, 13),
    'Larsian Cebu': const SearchArea(10.309, 123.891, 13),
    'Bankerohan Public Market Davao': const SearchArea(7.066, 125.602, 13),
    'San Pedro Street Davao': const SearchArea(7.064, 125.609, 13),
    'Gaisano Mall Davao': const SearchArea(7.081, 125.613, 13),
    'Jollibee Davao': const SearchArea(7.07, 125.61, 13),
    'Pasig Mega Market': const SearchArea(14.559, 121.082, 13),
  };
  final rows = <Map<String, Object?>>[];
  final disabled = <String>{};
  try {
    for (final sample in samples.entries) {
      for (final adapter in adapters) {
        if (!adapter.enabled || disabled.contains(adapter.id)) continue;
        final watch = Stopwatch()..start();
        try {
          final results = await adapter.search(
            PlaceSearchRequest(sample.key, area: sample.value),
          );
          rows.add({
            'query': sample.key,
            'provider': adapter.id,
            'milliseconds': watch.elapsedMilliseconds,
            'status': 'ok',
            'candidates': [
              for (final r in results)
                {
                  'name': r.name,
                  'address': r.address,
                  'source': r.sourceId,
                  'latitude': r.latitude,
                  'longitude': r.longitude,
                },
            ],
          });
        } on SearchFailure catch (error) {
          rows.add({
            'query': sample.key,
            'provider': adapter.id,
            'status': error.kind.name,
          });
          if (error.kind == SearchFailureKind.access ||
              error.kind == SearchFailureKind.rate ||
              error.kind == SearchFailureKind.daily) {
            disabled.add(adapter.id);
          }
        } catch (_) {
          rows.add({
            'query': sample.key,
            'provider': adapter.id,
            'status': 'unavailable',
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }
    for (final area in [
      samples['Pasig Mega Market']!,
      samples['Carbon Public Market Cebu']!,
      samples['Bankerohan Public Market Davao']!,
    ]) {
      for (final adapter in adapters.where(
        (a) => a.categories && a.enabled && !disabled.contains(a.id),
      )) {
        try {
          final results = await adapter.search(
            PlaceSearchRequest(
              'palengke',
              category: SearchCategory.marketplace,
              area: area,
            ),
          );
          rows.add({
            'query': 'marketplace',
            'area': '${area.latitude},${area.longitude}',
            'provider': adapter.id,
            'status': 'ok',
            'candidates': [
              for (final r in results) {'name': r.name, 'source': r.sourceId},
            ],
          });
        } on SearchFailure catch (error) {
          rows.add({
            'query': 'marketplace',
            'provider': adapter.id,
            'status': error.kind.name,
          });
        }
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
    }
  } finally {
    client.close();
  }
  final output = File(
    '../../docs/wayday/evidence/search-qualification-2026-10-28.json',
  );
  await output.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert({'date': DateTime.now().toUtc().toIso8601String(), 'method': 'Fixed public-place sample; returned candidates are not field-verified. No dashboard access. Count reflects qualification runner calls only.', 'requests': rows.length, 'results': rows})}\n',
  );
  stdout.writeln(
    'Qualification finished: ${rows.length} requests. Sanitized results saved in docs/wayday/evidence/search-qualification-2026-10-28.json.',
  );
}
