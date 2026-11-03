import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/core/widgets/place_picker.dart';
import 'package:wayday/features/maps/presentation/map_platform.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_quota.dart';

void main() {
  testWidgets(
    'unavailable map preserves label saving and Back cancellation at large text',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapPlatformSupportedProvider.overrideWithValue(true),
            placeMapBuilderProvider.overrideWithValue(
              (_) => const Text('Online map unavailable'),
            ),
            searchSourceChoiceProvider.overrideWithValue(
              SearchSourceChoice()..choose(SearchSource.others),
            ),
            combinedPlaceSearchProvider.overrideWithValue(
              CombinedPlaceSearch(
                [],
                QuotaLedger(read: () async => null, write: (_) async {}),
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.5),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () async {
                        result = (await choosePlace(
                          context,
                          title: 'From',
                          initial: 'Original',
                        ))?.label;
                      },
                      child: const Text('Choose'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('place-name')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byKey(const Key('place-name')), 'Changed');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('place-name')),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Original'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('place-name')),
        'Manual place',
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Use name only'),
        150,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('place-search-results')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Use name only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm location'));
      await tester.pumpAndSettle();
      expect(result, 'Manual place');
      expect(tester.takeException(), isNull);
    },
  );
}
