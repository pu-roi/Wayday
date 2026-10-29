import 'package:wayday/features/places/data/google_search.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import '../test/support/fake_location.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native IME and hardware Back preserve the location search session', (
    tester,
  ) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'features': [
            {
              'properties': {
                'name': 'Fixture Cebu',
                'countrycode': 'PH',
                'osm_type': 'N',
                'osm_id': 1,
                'street': 'Colon Street',
                'city': 'Cebu City',
                'state': 'Central Visayas',
                'country': 'Philippines',
              },
              'geometry': {
                'type': 'Point',
                'coordinates': [123.9, 10.3],
              },
            },
          ],
        }),
        200,
      ),
    );
    final service = CombinedPlaceSearch([
      HttpSearchAdapter(client, 'photon', endpoint: 'https://example.test'),
    ], QuotaLedger(read: () async => null, write: (_) async {}));
    addTearDown(() {
      service.dispose();
      client.close();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPlatformProvider.overrideWithValue(FakeLocationPlatform()),
          searchSourceChoiceProvider.overrideWithValue(
            SearchSourceChoice()..choose(SearchSource.others),
          ),
          combinedPlaceSearchProvider.overrideWithValue(service),
          placeMapBuilderProvider.overrideWithValue(
            (_) => const Center(child: Text('Fixture map')),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const OnlinePinPicker(
                      initial: null,
                      title: 'Starting point',
                    ),
                  ),
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    Future<void> waitKeyboard(bool visible) async {
      final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 150));
        // Scaffold removes insets from the body's MediaQuery after resizing it.
        final inset = tester.view.viewInsets.bottom;
        if ((inset > 0) == visible) return;
      }
      fail('Native keyboard visibility did not become $visible');
    }

    // Set the draft directly, then focus through the real TextInput connection.
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('place-name')),
    );
    field.controller!.text = 'Cebu';
    await tester.tap(find.byKey(const Key('place-name')));
    await waitKeyboard(true);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Fixture Cebu'), findsOneWidget);
    debugPrint('WAYDAY_KEYBOARD_HARDWARE_BACK_READY');
    // The host sends one real ADB Back event only while the isolated test is foreground.
    await waitKeyboard(false);
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(field.controller!.text, 'Cebu');
    expect(find.text('Fixture Cebu'), findsOneWidget);
    debugPrint('WAYDAY_KEYBOARD_HARDWARE_BACK_PASSED');
    await tester.pump(const Duration(seconds: 3));
    await tester.scrollUntilVisible(
      find.text('Back to map'),
      100,
      scrollable: find.descendant(
        of: find.byKey(const Key('place-search-results')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Back to map').hitTestable(), findsOneWidget);
    expect(find.text('Use name only'), findsOneWidget);
    debugPrint('WAYDAY_KEYBOARD_BOTTOM_ACTIONS_READY');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byKey(const Key('place-name')));
    await waitKeyboard(true);
    debugPrint('WAYDAY_KEYBOARD_NATIVE_DISMISS_READY');
    // The host/user taps the actual keyboard close control.
    await waitKeyboard(false);
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(field.controller!.text, 'Cebu');
    expect(find.text('Fixture Cebu'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('place-search-results')), findsNothing);
    expect(field.controller!.text, 'Cebu');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Open picker'), findsOneWidget);
    debugPrint('WAYDAY_KEYBOARD_NATIVE_CHECK_PASSED');
  });
}
