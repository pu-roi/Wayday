import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/trip_view.dart';
import '../test/trip_navigation_test.dart' show FakeNavigationDriver;
import '../test/trip_session_test.dart'
    show FakeTripMap, tripSession, tripFixture;

/// Android UI/Back/progress fixture: no real navigator, GPS or paid requests.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android compact checklist keeps manual progress across Back', (
    tester,
  ) async {
    final identity = await const MethodChannel(
      'wayday/planning',
    ).invokeMapMethod<String, String>('identity');
    expect(identity!['package'], endsWith('.maptest'));
    var saved = tripFixture();
    final driver = FakeNavigationDriver();
    void open(BuildContext context) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TripView(
            initial: saved,
            session: tripSession(
              driver,
              plan: saved,
              save: (value) async => saved = value,
            ),
            mapBuilder: (_, ready, position) {
              ready(FakeTripMap());
              return const ColoredBox(
                color: Color(0xffe5f0f9),
                child: Center(child: Text('Synthetic navigation viewport')),
              );
            },
          ),
        ),
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => open(context),
                  child: const Text('Open trip'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open trip'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsOneWidget);
    await tester.tap(find.text('Grocery'));
    await tester.pumpAndSettle();
    expect(saved.completed, {'a'});
    expect(driver.advances, 0);
    await tester.tap(
      find.text('Eat pares kasama ang girlfriend ko pagkatapos mamili'),
    );
    await tester.pumpAndSettle();
    expect(saved.completed, {'a', 'b'});
    expect(driver.advances, 1);
    expect(find.text('Finish trip'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open trip'), findsOneWidget);
    await tester.tap(find.text('Open trip'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Final destination'), findsOneWidget);
    await tester.tap(find.text('Finish trip'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    debugPrint('WAYDAY_COMPACT_NAVIGATION_FIXTURE_PASSED');
  });
}
