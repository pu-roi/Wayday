import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/philippine_place_search.dart';
import 'package:wayday/features/places/presentation/place_search_controller.dart';

const cebu = PlaceSearchResult(
  name: 'Cebu',
  latitude: 10.3,
  longitude: 123.9,
  sourceId: 'osm/node/1',
);

void main() {
  testWidgets('search waits 600 ms, skips short and duplicate queries', (
    tester,
  ) async {
    final queries = <String>[];
    final search = PlaceSearchController((query) async {
      queries.add(query);
      return [cebu];
    });
    addTearDown(search.dispose);
    search.change('C');
    await tester.pump(const Duration(seconds: 1));
    expect(queries, isEmpty);
    search.change('Ce');
    await tester.pump(const Duration(milliseconds: 599));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(queries, ['Ce']);
    expect(search.results.single.name, 'Cebu');
    search.change('Ce ');
    search.submit();
    await tester.pump(const Duration(seconds: 1));
    expect(queries, ['Ce']);
    search.change('Other');
    search.dismiss();
    search.change('Ce');
    await tester.pump(const Duration(milliseconds: 600));
    expect(queries, ['Ce']);
  });

  testWidgets(
    'only the latest queued query runs and stale results never replace it',
    (tester) async {
      final pending = <Completer<List<PlaceSearchResult>>>[];
      final queries = <String>[];
      final search = PlaceSearchController((query) {
        queries.add(query);
        final result = Completer<List<PlaceSearchResult>>();
        pending.add(result);
        return result.future;
      });
      addTearDown(search.dispose);
      search.change('Cebu');
      await tester.pump(const Duration(milliseconds: 600));
      search.change('Manila');
      await tester.pump(const Duration(milliseconds: 600));
      search.change('Davao');
      await tester.pump(const Duration(milliseconds: 600));
      expect(queries, ['Cebu']);
      pending.first.complete([cebu]);
      await tester.pump();
      expect(queries, ['Cebu', 'Davao']);
      expect(search.results, isEmpty);
      pending.last.complete([]);
      await tester.pump();
      expect(search.searched, isTrue);
      expect(search.loading, isFalse);
    },
  );

  testWidgets(
    'failures can retry and dismissed searches cannot change selection state',
    (tester) async {
      var attempts = 0;
      final search = PlaceSearchController((query) async {
        if (++attempts == 1) throw const PlaceSearchUnavailable();
        return [cebu];
      });
      search.change('Cebu');
      await tester.pump(const Duration(milliseconds: 600));
      expect(search.failed, isTrue);
      search.retry();
      await tester.pump();
      expect(search.failed, isFalse);
      expect(search.results.single, cebu);
      search.change('Manila');
      search.dismiss();
      await tester.pump(const Duration(seconds: 1));
      expect(attempts, 2);
      search.dispose();
    },
  );
}
