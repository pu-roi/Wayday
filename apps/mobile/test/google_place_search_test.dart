import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/places/domain/search_terms.dart';
import 'package:wayday/features/places/domain/philippine_eligibility.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';
import 'package:wayday/features/errands/domain/errand.dart';
import 'package:wayday/features/maps/presentation/online_pin_picker.dart';
import 'package:wayday/features/maps/presentation/place_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wayday/features/maps/data/location_reader.dart';
import 'support/fake_location.dart';
import 'package:wayday/features/places/presentation/place_search_panel.dart';
import 'package:wayday/app/theme.dart';

class Bridge implements GoogleSearchBridge {
  final loads = <GoogleNativeRequest>[];
  final shown = <int>[];
  Completer<Map<Object?, Object?>>? response;
  @override
  Future<Map<Object?, Object?>> load(GoogleNativeRequest request) {
    loads.add(request);
    return response?.future ?? Future.value({'count': 3});
  }

  @override
  Future<void> show(int revision) async => shown.add(revision);
  @override
  Future<void> cancel() async {}
}

class CountingOther extends SearchAdapter {
  int calls = 0;
  @override
  String get id => 'geoapify';
  @override
  String get endpoint => 'https://fixture.invalid';
  @override
  bool get enabled => true;
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) async {
    calls++;
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'original Google controls stay reachable on a small phone with larger text and keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final source = SearchSourceChoice();
      final ledger = QuotaLedger(read: () async => null, write: (_) async {});
      final google = GoogleSearchService(ledger, enabled: false),
          others = CombinedPlaceSearch([], ledger);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchSourceChoiceProvider.overrideWithValue(source),
            googleSearchProvider.overrideWithValue(google),
            combinedPlaceSearchProvider.overrideWithValue(others),
            locationPlatformProvider.overrideWithValue(
              FakeLocationPlatform(access: LocationAccess.denied),
            ),
            placeMapBuilderProvider.overrideWithValue(
              (_) => const SizedBox.expand(),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.6)),
              child: child!,
            ),
            home: const OnlinePinPicker(initial: null),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('place-name')));
      await tester.enterText(find.byKey(const Key('place-name')), 'Megamall');
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      expect(find.text('Other sources'), findsOneWidget);
      expect(find.byTooltip('Search options'), findsNothing);
      final header = find.descendant(
        of: find.byKey(const PageStorageKey('google-search-controls')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Search this area'),
        70,
        scrollable: header,
      );
      expect(find.text('Places'), findsNothing);
      expect(find.text('Search original text'), findsNothing);
      expect(find.textContaining('Searching for'), findsNothing);
      final footer = find.descendant(
        of: find.byKey(const PageStorageKey('google-search-fallback')),
        matching: find.byType(Scrollable),
      );
      expect(find.text('Saves this name without a map pin.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Back to map'),
        60,
        scrollable: footer,
      );
      expect(find.text('Back to map').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Close search'), findsOneWidget);
      await tester.tap(find.byTooltip('Close search'));
      await tester.pump();
      expect(find.byType(PlaceSearchPanel), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('place-name')))
            .controller!
            .text,
        'Megamall',
      );
      await tester.pumpWidget(const SizedBox());
      google.dispose();
      others.dispose();
      source.dispose();
    },
  );
  test(
    'local Philippine mask verifies islands and rejects foreign points inside a broad country box',
    () {
      for (final point in [
        (14.585, 121.057),
        (16.4, 120.6),
        (10.32, 123.89),
        (7.10, 125.60),
        (9.75, 118.75),
        (20.45, 121.97),
      ]) {
        expect(
          PhilippineEligibility.confirmed(point.$1, point.$2),
          isTrue,
          reason: '$point',
        );
      }
      for (final point in [
        (5.98, 116.07),
        (4.48, 118.62),
        (21.90, 120.85),
        (4.10, 126.9),
        (0.0, 0.0),
        (14.5, 120.0),
      ]) {
        expect(
          PhilippineEligibility.confirmed(point.$1, point.$2),
          isFalse,
          reason: '$point',
        );
      }
      final now = DateTime.utc(2026, 10, 29);
      final data = <Object?, Object?>{
        'revision': 1,
        'placeId': 'id',
        'latitude': 14.585,
        'longitude': 121.057,
        'countryStatus': null,
        'retrievedAtMillis': now.millisecondsSinceEpoch,
      };
      expect(GooglePlaceSnapshot.fromJson(data, now).valid, isTrue);
      data['countryStatus'] = false;
      expect(GooglePlaceSnapshot.fromJson(data, now).valid, isFalse);
    },
  );
  testWidgets(
    'Google is initial, explicit fallback preserves the field and Back hides search keyboard only',
    (tester) async {
      final source = SearchSourceChoice();
      final ledger = QuotaLedger(read: () async => null, write: (_) async {});
      final google = GoogleSearchService(ledger, enabled: false);
      final others = CombinedPlaceSearch([], ledger);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchSourceChoiceProvider.overrideWithValue(source),
            googleSearchProvider.overrideWithValue(google),
            combinedPlaceSearchProvider.overrideWithValue(others),
            locationPlatformProvider.overrideWithValue(
              FakeLocationPlatform(access: LocationAccess.denied),
            ),
            placeMapBuilderProvider.overrideWithValue(
              (_) => const SizedBox.expand(),
            ),
          ],
          child: const MaterialApp(
            home: OnlinePinPicker(initial: PlaceIntent(label: 'My draft')),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('place-name')));
      await tester.pump();
      expect(source.value, SearchSource.google);
      expect(find.text('Other sources'), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.byKey(const Key('place-name')),
      );
      expect(field.controller!.text, 'My draft');
      await tester.tap(find.text('Other sources'));
      await tester.pump();
      expect(source.value, SearchSource.others);
      expect(field.controller!.text, 'My draft');
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(PlaceSearchPanel), findsOneWidget);
      expect(field.controller!.text, 'My draft');
      await tester.pumpWidget(const SizedBox());
      google.dispose();
      others.dispose();
      source.dispose();
    },
  );
  test(
    'pinned dictionary covers aliases, qualifiers and safe fuzzy corrections',
    () {
      expect(searchBrands.length, greaterThan(300));
      for (final query in ['McDo', 'mcdonals', 'McDonald’s']) {
        expect(interpretSearch(query).providerText, "McDonald's");
      }
      expect(interpretSearch('jolibee').providerText, 'Jollibee');
      expect(interpretSearch('Megamall').providerText, 'SM Megamall');
      expect(
        interpretSearch('mcdonals Shangri-La').providerText,
        "McDonald's Shangri-La",
      );
      for (final text in ['SM', 'BGC', '12 mcdonals street', 'Rizal Street']) {
        expect(interpretSearch(text).providerText, text);
      }
      expect(
        interpretSearch('mcdonals', useOriginal: true).providerText,
        'mcdonals',
      );
      expect(boundedEditDistance('jollibee', 'jollibee', 2), 0);
      expect(boundedEditDistance('jollibee', 'jollbiee', 1), 1);
    },
  );
  test('ambiguous dictionary corrections remain suggestions', () {
    // Exercise real collisions instead of depending on a fabricated brand.
    final candidates = searchBrands.where(
      (b) => b.name.length >= 5 && !b.landmark,
    );
    var found = false;
    for (final brand in candidates) {
      final query = '${brand.name.substring(0, brand.name.length - 1)}x';
      final result = interpretSearch(query);
      if (result.suggestions.length >= 2) {
        expect(result.providerText, query);
        found = true;
        break;
      }
    }
    expect(found, isTrue);
  });
  test('Filipino aliases map to honest categories', () {
    expect(SearchCategory.match('sari-sari store'), SearchCategory.convenience);
    expect(SearchCategory.match('tindahan'), SearchCategory.convenience);
    expect(SearchCategory.match('palengke'), SearchCategory.marketplace);
    expect(SearchCategory.match('botika'), SearchCategory.pharmacy);
    expect(SearchCategory.match('kainan'), SearchCategory.food);
    expect(SearchCategory.match('palengke Pasig'), isNull);
  });
  test(
    'snapshot validation rejects missing IDs, invalid coordinates and unverified country',
    () {
      final now = DateTime.utc(2026, 10, 29);
      expect(
        () => GooglePlaceSnapshot.fromJson({'revision': 1}, now),
        throwsFormatException,
      );
      final snapshot = GooglePlaceSnapshot.fromJson({
        'revision': 1,
        'placeId': 'id',
        'latitude': 14.5,
        'longitude': 121,
        'retrievedAtMillis': now.millisecondsSinceEpoch,
        'countryVerified': false,
        'countryStatus': false,
      }, now);
      expect(snapshot.valid, isFalse);
      expect(
        GooglePlaceSnapshot.fromJson({
          'revision': 1,
          'placeId': 'id',
          'latitude': 91,
          'longitude': 121,
          'retrievedAtMillis': now.millisecondsSinceEpoch,
          'countryVerified': true,
        }, now).valid,
        isFalse,
      );
      expect(
        PlaceIntent.fromJson({
          'kind': 'providerReference',
          'label': 'Mine',
          'provider': 'google_ui_kit',
          'providerPlaceId': 'id',
          'latitude': 14.5,
          'longitude': 121,
        }).hasCoordinates,
        isFalse,
      );
    },
  );
  test(
    'foreground expiry timer physically purges the temporary coordinate file',
    () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026, 10, 29);
        String file = '{}';
        final cache = GooglePinCache(
          now: () => start.add(clock.elapsed),
          read: () async => file,
          write: (v) async => file = v,
        );
        cache.put('id', 14.5, 121, start);
        clock.flushMicrotasks();
        final lease = cache.lease('id');
        clock.elapse(
          const Duration(days: 30) - const Duration(milliseconds: 1),
        );
        expect(lease.valid, isTrue);
        clock.elapse(const Duration(milliseconds: 1));
        clock.flushMicrotasks();
        expect(lease.valid, isFalse);
        expect(jsonDecode(file), isEmpty);
        cache.dispose();
      });
    },
  );
  test(
    'Google cancellation consumes a reservation without an outage cooldown',
    () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026, 10, 29);
        DateTime now() => start.add(clock.elapsed);
        String file = '{}';
        final ledger = QuotaLedger(
          now: now,
          read: () async => null,
          write: (v) async => file = v,
        );
        final google = GoogleSearchService(ledger, now: now),
            bridge = Bridge()..response = Completer();
        final owner = Object();
        google.search(
          owner,
          bridge,
          PlaceSearchRequest('first'),
          (_) {},
          (_, _) {},
          immediate: true,
        );
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
        google.cancel(owner);
        bridge.response!.complete({'error': 'cancelled'});
        bridge.response = null;
        clock.flushMicrotasks();
        google.search(
          owner,
          bridge,
          PlaceSearchRequest('next'),
          (_) {},
          (_, _) {},
          immediate: true,
        );
        clock.elapse(const Duration(milliseconds: 1100));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 2);
        final accounting = jsonDecode(file) as Map;
        expect((accounting['starts']['google_ui_kit'] as List).length, 2);
        expect(accounting['cooldowns'], isEmpty);
        google.dispose();
      });
    },
  );
  test(
    'Google minute quota is twenty and details use the same provider identity',
    () async {
      var time = DateTime.utc(2026, 10, 29);
      final ledger = QuotaLedger(
        now: () => time,
        read: () async => null,
        write: (_) async {},
      );
      final policy = ProviderPolicy.forId('google_ui_kit');
      for (var i = 0; i < 20; i++) {
        expect(await ledger.reserve('google_ui_kit', policy), isNull);
        time = time.add(const Duration(milliseconds: 1100));
      }
      expect(
        await ledger.reserve('google_ui_kit', policy),
        DateTime.utc(2026, 10, 29, 0, 1),
      );
      expect(
        GoogleNativeRequest(
          1,
          PlaceSearchRequest('test'),
          placeId: 'id',
        ).toJson()['placeId'],
        'id',
      );
    },
  );
  test(
    'Google durable errand and saved JSON keep IDs and user labels only',
    () async {
      var time = DateTime.utc(2026, 10, 29);
      String? file;
      final cache = GooglePinCache(
        now: () => time,
        read: () async => file,
        write: (v) async => file = v,
      );
      await cache.put('google-place-id', 14.58, 121.05, time);
      final place = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'My lunch stop',
        provider: 'google_ui_kit',
        providerPlaceId: 'google-place-id',
        googlePin: cache.lease('google-place-id'),
        address: 'Must never persist',
        brand: 'Returned brand',
        retrievedAt: time.toIso8601String(),
        attributions: const ['Google Maps'],
      );
      final errand = Errand(
        id: 'a',
        title: 'Lunch',
        place: place.label,
        placeIntent: place,
      );
      final copied = errand.copyForToday(newId: 'b', groupId: 'g');
      final json = jsonEncode([
        errand.toJson(),
        copied.toJson(),
        SavedPlace(id: 's', place: place).toJson(),
      ]);
      for (final forbidden in [
        '14.58',
        '121.05',
        'Must never persist',
        'Returned brand',
        'retrievedAt',
      ]) {
        expect(json, isNot(contains(forbidden)));
      }
      final restored = PlaceIntent.fromJson(
        place.toJson(),
        resolveGooglePin: cache.lease,
      );
      expect(restored.hasCoordinates, isTrue);
      time = time.add(const Duration(days: 30));
      expect(place.hasCoordinates, isFalse);
      expect(copied.placeIntent.hasCoordinates, isFalse);
      expect(restored.latitude, isNull);
      await cache.purge();
      expect(jsonDecode(file!), isEmpty);
      expect(restored.label, 'My lunch stop');
      cache.dispose();
    },
  );
  test(
    'restart, eviction, invalid data and rollback do not revive a lease',
    () async {
      var time = DateTime.utc(2026, 10, 29);
      String? file;
      final one = GooglePinCache(
        now: () => time,
        read: () async => file,
        write: (v) async => file = v,
      );
      await one.put('id', 14.5, 121, time);
      one.dispose();
      final two = GooglePinCache(
        now: () => time,
        read: () async => file,
        write: (v) async => file = v,
      );
      await two.load();
      expect(two.lease('id').valid, isTrue);
      expect(two.lease('evicted').valid, isFalse);
      time = time.subtract(const Duration(seconds: 1));
      expect(two.lease('id').valid, isFalse);
      await two.purge();
      expect(jsonDecode(file!), isEmpty);
      two.dispose();
    },
  );
  test(
    'Google debounces, shares spacing across owners, and never caches results',
    () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026, 10, 29);
        DateTime now() => start.add(clock.elapsed);
        final ledger = QuotaLedger(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final service = GoogleSearchService(ledger, now: now);
        final bridge = Bridge(), owner = Object();
        void search(String text, {Object? user, bool immediate = false}) =>
            service.search(
              user ?? owner,
              bridge,
              PlaceSearchRequest(text),
              (_) {},
              (_, _) {},
              immediate: immediate,
            );
        search('McD');
        clock.elapse(const Duration(milliseconds: 600));
        search('McDo');
        clock.elapse(const Duration(milliseconds: 999));
        expect(bridge.loads, isEmpty);
        clock.elapse(const Duration(milliseconds: 1));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 1);
        expect(bridge.loads.single.toJson()['query'], "McDonald's");
        search('McDo', user: Object(), immediate: true);
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
        expect(bridge.loads.length, 1);
        clock.elapse(const Duration(milliseconds: 1100));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 2);
        service.dispose();
      });
    },
  );
  test('one active load and only the latest pending query survives', () {
    fakeAsync((clock) {
      final start = DateTime.utc(2026, 10, 29);
      DateTime now() => start.add(clock.elapsed);
      final service = GoogleSearchService(
        QuotaLedger(now: now, read: () async => null, write: (_) async {}),
        now: now,
      );
      final bridge = Bridge()..response = Completer();
      final owner = Object();
      void query(String text) => service.search(
        owner,
        bridge,
        PlaceSearchRequest(text),
        (_) {},
        (_, _) {},
        immediate: true,
      );
      query('first');
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      query('second');
      query('third');
      clock.elapse(const Duration(milliseconds: 1500));
      clock.flushMicrotasks();
      expect(bridge.loads.length, 1);
      bridge.response!.complete({'count': 1});
      bridge.response = null;
      clock.flushMicrotasks();
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(bridge.loads.map((r) => r.search.text), ['first', 'third']);
      service.dispose();
    });
  });
  test('accounting failure prevents native dispatch and exposes fallback', () {
    fakeAsync((clock) {
      final service = GoogleSearchService(
        QuotaLedger(
          read: () async => null,
          write: (_) async => throw StateError('disk'),
        ),
      );
      final bridge = Bridge();
      SourceState? state;
      service.search(
        Object(),
        bridge,
        PlaceSearchRequest('test'),
        (v) => state = v,
        (_, _) {},
        immediate: true,
      );
      clock.elapse(Duration.zero);
      clock.flushMicrotasks();
      expect(bridge.loads, isEmpty);
      expect(state!.phase, SourcePhase.unavailable);
      service.dispose();
    });
  });
  test(
    'Google daily budget includes details and persists across restarts',
    () async {
      var now = DateTime.utc(2026, 10, 29);
      String? file;
      QuotaLedger ledger() => QuotaLedger(
        now: () => now,
        read: () async => file,
        write: (v) async => file = v,
      );
      var current = ledger();
      final policy = ProviderPolicy.forId('google_ui_kit');
      for (var i = 0; i < 100; i++) {
        expect(await current.reserve('google_ui_kit', policy), isNull);
        now = now.add(const Duration(seconds: 4));
        if (i == 49) current = ledger();
      }
      await expectLater(
        current.reserve('google_ui_kit', policy),
        throwsA(isA<SearchFailure>()),
      );
      expect(file, isNot(contains('query')));
      expect(file, isNot(contains('latitude')));
    },
  );
  test(
    'source switch, stale callbacks, staged cards and exact selection provenance',
    () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026, 10, 29);
        DateTime now() => start.add(clock.elapsed);
        final ledger = QuotaLedger(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final google = GoogleSearchService(ledger, now: now);
        final other = CountingOther();
        final others = CombinedPlaceSearch([other], ledger, now: now);
        final choice = SearchSourceChoice();
        final pins = GooglePinCache(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final controller = PlaceSearchController(
          others,
          google: google,
          sourceChoice: choice,
          pins: pins,
        );
        final bridge = Bridge();
        controller.attachGoogle(bridge);
        PlaceIntent? selected;
        controller.onGoogleSelection = (v) => selected = v;
        controller.change('McDo');
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        final first = bridge.loads.single;
        controller.freezeResults();
        controller.updateDeviceLocation(const SearchOrigin.device(14.5, 121));
        clock.elapse(const Duration(milliseconds: 1100));
        clock.flushMicrotasks();
        expect(controller.hasUpdates, isTrue);
        expect(bridge.shown, [first.revision]);
        controller.googleSelected(
          GooglePlaceSnapshot(
            revision: first.revision,
            placeId: 'exact-id',
            latitude: 14.5,
            longitude: 121,
            countryVerified: true,
            resolved: false,
            retrievedAt: now(),
          ),
        );
        clock.flushMicrotasks();
        expect(selected!.providerPlaceId, 'exact-id');
        expect(selected!.label, 'McDo');
        controller.applyUpdates();
        expect(bridge.shown.length, 2);
        expect(other.calls, 0);
        controller.chooseSource(SearchSource.others);
        clock.elapse(Duration.zero);
        clock.flushMicrotasks();
        expect(other.calls, 1);
        expect(controller.query, 'McDo');
        expect(choice.value, SearchSource.others);
        selected = null;
        controller.googleSelected(
          GooglePlaceSnapshot(
            revision: first.revision,
            placeId: 'stale-id',
            latitude: 14.5,
            longitude: 121,
            countryVerified: true,
            resolved: false,
            retrievedAt: now(),
          ),
        );
        clock.flushMicrotasks();
        expect(selected, isNull);
        controller.dispose();
        google.dispose();
        others.dispose();
        choice.dispose();
        pins.dispose();
      });
    },
  );
  test(
    'unknown Google selection resolves once; mismatched IDs and unverified details cannot commit',
    () {
      fakeAsync((clock) {
        final start = DateTime.utc(2026, 10, 29);
        DateTime now() => start.add(clock.elapsed);
        final ledger = QuotaLedger(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final google = GoogleSearchService(ledger, now: now);
        final others = CombinedPlaceSearch([], ledger, now: now);
        final choice = SearchSourceChoice();
        final pins = GooglePinCache(
          now: now,
          read: () async => null,
          write: (_) async {},
        );
        final controller = PlaceSearchController(
          others,
          google: google,
          sourceChoice: choice,
          pins: pins,
        );
        final bridge = Bridge();
        controller.attachGoogle(bridge);
        PlaceIntent? selected;
        controller.onGoogleSelection = (v) => selected = v;
        controller.change('Megamall');
        clock.elapse(const Duration(seconds: 1));
        clock.flushMicrotasks();
        final pending = GooglePlaceSnapshot(
          revision: bridge.loads.single.revision,
          placeId: 'requested-id',
          latitude: null,
          longitude: null,
          countryVerified: false,
          resolved: false,
          retrievedAt: now(),
        );
        controller.googleSelected(pending);
        controller.googleSelected(pending);
        clock.elapse(const Duration(milliseconds: 1100));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 2);
        expect(bridge.loads.last.placeId, 'requested-id');
        controller.updateDeviceLocation(const SearchOrigin.device(14.6, 121.1));
        clock.elapse(const Duration(milliseconds: 1100));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 2);
        controller.googleSelected(
          GooglePlaceSnapshot(
            revision: bridge.loads.last.revision,
            placeId: 'different-id',
            latitude: 14.5,
            longitude: 121,
            countryVerified: true,
            resolved: true,
            retrievedAt: now(),
          ),
        );
        controller.googleSelected(
          GooglePlaceSnapshot(
            revision: bridge.loads.last.revision,
            placeId: 'requested-id',
            latitude: 14.5,
            longitude: 121,
            countryVerified: false,
            resolved: true,
            retrievedAt: now(),
          ),
        );
        clock.flushMicrotasks();
        expect(selected, isNull);
        expect(controller.googleMessage, contains('could not be verified'));
        controller.change('new query');
        controller.suspend();
        clock.elapse(const Duration(seconds: 3));
        clock.flushMicrotasks();
        expect(bridge.loads.length, 2);
        controller.dispose();
        google.dispose();
        others.dispose();
        choice.dispose();
        pins.dispose();
      });
    },
  );
}
