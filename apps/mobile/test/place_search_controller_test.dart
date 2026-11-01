import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/search_adapters.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';

class TestAdapter extends SearchAdapter {
  TestAdapter(this.id, this.run, {this.enabled = true, this.categories = true});
  @override
  final String id;
  @override
  String get endpoint => 'https://example.test/$id';
  @override
  final bool enabled, categories;
  final Future<List<PlaceSearchResult>> Function(PlaceSearchRequest) run;
  @override
  Future<List<PlaceSearchResult>> search(PlaceSearchRequest request) =>
      run(request);
}

class TestLedger {
  String? disk;
  bool fail = false;
  late final QuotaLedger ledger;
  TestLedger(DateTime Function() now) {
    ledger = QuotaLedger(
      now: now,
      read: () async => disk,
      write: (value) async {
        if (fail) throw StateError('disk');
        disk = value;
      },
    );
  }
}

const cebu = PlaceSearchResult(
  name: 'Cebu',
  latitude: 10.3,
  longitude: 123.9,
  sourceId: 'osm/node/1',
);

void main() {
  testWidgets(
    '800/1500 ms debounce, short input, Search and cache share one service',
    (tester) async {
      final calls = <String>[];
      final clock = tester.binding.clock.now;
      final service = CombinedPlaceSearch(
        [
          for (final id in ['geoapify', 'locationiq', 'photon'])
            TestAdapter(id, (request) async {
              calls.add('$id:${request.text}');
              return [cebu];
            }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final controller = PlaceSearchController(service);
      addTearDown(() {
        controller.dispose();
        service.dispose();
      });
      controller.change('Ce');
      await tester.pump(const Duration(seconds: 2));
      expect(calls, isEmpty);
      controller.change('Ceb');
      await tester.pump(const Duration(milliseconds: 400));
      controller.change('Cebu');
      await tester.pump(const Duration(milliseconds: 799));
      expect(calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.length, 2);
      expect(controller.results.length, 1);
      await tester.pump(const Duration(milliseconds: 700));
      expect(calls.length, 3);
      controller.submit();
      controller.submit();
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.length, 3);
      controller.dismiss();
      controller.change(' Cebu ');
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls.length, 3);
      final other = PlaceSearchController(service);
      addTearDown(other.dispose);
      other.change('Cebu');
      await tester.pump(const Duration(milliseconds: 1));
      expect(other.results.single.name, 'Cebu');
      expect(calls.length, 3);
    },
  );
  testWidgets(
    'only latest eligible query dispatches; stale response is ignored',
    (tester) async {
      final pending = Completer<List<PlaceSearchResult>>();
      final calls = <String>[];
      final clock = tester.binding.clock.now;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (r) {
            calls.add(r.text);
            return calls.length == 1 ? pending.future : Future.value([cebu]);
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
      c.change('First');
      await tester.pump(const Duration(milliseconds: 800));
      c.change('Second');
      await tester.pump(const Duration(milliseconds: 800));
      c.change('Last');
      await tester.pump(const Duration(milliseconds: 800));
      pending.complete([
        const PlaceSearchResult(
          name: 'Stale',
          latitude: 1,
          longitude: 1,
          sourceId: 'x',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, ['First', 'Last']);
      expect(c.results.single.name, 'Cebu');
    },
  );
  testWidgets(
    'in-flight identical queries combine and dismiss cancels pending work',
    (tester) async {
      var calls = 0;
      final pending = Completer<List<PlaceSearchResult>>();
      final clock = tester.binding.clock.now;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) {
            calls++;
            return pending.future;
          }),
        ],
        TestLedger(clock).ledger,
        now: clock,
      );
      final a = PlaceSearchController(service),
          b = PlaceSearchController(service);
      addTearDown(() {
        a.dispose();
        b.dispose();
        service.dispose();
      });
      a.change('Cebu');
      await tester.pump(const Duration(milliseconds: 800));
      b.change('Cebu');
      pending.complete([cebu]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
      expect(b.results.single.name, 'Cebu');
      a.change('Manila');
      a.dismiss();
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
    },
  );
  testWidgets(
    'partial failures preserve results and retries respect persisted cooldown',
    (tester) async {
      final clock = tester.binding.clock.now;
      var failedCalls = 0;
      final disk = TestLedger(clock);
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async => [cebu]),
          TestAdapter('locationiq', (_) async {
            failedCalls++;
            throw const SearchFailure(SearchFailureKind.rate);
          }),
        ],
        disk.ledger,
        now: clock,
      );
      final c = PlaceSearchController(service);
      addTearDown(() {
        c.dispose();
        service.dispose();
      });
      c.change('Cebu');
      await tester.pump(const Duration(milliseconds: 800));
      expect(c.results.single.name, 'Cebu');
      expect(c.failed, isTrue);
      c.retry();
      await tester.pump(const Duration(milliseconds: 1));
      expect(failedCalls, 1);
      final restarted = QuotaLedger(
        now: clock,
        read: () async => disk.disk,
        write: (v) async => disk.disk = v,
      );
      await expectLater(
        restarted.reserve('locationiq', ProviderPolicy.forId('locationiq')),
        throwsA(isA<SearchFailure>()),
      );
      await tester.pump(const Duration(seconds: 61));
      expect(failedCalls, 1);
      c.retry();
      await tester.pump(const Duration(milliseconds: 1));
      expect(failedCalls, 2);
    },
  );
  testWidgets('accounting failure prevents every network dispatch', (
    tester,
  ) async {
    final clock = tester.binding.clock.now;
    var calls = 0;
    final disk = TestLedger(clock)..fail = true;
    final service = CombinedPlaceSearch(
      [
        TestAdapter('geoapify', (_) async {
          calls++;
          return [cebu];
        }),
      ],
      disk.ledger,
      now: clock,
    );
    final c = PlaceSearchController(service);
    addTearDown(() {
      c.dispose();
      service.dispose();
    });
    c.change('Cebu');
    await tester.pump(const Duration(milliseconds: 800));
    expect(calls, 0);
    expect(c.failed, isTrue);
    expect(disk.disk, isNull);
  });
  testWidgets('categories require local area and pan does not dispatch', (
    tester,
  ) async {
    final clock = tester.binding.clock.now;
    final calls = <PlaceSearchRequest>[];
    final service = CombinedPlaceSearch(
      [
        TestAdapter('geoapify', (r) async {
          calls.add(r);
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
    c.change('palengke');
    c.chooseCategory(SearchCategory.marketplace);
    await tester.pump(const Duration(seconds: 2));
    expect(calls, isEmpty);
    expect(c.needsLocalArea, isTrue);
    c.updateArea(const SearchArea(14.5, 121, 12));
    await tester.pump(const Duration(seconds: 2));
    expect(calls, isEmpty);
    c.searchThisArea();
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls.single.category, SearchCategory.marketplace);
    c.updateArea(const SearchArea(14.6, 121, 12));
    await tester.pump(const Duration(seconds: 2));
    expect(calls.length, 1);
    c.searchThisArea();
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls.length, 2);
  });
  testWidgets('cache expires and empty results expire sooner', (tester) async {
    final clock = tester.binding.clock.now;
    var calls = 0;
    final service = CombinedPlaceSearch(
      [
        TestAdapter('geoapify', (_) async {
          calls++;
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
    c.change('Empty');
    await tester.pump(const Duration(milliseconds: 800));
    expect(c.emptySuccess, isTrue);
    c.dismiss();
    c.change('Empty');
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 61));
    c.dismiss();
    c.change('Empty');
    await tester.pump(const Duration(milliseconds: 800));
    expect(calls, 2);
  });
  testWidgets(
    'keyboard Search accepts two characters without bypassing spacing',
    (tester) async {
      final clock = tester.binding.clock.now;
      var calls = 0;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async {
            calls++;
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
      c.change('SM');
      c.submit();
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
      c.change('SM N');
      c.submit();
      c.submit();
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(calls, 2);
    },
  );
  testWidgets(
    'background suspension discards pending work without restarting on resume',
    (tester) async {
      final clock = tester.binding.clock.now;
      var calls = 0;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async {
            calls++;
            return [cebu];
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
      c.change('Cebu');
      c.suspend();
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 0);
      expect(c.loading, isFalse);
      c.retry();
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
    },
  );
  testWidgets(
    'later batches append without moving existing rows and retain merged credits',
    (tester) async {
      final clock = tester.binding.clock.now;
      final later = Completer<List<PlaceSearchResult>>();
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async => [cebu]),
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
      c.change('Cebu');
      await tester.pump(const Duration(milliseconds: 800));
      later.complete([
        cebu.withCredits(['Powered by Geoapify']),
        const PlaceSearchResult(
          name: 'Cebu branch',
          latitude: 10.4,
          longitude: 123.9,
          sourceId: 'second',
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 1));
      expect(c.results.map((r) => r.sourceId), ['osm/node/1', 'second']);
      expect(c.results.first.attributions, contains('Powered by Geoapify'));
    },
  );
  testWidgets(
    'successful cache expires after fifteen minutes and LRU retains only a hundred entries',
    (tester) async {
      final clock = tester.binding.clock.now;
      var calls = 0;
      final service = CombinedPlaceSearch(
        [
          TestAdapter('geoapify', (_) async {
            calls++;
            return [cebu];
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
      for (var i = 0; i < 101; i++) {
        c.change('Place $i');
        c.submit();
        await tester.pump(const Duration(milliseconds: 1101));
      }
      expect(calls, 101);
      c.change('Place 1');
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 101);
      c.change('Place 0');
      c.submit();
      await tester.pump(const Duration(milliseconds: 1101));
      expect(calls, 102);
      await tester.pump(const Duration(minutes: 16));
      c.dismiss();
      c.change('Place 1');
      await tester.pump(const Duration(milliseconds: 800));
      expect(calls, 103);
    },
  );
  test('dedup preserves branches, streets and conflicting addresses', () {
    const same = PlaceSearchResult(
      name: 'Cebu',
      latitude: 10.30001,
      longitude: 123.9,
      sourceId: 'other',
      attributions: ['Powered by Geoapify'],
    );
    expect(sameSearchPlace(cebu, same), isTrue);
    expect(
      sameSearchPlace(
        cebu,
        const PlaceSearchResult(
          name: 'Cebu',
          latitude: 10.4,
          longitude: 123.9,
          sourceId: 'branch',
        ),
      ),
      isFalse,
    );
    expect(
      sameSearchPlace(
        cebu,
        const PlaceSearchResult(
          name: 'Cebu',
          latitude: 10.3,
          longitude: 123.9,
          sourceId: 'street',
          street: true,
        ),
      ),
      isFalse,
    );
    expect(
      SearchCategory.match('  public   market '),
      SearchCategory.marketplace,
    );
    expect(SearchCategory.match('palengke Pasig'), isNull);
  });
}
