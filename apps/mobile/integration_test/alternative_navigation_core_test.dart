import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/alternative_route_test.dart' show route;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('navigation core initializes beside the pinned OpenGL renderer', (
    tester,
  ) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity!['package'], endsWith('.maptest'));
    for (var i = 0; i < 3; i++) {
      final result = await const MethodChannel(
        'wayday/alternative_navigation',
      ).invokeMapMethod<String, String>('initializeFixture');
      expect(result, {'core': '5.0.0', 'renderer': 'opengl-13.7.1'});
    }
    final progress = await const MethodChannel('wayday/alternative_navigation')
        .invokeMapMethod<String, dynamic>('guidanceFixture', {
          'leg': (route()['legs'] as List).single,
        });
    expect(progress!['legs'], 1);
    expect(progress['steps'], 2);
    expect(progress['firstDistance'], closeTo(154.769, .1));
    expect(progress['distance'], inInclusiveRange(0, 25));
    expect(progress['samples'], greaterThanOrEqualTo(2));
  });
}
