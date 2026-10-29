import 'dart:async';
import 'dart:convert';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/combined_place_search.dart';
import 'package:wayday/features/places/data/google_search.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';
import 'google_place_search_test.dart' show Bridge;
import 'place_search_controller_test.dart' show TestAdapter, cebu;

class SessionFixture {
  SessionFixture(this.clock) {
    ledger = QuotaLedger(
      now: now,
      read: () async => null,
      write: (value) async => disk = value,
    );
    google = GoogleSearchService(ledger, now: now);
    others = CombinedPlaceSearch(
      [
        TestAdapter('geoapify', (request) {
          otherCalls++;
          return otherResponse?.future ?? Future.value([cebu]);
        }),
      ],
      ledger,
      now: now,
    );
    controller = PlaceSearchController(
      others,
      google: google,
      sourceChoice: choice,
    )..attachGoogle(bridge);
  }
  final FakeAsync clock;
  final choice = SearchSourceChoice();
  final bridge = Bridge();
  late final QuotaLedger ledger;
  late final GoogleSearchService google;
  late final CombinedPlaceSearch others;
  late final PlaceSearchController controller;
  Completer<List<PlaceSearchResult>>? otherResponse;
  String disk = '{}';
  int otherCalls = 0;
  DateTime now() => DateTime.utc(2026, 10, 29).add(clock.elapsed);
  void tick([Duration value = const Duration(seconds: 2)]) {
    clock.elapse(value);
    clock.flushMicrotasks();
  }

  Map<String, Object?> get starts => Map<String, Object?>.from(
    (jsonDecode(disk) as Map<String, dynamic>)['starts']
        as Map<String, dynamic>,
  );
  void dispose() {
    controller.dispose();
    google.dispose();
    others.dispose();
    choice.dispose();
  }
}

void main() {
  test(
    'quota-waiting Google work cannot dispatch while another source is selected',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        for (var i = 0; i < 20; i++) {
          f.ledger.reserve(
            'google_ui_kit',
            ProviderPolicy.forId('google_ui_kit'),
          );
          clock.flushMicrotasks();
          f.tick(const Duration(milliseconds: 1100));
        }
        f.controller.change('Megamall');
        f.tick();
        expect(f.bridge.loads, isEmpty);
        f.choice.choose(SearchSource.others);
        f.tick(const Duration(minutes: 2));
        expect(f.bridge.loads, isEmpty);
        f.choice.choose(SearchSource.google);
        f.tick();
        expect(f.bridge.loads.length, 1);
        f.dispose();
      });
    },
  );

  test(
    'panning is quiet; explicit area/category changes invalidate hidden snapshots',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.controller.updateArea(const SearchArea(14.58, 121.05, 14));
        f.controller.updateDeviceLocation(
          const SearchOrigin.device(14.58, 121.05),
        );
        f.controller.change('Cebu');
        f.tick();
        f.choice.choose(SearchSource.others);
        f.tick();
        f.controller.updateArea(const SearchArea(14.60, 121.10, 14));
        f.tick();
        expect(f.otherCalls, 1);
        expect(f.bridge.loads.length, 1);
        f.controller.searchThisArea();
        f.tick();
        f.choice.choose(SearchSource.google);
        f.tick();
        expect(f.bridge.loads.length, 2);
        expect(f.bridge.loads.last.search.origin!.kind, SearchOriginKind.map);
        f.controller.chooseCategory(SearchCategory.pharmacy);
        f.tick();
        expect(f.bridge.loads.last.search.category, SearchCategory.pharmacy);
        f.dispose();
      });
    },
  );

  test('closed controllers do not search when the shared source changes', () {
    fakeAsync((clock) {
      final f = SessionFixture(clock);
      final closed = PlaceSearchController(
        f.others,
        google: f.google,
        sourceChoice: f.choice,
      )..query = 'Unopened picker';
      f.controller.change('Megamall');
      f.tick();
      f.choice.choose(SearchSource.others);
      f.tick();
      expect(f.otherCalls, 1);
      expect(closed.hasSearch, isFalse);
      closed.dispose();
      f.dispose();
    });
  });
  test(
    'ten source switches retain results and consume only two starts even after TTL',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.controller.change('Megamall');
        f.tick();
        f.choice.choose(SearchSource.others);
        f.tick();
        final record = f.controller.results.single;
        final before = jsonEncode(f.starts);
        f.tick(const Duration(minutes: 16));
        for (var i = 0; i < 10; i++) {
          f.choice.choose(SearchSource.google);
          f.tick();
          expect(f.controller.searched, isTrue);
          f.choice.choose(SearchSource.others);
          f.tick();
          expect(f.controller.results.single, same(record));
        }
        expect(f.bridge.loads.length, 1);
        expect(f.otherCalls, 1);
        expect(jsonEncode(f.starts), before);
        f.dispose();
      });
    },
  );

  test(
    'queued work pauses while hidden and two-character submit survives switching',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.controller.change('SM');
        f.controller.submit();
        f.choice.choose(SearchSource.others);
        f.tick();
        expect(f.bridge.loads, isEmpty);
        expect(f.otherCalls, 1);
        f.choice.choose(SearchSource.google);
        f.tick();
        expect(f.bridge.loads.length, 1);
        f.dispose();
      });
    },
  );

  test('Google completion while hidden is retained without another load', () {
    fakeAsync((clock) {
      final f = SessionFixture(clock);
      final response = Completer<Map<Object?, Object?>>();
      f.bridge.response = response;
      f.controller.change('Megamall');
      f.tick();
      f.choice.choose(SearchSource.others);
      f.tick();
      response.complete({'count': 2});
      clock.flushMicrotasks();
      expect(f.controller.results.single, cebu);
      f.choice.choose(SearchSource.google);
      expect(f.controller.searched, isTrue);
      expect(f.controller.emptySuccess, isFalse);
      expect(f.bridge.loads.length, 1);
      f.dispose();
    });
  });

  test(
    'Other sources completion while hidden is retained and frozen updates survive',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.choice.choose(SearchSource.others);
        f.otherResponse = Completer();
        f.controller.change('Cebu');
        f.tick();
        f.controller.freezeResults();
        f.choice.choose(SearchSource.google);
        f.tick();
        f.otherResponse!.complete([cebu]);
        clock.flushMicrotasks();
        expect(f.controller.hasUpdates, isFalse);
        f.choice.choose(SearchSource.others);
        expect(f.controller.hasUpdates, isTrue);
        expect(f.controller.results, isEmpty);
        f.controller.applyUpdates();
        expect(f.controller.results.single, cebu);
        expect(f.otherCalls, 1);
        f.dispose();
      });
    },
  );

  test('edits invalidate hidden results and discard old callbacks', () {
    fakeAsync((clock) {
      final f = SessionFixture(clock);
      final old = Completer<Map<Object?, Object?>>();
      f.bridge.response = old;
      f.controller.change('Megamall');
      f.tick();
      f.choice.choose(SearchSource.others);
      f.tick();
      f.controller.change('Cebu');
      old.complete({'count': 9});
      clock.flushMicrotasks();
      f.bridge.response = null;
      f.choice.choose(SearchSource.google);
      f.tick();
      expect(f.bridge.loads.length, 2);
      expect(f.bridge.loads.last.search.text, 'Cebu');
      f.dispose();
    });
  });

  test('empty and failed Google sessions do not retry when switching', () {
    for (final result in [
      {'count': 0},
      {'error': 'temporary'},
    ]) {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.bridge.response = Completer()..complete(result);
        f.controller.change('Megamall');
        f.tick();
        final failed = f.controller.failed;
        f.choice.choose(SearchSource.others);
        f.tick();
        f.choice.choose(SearchSource.google);
        f.tick(const Duration(seconds: 20));
        expect(f.bridge.loads.length, 1);
        expect(f.controller.failed, failed);
        if (!failed) expect(f.controller.emptySuccess, isTrue);
        f.dispose();
      });
    }
  });

  test('explicit refresh bypasses Other sources cache but retains records', () {
    fakeAsync((clock) {
      final f = SessionFixture(clock)..choice.choose(SearchSource.others);
      f.controller.change('Cebu');
      f.tick();
      f.controller.refreshResults();
      expect(f.controller.results.single, cebu);
      f.tick();
      expect(f.otherCalls, 2);
      f.choice.choose(SearchSource.google);
      f.tick();
      f.controller.refreshResults();
      f.tick();
      expect(f.bridge.loads.length, 2);
      f.dispose();
    });
  });

  test(
    'background keeps completed results, rejects late work and closed pickers stay quiet',
    () {
      fakeAsync((clock) {
        final f = SessionFixture(clock);
        f.controller.change('Megamall');
        f.tick();
        f.choice.choose(SearchSource.others);
        f.otherResponse = Completer();
        f.tick();
        f.controller.suspend();
        f.otherResponse!.complete([cebu]);
        clock.flushMicrotasks();
        f.choice.choose(SearchSource.google);
        f.tick();
        expect(f.controller.searched, isTrue);
        expect(f.bridge.loads.length, 1);
        f.choice.choose(SearchSource.others);
        f.tick();
        expect(f.controller.results, isEmpty);
        expect(f.otherCalls, 1);
        f.controller.dismiss();
        f.choice.choose(SearchSource.google);
        f.tick();
        expect(f.bridge.loads.length, 1);
        f.dispose();
      });
    },
  );
}
