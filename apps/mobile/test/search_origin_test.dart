import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';
import 'place_search_controller_test.dart' show TestAdapter, TestLedger;
import 'search_ranking_test.dart' show place;

void main() {
  testWidgets(
    'partial provider access failure preserves near-first typo results and canonical cache reuse',
    (tester) async {
      final clock = tester.binding.clock.now;
      final later = Completer<List<PlaceSearchResult>>();
      final calls = <String>[];
      final near = place('near', 'Jollibee', 14.5935);
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async {
            calls.add('geoapify');
            return [place('far', 'Jolibee', 15.707)];
          }),
          TestAdapter('locationiq', (_) {
            calls.add('locationiq');
            return later.future;
          }),
          TestAdapter('photon', (_) async {
            calls.add('photon');
            throw const SearchFailure(SearchFailureKind.access);
          }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.updateDeviceLocation(const SearchOrigin.device(14.58, 121.05));
      c.change('jolibee');
      await tester.pump(const Duration(milliseconds: 800));
      later.complete([near]);
      await tester.pump(const Duration(milliseconds: 700));
      expect(c.failed, isTrue);
      expect(c.results.first, near);
      expect(c.sources['geoapify']!.phase, SourcePhase.complete);
      expect(c.sources['locationiq']!.phase, SourcePhase.complete);
      expect(c.sources['photon']!.phase, SourcePhase.unavailable);
      expect(calls.length, 3);
      c.change('Jollibee');
      await tester.pump();
      expect(c.results.first, near);
      expect(calls.length, 3);
      expect(c.query, 'Jollibee');
    },
  );
  testWidgets(
    'device origin works at overview; pan is inert and explicit map selection wins',
    (tester) async {
      final requests = <PlaceSearchRequest>[];
      final clock = tester.binding.clock.now;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (r) async {
            requests.add(r);
            return [];
          }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.updateArea(const SearchArea(10.3, 123.9, 5));
      c.updateDeviceLocation(const SearchOrigin.device(14.58, 121.05));
      c.change('Megamall');
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests.single.area!.latitude, 14.58);
      expect(requests.single.area!.zoom, 12);
      c.updateArea(const SearchArea(10.3, 123.9, 14));
      await tester.pump(const Duration(seconds: 2));
      expect(requests.length, 1);
      expect(c.originLabel, 'Near me');
      c.searchThisArea();
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.last.area!.latitude, 10.3);
      expect(c.originLabel, 'This map area');
      c.updateDeviceLocation(const SearchOrigin.device(14.6, 121.05));
      await tester.pump(const Duration(seconds: 2));
      expect(requests.length, 2);
      c.useNearMe();
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.last.area!.latitude, 14.6);
      expect(requests.length, 3);
    },
  );
  testWidgets(
    'fresh location replaces queued work and allows only one dispatched replacement',
    (tester) async {
      final requests = <PlaceSearchRequest>[];
      final clock = tester.binding.clock.now;
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
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.change('Megamall');
      await tester.pump(const Duration(milliseconds: 400));
      c.updateDeviceLocation(const SearchOrigin.device(14.58, 121.05));
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests.length, 1);
      expect(requests.single.origin, isNotNull);
      c.updateDeviceLocation(const SearchOrigin.device(14.5801, 121.05));
      await tester.pump(const Duration(seconds: 2));
      expect(requests.length, 1);
      c.updateDeviceLocation(const SearchOrigin.device(14.60, 121.05));
      await tester.pump(const Duration(milliseconds: 1));
      expect(requests.length, 2);
      c.updateDeviceLocation(const SearchOrigin.device(14.7, 121.05));
      await tester.pump(const Duration(seconds: 2));
      expect(requests.length, 2);
      c.change('McDonalds');
      await tester.pump(const Duration(milliseconds: 800));
      expect(requests.length, 3);
    },
  );
  testWidgets(
    'late exact result rises, interaction freezes records, updates are local',
    (tester) async {
      final later = Completer<List<PlaceSearchResult>>();
      final clock = tester.binding.clock.now;
      var calls = 0;
      final first = place('tenant', 'Megamall Building A', 14.58);
      final mall = place('mall', 'SM Megamall', 14.6);
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async {
            calls++;
            return [first];
          }),
          TestAdapter('locationiq', (_) {
            calls++;
            return later.future;
          }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.change('Megamall');
      await tester.pump(const Duration(milliseconds: 800));
      c.freezeResults();
      later.complete([mall]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(c.results, [first]);
      expect(identical(c.results.first, first), isTrue);
      expect(c.hasUpdates, isTrue);
      c.applyUpdates();
      expect(c.results.first, mall);
      expect(c.hasUpdates, isFalse);
      expect(calls, 2);
      c.change('Megamall again');
      expect(c.hasUpdates, isFalse);
      c.dismiss();
    },
  );
  testWidgets('all-provider ranking occurs before the thirty-result limit', (
    tester,
  ) async {
    final clock = tester.binding.clock.now;
    final later = Completer<List<PlaceSearchResult>>();
    final service = CombinedPlaceSearch(
      [
        TestAdapter(
          'geoapify',
          (_) async =>
              List.generate(20, (i) => place('a$i', 'Other $i', 14.58)),
        ),
        TestAdapter('locationiq', (_) => later.future),
      ],
      TestLedger(clock).ledger,
      now: clock,
    );
    final c = PlaceSearchController(service);
    addTearDown(() {
      c.dispose();
      service.dispose();
    });
    c.change('Megamall');
    await tester.pump(const Duration(milliseconds: 800));
    later.complete([
      for (var i = 0; i < 19; i++) place('b$i', 'Other branch $i', 14.58),
      place('mall', 'SM Megamall', 14.6),
    ]);
    await tester.pump(const Duration(milliseconds: 1));
    expect(c.results.length, 30);
    expect(c.results.first.sourceId, 'mall');
  });
  test(
    'cache keys distinguish origin type and Photon zoom without timestamps',
    () {
      final a = PlaceSearchRequest(
        'SM',
        origin: const SearchOrigin.device(14.58, 121.05),
      );
      final b = PlaceSearchRequest(
        'SM',
        area: const SearchArea(14.58, 121.05, 14),
      );
      final d = PlaceSearchRequest(
        'SM',
        area: const SearchArea(14.58, 121.05, 15),
      );
      expect(a.key, isNot(b.key));
      expect(b.key, isNot(d.key));
    },
  );
}
