import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/map_selection_test.dart' as selection;
import '../test/place_quality_discovery_test.dart' as discovery;
import '../test/place_ranking_test.dart' as ranking;
import '../test/today_date_lifecycle_test.dart' as dates;

/// Mocked provider/road work on the disposable package; no personal data or paid calls.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('disposable native bridge exposes enriched metadata profile', (
    tester,
  ) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity!['package'], endsWith('.maptest'));
    final status = await const MethodChannel(
      'wayday/recommendations',
    ).invokeMapMethod<String, Object?>('status');
    expect(status!['metadataVersion'], 2);
  });
  selection.main();
  discovery.main();
  ranking.main();
  dates.main();
}
