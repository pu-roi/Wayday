import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/place_hours.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import '../test/helpers/planning_fixtures.dart';
import '../test/business_hours_widget_test.dart' show HoursMetadata, business;

/// Guarded disposable fixture only: no search, road or Gemini requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android business-hours profile and disclosed weekly hours', (
    tester,
  ) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity!['package'], endsWith('.maptest'));
    final status = await const MethodChannel(
      'wayday/recommendations',
    ).invokeMapMethod<String, Object?>('status');
    expect(status!['bridgeVersion'], 3);
    final source = HoursMetadata(), roads = Roads();
    addTearDown(roads.client.close);
    final model = PlanningController(
      fixture(),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
      discovery: source,
    );
    addTearDown(model.dispose);
    source.hours = BusinessHours(
      version: 1,
      offset: 480,
      checkedAt: DateTime.now(),
      regular: {
        'periods': [
          for (var d = 0; d < 7; d++)
            {
              'open': {'day': d, 'hour': 8, 'minute': 0},
              'close': {'day': d, 'hour': 21, 'minute': 0},
            },
        ],
        'weekdays': ['Synthetic weekly hours: 8 AM–9 PM'],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlaceHours(model: model, place: business),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Usual hours for'), findsOneWidget);
    expect(find.textContaining('Expected open'), findsNothing);
    await tester.tap(find.text('Weekly hours'));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic weekly hours: 8 AM–9 PM'), findsOneWidget);
    source.hours = BusinessHours(version: 1, checkedAt: DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: Scaffold(
          body: PlaceHours(
            key: const ValueKey('unknown'),
            model: model,
            place: business,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Hours not provided by Google Maps'), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugPrint('WAYDAY_BUSINESS_HOURS_FIXTURE_PASSED');
  });
}
