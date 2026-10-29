import 'package:wayday/features/places/data/google_search.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/presentation/place_search_panel.dart';

/// Uses real Android permission/IME surfaces, public fixture coordinates and
/// transport fixtures. Run only through the separate .maptest application.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native permission, fresh search and keyboard preserve the draft', (
    tester,
  ) async {
    var fixes = 0;
    PlaceMapRequest? map;
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'features': [
            for (final row in [
              (1, 'McDonald’s Far', 14.7),
              (2, 'McDonald’s Nearby', 14.581),
            ])
              {
                'properties': {
                  'name': row.$2,
                  'countrycode': 'PH',
                  'osm_type': 'N',
                  'osm_id': row.$1,
                },
                'geometry': {
                  'type': 'Point',
                  'coordinates': [121.05, row.$3],
                },
              },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
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
          searchSourceChoiceProvider.overrideWithValue(SearchSourceChoice()..choose(SearchSource.others)),
          combinedPlaceSearchProvider.overrideWithValue(service),
          // The OS permission adapter remains real; GPS is deterministic and private
          // device coordinates are never read or recorded by this harness.
          locationReaderProvider.overrideWithValue(() async {
            fixes++;
            return const LocationFix(14.58, 121.05, 30);
          }),
          placeMapBuilderProvider.overrideWithValue((r) {
            map = r;
            return const Center(child: Text('Fixture map'));
          }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const OnlinePinPicker(initial: null),
        ),
      ),
    );

    Future<void> waitFor(bool Function() condition, String description) async {
        final deadline = DateTime.now().add(const Duration(seconds: 90));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 150));
        if (condition()) return;
      }
      fail('Timed out: $description');
    }

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('place-name')),
    );
    field.controller!.text = "McDonald's";
    await tester.tap(find.byKey(const Key('place-name')));
    await tester.pump(const Duration(seconds: 2));
    expect(fixes, 0);
    expect(find.text('Philippines'), findsOneWidget);
    debugPrint('WAYDAY_LOCATION_DENY_READY');
    await tester.tap(find.widgetWithText(TextButton, 'Use my location'));
    await waitFor(
      () => find
          .textContaining('Location permission is unavailable')
          .evaluate()
          .isNotEmpty,
      'deny dialog',
    );
    expect(field.controller!.text, "McDonald's");
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(fixes, 0);
    debugPrint('WAYDAY_LOCATION_ALLOW_READY');
    await tester.tap(find.widgetWithText(TextButton, 'Use my location'));
    await waitFor(
      () => fixes == 1 && find.text('Near me').evaluate().isNotEmpty,
      'allow dialog',
    );
    await waitFor(
      () => tester
          .widget<PlaceSearchPanel>(find.byType(PlaceSearchPanel))
          .search
          .results
          .isNotEmpty,
      'fixture search completion',
    );
    expect(map!.focus, isNull);
    expect(map!.focusRevision, 0);
    final near = find.text('McDonald’s Nearby'),
        far = find.text('McDonald’s Far');
    expect(
      tester
          .widget<PlaceSearchPanel>(find.byType(PlaceSearchPanel))
          .search
          .results
          .first
          .sourceId,
      'osm/node/2',
    );
    await tester.scrollUntilVisible(
      near,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.scrollUntilVisible(
      far,
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getTopLeft(near).dy, lessThan(tester.getTopLeft(far).dy));
    expect(field.controller!.text, "McDonald's");
    debugPrint('WAYDAY_LOCATION_PERMISSION_PASSED');

    // Establish a new native editor connection after the system dialog. This
    // also makes the keyboard check independent of the IME's restore policy.
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pump();
    await tester.tap(find.byKey(const Key('place-name')));
    await waitFor(() => tester.view.viewInsets.bottom > 0, 'keyboard open');
    debugPrint('WAYDAY_LOCATION_BACK_READY');
    await waitFor(() => tester.view.viewInsets.bottom == 0, 'hardware Back');
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(field.controller!.text, "McDonald's");
    await tester.tap(find.byKey(const Key('place-name')));
    await waitFor(() => tester.view.viewInsets.bottom > 0, 'keyboard reopen');
    debugPrint('WAYDAY_LOCATION_IME_CLOSE_READY');
    await waitFor(
      () => tester.view.viewInsets.bottom == 0,
      'keyboard close button',
    );
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    expect(fixes, 1);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('place-name')));
    await waitFor(() => fixes == 2, 'fresh location on search reopen');
    expect(field.controller!.text, "McDonald's");
    expect(find.byKey(const Key('place-search-results')), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    debugPrint('WAYDAY_LOCATION_NATIVE_PASSED');
  });
}
