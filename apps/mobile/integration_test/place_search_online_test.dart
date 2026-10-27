import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:wayday/features/places/data/philippine_place_search.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('online Philippine search returns Cebu on Android', (tester) async {
    final client = http.Client();
    try {
      final results = await PhilippinePlaceSearch(client, Uri.parse('https://photon.komoot.io/api/')).search('Cebu');
      expect(results, isNotEmpty);
      expect(results.first.latitude, inInclusiveRange(-90, 90));
      expect(results.first.longitude, inInclusiveRange(-180, 180));
    } finally {
      client.close();
    }
  });
}
