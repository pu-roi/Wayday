import 'package:wayday/features/places/data/google_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'place_search_controller_test.dart' show TestAdapter, TestLedger;
import 'search_ranking_test.dart' show place;
import 'support/fake_location.dart';

void main() {
  testWidgets(
    'contextual opt-in preserves draft/query; reopening gets a fresh fix without another prompt',
    (tester) async {
      final platform = FakeLocationPlatform(access: LocationAccess.denied);
      final clock = tester.binding.clock.now;
      final requests = <PlaceSearchRequest>[];
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (r) async {
            requests.add(r);
            return [place('mall', 'SM Megamall', 14.6)];
          }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      addTearDown(service.dispose);
      PlaceMapRequest? map;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
          searchSourceChoiceProvider.overrideWithValue(SearchSourceChoice()..choose(SearchSource.others)),
            locationPlatformProvider.overrideWithValue(platform),
            combinedPlaceSearchProvider.overrideWithValue(service),
            placeMapBuilderProvider.overrideWithValue((r) {
              map = r;
              return const SizedBox();
            }),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: const OnlinePinPicker(initial: null),
          ),
        ),
      );
      expect(platform.checks, 0);
      await tester.enterText(find.byKey(const Key('place-name')), 'Megamall');
      await tester.pump(const Duration(seconds: 1));
      expect(platform.prompts, 0);
      expect(platform.acquisitions, 0);
      expect(find.text('Philippines'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Use my location'));
      await tester.pumpAndSettle();
      expect(platform.prompts, 1);
      expect(platform.acquisitions, 1);
      expect(find.byKey(const Key('place-search-results')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Megamall',
      );
      expect(map!.focus, isNull);
      expect(map!.focusRevision, 0);
      expect(find.text('Near me'), findsWidgets);
      map!.onViewportChanged!(10.3, 123.9, 14);
      final before = requests.length;
      await tester.pump(const Duration(seconds: 2));
      expect(requests.length, before);
      await tester.tap(find.widgetWithText(TextButton, 'Search this area'));
      await tester.pumpAndSettle();
      expect(find.text('This map area'), findsOneWidget);
      expect(requests.last.origin!.kind, SearchOriginKind.map);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('place-name')));
      await tester.pumpAndSettle();
      expect(platform.prompts, 1);
      expect(platform.acquisitions, 2);
      expect(find.text('This map area'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('place-name')), 'SM');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Search this area'));
      await tester.pumpAndSettle();
      expect(requests.last.text, 'SM');
      expect(requests.last.origin!.kind, SearchOriginKind.map);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
    },
  );
}
