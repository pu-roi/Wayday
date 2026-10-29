import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/presentation/place_search_panel.dart';
import 'package:wayday/features/places/presentation/google_search_view.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/data/google_search.dart';

class FixtureOtherSearch extends SearchAdapter {
  @override
  String get id => 'geoapify';
  @override
  String get endpoint => 'https://fixture.invalid';
  @override
  bool get enabled => true;
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) async => [
    const PlaceSearchResult(
      name: 'Fixture result',
      latitude: 14.58,
      longitude: 121.05,
      sourceId: 'fixture-only',
    ),
  ];
}

class PublicFixtureLocation extends LocationPlatform {
  @override
  Future<bool> servicesEnabled() async => true;
  @override
  Future<LocationAccess> checkPermission() async => LocationAccess.allowed;
  @override
  Future<LocationAccess> requestPermission() async => LocationAccess.allowed;
  @override
  Future<LocationFix> acquire() async =>
      LocationFix(14.58, 121.05, 20, acquiredAt: DateTime.now());
  @override
  Future<void> openSettings({required bool services}) async {}
}

/// Run only with WAYDAY_MAP_TEST=true. The SDK key must authorize this exact
/// package/certificate. No real device location, names, addresses or IDs are logged.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized()
          .shouldPropagateDevicePointerEvents =
      true;
  testWidgets('standard Google cards, metadata, keyboard and bounded PH sample', (
    tester,
  ) async {
    PlaceIntent? committed;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          combinedPlaceSearchProvider.overrideWith((ref) {
            final service = CombinedPlaceSearch([
              FixtureOtherSearch(),
            ], ref.read(searchQuotaLedgerProvider));
            ref.onDispose(service.dispose);
            return service;
          }),
          locationPlatformProvider.overrideWithValue(PublicFixtureLocation()),
          if (!const bool.fromEnvironment('WAYDAY_GOOGLE_REAL_MAP'))
            placeMapBuilderProvider.overrideWithValue((request) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => request.onViewportChanged?.call(14.58, 121.05, 14),
              );
              return const Center(child: Text('Fixture map'));
            }),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    committed = await Navigator.of(context).push<PlaceIntent>(
                      MaterialPageRoute(
                        builder: (_) => const OnlinePinPicker(
                          initial: null,
                          title: 'Starting point',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open isolated picker'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open isolated picker'));
    await tester.pumpAndSettle();
    final finder = find.byKey(const Key('place-name'));
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 500));
    final field = tester.widget<TextFormField>(finder);
    final controller = tester
        .widget<PlaceSearchPanel>(find.byType(PlaceSearchPanel))
        .search;
    MethodChannel currentChannel() => MethodChannel(
      'wayday/google_places/${tester.state<GoogleSearchViewState>(find.byType(GoogleSearchView)).nativeViewId}',
    );
    final sample = <(String, String)>[
      ('Megamall', 'SM Megamall'),
      ('McDo', "McDonald's"),
      ('mcdonals', "McDonald's"),
      ('jolibee Cebu', 'Jollibee'),
      ('Colon Street Cebu', 'Colon'),
      ('Mercury Drug Davao', 'Mercury'),
      ('Carbon Market Cebu', 'Carbon'),
      ('sari-sari store', ''),
    ];
    for (final row in sample) {
      field.controller!.text = row.$1;
      controller.change(row.$1);
      if (row.$1 == 'sari-sari store') {
        controller.chooseCategory(SearchCategory.convenience);
      } else {
        controller.submit();
      }
      final deadline = DateTime.now().add(const Duration(seconds: 12));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 150));
        if (controller.searched) break;
      }
      if (const bool.fromEnvironment('WAYDAY_GOOGLE_EXPECT_UNAVAILABLE')) {
        expect(controller.failed, isTrue);
        expect(field.controller!.text, 'Megamall');
        expect(find.text('Other sources'), findsOneWidget);
        await tester.tap(find.byTooltip('Close search'));
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm location'),
              )
              .onPressed,
          isNull,
        );
        debugPrint('WAYDAY_GOOGLE_MISSING_SERVICES_FALLBACK_PASSED');
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        return;
      }
      expect(
        controller.failed,
        isFalse,
        reason:
            'Google source must work for the isolated test identity before continuing.',
      );
      final metadata = await currentChannel().invokeMapMethod<String, Object?>(
        'qualify',
        {'expected': row.$2},
      );
      debugPrint(
        'WAYDAY_GOOGLE_SAMPLE ${jsonEncode({'query': row.$1, ...?metadata})}',
      );
      expect(metadata?['count'], greaterThan(0));
      expect(metadata?['idPresent'], isTrue);
      if (row.$1 == 'Megamall') {
        final nativeBeforeKeyboard = tester.state<GoogleSearchViewState>(
          find.byType(GoogleSearchView),
        );
        final originalChannel = currentChannel();
        for (var i = 0; i < 10; i++) {
          controller.chooseSource(SearchSource.others);
          await tester.pump(const Duration(milliseconds: 150));
          final hidden = await originalChannel.invokeMapMethod<String, Object?>(
            'qualify',
            <String, Object?>{},
          );
          expect(hidden?['visible'], isFalse);
          expect(hidden?['hiddenFromAccessibility'], isTrue);
          controller.chooseSource(SearchSource.google);
          await tester.pump(const Duration(milliseconds: 150));
          expect(
            tester.state(find.byType(GoogleSearchView)),
            same(nativeBeforeKeyboard),
          );
        }
        final retained = await currentChannel()
            .invokeMapMethod<String, Object?>('qualify', <String, Object?>{});
        expect(retained?['bindings'], metadata?['bindings']);
        expect(retained?['count'], metadata?['count']);
        expect(retained?['visible'], isTrue);
        debugPrint(
          'WAYDAY_SOURCE_RETENTION_PASSED switches=10 bindings=${retained?['bindings']}',
        );
        await tester.tap(finder);
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
        final keyboardDeadline = DateTime.now().add(const Duration(seconds: 8));
        while (tester.view.viewInsets.bottom == 0 &&
            DateTime.now().isBefore(keyboardDeadline)) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.view.viewInsets.bottom, greaterThan(0));
        debugPrint('WAYDAY_GOOGLE_IME_READY');
        final hideDeadline = DateTime.now().add(const Duration(seconds: 45));
        while (tester.view.viewInsets.bottom > 0 &&
            DateTime.now().isBefore(hideDeadline)) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.pumpAndSettle();
        expect(find.byType(PlaceSearchPanel), findsOneWidget);
        expect(field.controller!.text, 'Megamall');
        expect(tester.view.viewInsets.bottom, 0);
        expect(
          tester.state<GoogleSearchViewState>(find.byType(GoogleSearchView)),
          same(nativeBeforeKeyboard),
        );
        expect(find.byTooltip('Search options'), findsNothing);
        expect(find.text('Places'), findsNothing);
        expect(find.text('Search this area'), findsOneWidget);
        expect(find.text('Saves this name without a map pin.'), findsOneWidget);
        debugPrint('WAYDAY_GOOGLE_RESTORED_LAYOUT_READY');
        await tester.pump(const Duration(seconds: 3));
        // Flutter-dispatched Back also preserves search after the IME has hidden.
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.byType(PlaceSearchPanel), findsOneWidget);
        expect(field.controller!.text, 'Megamall');
        debugPrint('WAYDAY_GOOGLE_TAP_CARD_READY');
        await tester.tapAt(
          tester.getTopLeft(find.byType(GoogleSearchView)) +
              const Offset(32, 72),
        );
        final tapDeadline = DateTime.now().add(const Duration(seconds: 45));
        while (find.byType(PlaceSearchPanel).evaluate().isNotEmpty &&
            controller.googleMessage == null &&
            DateTime.now().isBefore(tapDeadline)) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        final resolvedDeadline = DateTime.now().add(
          const Duration(seconds: 10),
        );
        while (find.byType(PlaceSearchPanel).evaluate().isNotEmpty &&
            controller.googleMessage == null &&
            DateTime.now().isBefore(resolvedDeadline)) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        if (find.byType(PlaceSearchPanel).evaluate().isNotEmpty) {
          final details = await currentChannel()
              .invokeMapMethod<String, Object?>('qualify', <String, Object?>{});
          debugPrint('WAYDAY_GOOGLE_DETAILS_METADATA ${jsonEncode(details)}');
          expect(controller.googleMessage, contains('could not be verified'));
          await tester.tap(find.byTooltip('Close search'));
          await tester.pump();
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Confirm location'),
                )
                .onPressed,
            isNull,
          );
          expect(field.controller!.text, 'Megamall');
          debugPrint('WAYDAY_GOOGLE_COUNTRY_GATE_BLOCKED_SAFELY');
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          return;
        }
        expect(find.text('Your label'), findsOneWidget);
        debugPrint('WAYDAY_GOOGLE_NATIVE_SELECTION_VALIDATED');
        if (const bool.fromEnvironment('WAYDAY_GOOGLE_SINGLE_SAMPLE')) {
          await tester.tap(
            find.widgetWithText(FilledButton, 'Confirm location'),
          );
          await tester.pumpAndSettle();
          expect(committed?.provider, 'google_ui_kit');
          expect(committed?.label, 'Megamall');
          expect(committed?.hasCoordinates, isTrue);
          expect(committed?.providerPlaceId, isNotEmpty);
          expect(committed!.toJson().containsKey('latitude'), isFalse);
          expect(committed!.toJson().containsKey('address'), isFalse);
          debugPrint('WAYDAY_GOOGLE_NATIVE_CONFIRMATION_PASSED');
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          return;
        }
        await tester.tap(finder);
        await tester.pump();
      }
    }
    await currentChannel().invokeMapMethod<String, Object?>('qualify', {
      'select': true,
    });
    final selectionDeadline = DateTime.now().add(const Duration(seconds: 10));
    while (find.byType(PlaceSearchPanel).evaluate().isNotEmpty &&
        DateTime.now().isBefore(selectionDeadline)) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.text('Your label'), findsOneWidget);
    expect(find.text('Confirm location'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm location'),
          )
          .onPressed,
      isNotNull,
    );
    debugPrint('WAYDAY_GOOGLE_NATIVE_SELECTION_VALIDATED');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm location'));
    await tester.pumpAndSettle();
    expect(committed?.provider, 'google_ui_kit');
    expect(committed?.label, 'sari-sari store');
    expect(committed?.hasCoordinates, isTrue);
    expect(committed!.toJson().containsKey('latitude'), isFalse);
    debugPrint('WAYDAY_GOOGLE_NATIVE_CONFIRMATION_PASSED');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    debugPrint('WAYDAY_GOOGLE_NATIVE_DISPOSED');
  });
}
