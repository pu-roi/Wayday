import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_search.dart';

void main() {
  test(
    'minute and daily reservations survive restart without storing queries',
    () async {
      var now = DateTime.utc(2026, 10, 28);
      String? disk;
      QuotaLedger create() => QuotaLedger(
        now: () => now,
        read: () async => disk,
        write: (s) async => disk = s,
      );
      var ledger = create();
      const policy = ProviderPolicy(Duration.zero, 2, 3, Duration.zero);
      expect(await ledger.reserve('locationiq', policy), isNull);
      expect(await ledger.reserve('locationiq', policy), isNull);
      expect(
        await ledger.reserve('locationiq', policy),
        now.add(const Duration(minutes: 1)),
      );
      ledger = create();
      now = now.add(const Duration(minutes: 1));
      expect(await ledger.reserve('locationiq', policy), isNull);
      await expectLater(
        ledger.reserve('locationiq', policy),
        throwsA(
          isA<SearchFailure>().having(
            (e) => e.kind,
            'kind',
            SearchFailureKind.daily,
          ),
        ),
      );
      expect(
        (jsonDecode(disk!) as Map).keys,
        containsAll(['starts', 'cooldowns', 'streaks']),
      );
      expect(disk, isNot(contains('query')));
      expect(disk, isNot(contains('key')));
      now = now.add(const Duration(hours: 24));
      expect(await ledger.reserve('locationiq', policy), isNull);
    },
  );
  test('spacing is enforced across a recreated ledger', () async {
    final now = DateTime.utc(2026, 10, 28);
    String? disk;
    QuotaLedger create() => QuotaLedger(
      now: () => now,
      read: () async => disk,
      write: (s) async => disk = s,
    );
    await create().reserve('geoapify', ProviderPolicy.forId('geoapify'));
    expect(
      await create().reserve('geoapify', ProviderPolicy.forId('geoapify')),
      now.add(const Duration(milliseconds: 1100)),
    );
  });
  test(
    'daily response resets at UTC midnight and backoff grows to fifteen minutes',
    () async {
      var now = DateTime.utc(2026, 10, 28, 15);
      String? disk;
      final ledger = QuotaLedger(
        now: () => now,
        read: () async => disk,
        write: (s) async => disk = s,
      );
      expect(
        await ledger.failed(
          'locationiq',
          const SearchFailure(SearchFailureKind.daily),
        ),
        DateTime.utc(2026, 10, 29),
      );
      for (final seconds in [60, 120, 240, 480, 900, 900]) {
        expect(
          await ledger.failed(
            'photon',
            const SearchFailure(SearchFailureKind.rate),
          ),
          now.add(Duration(seconds: seconds)),
        );
        now = now.add(const Duration(hours: 1));
      }
    },
  );
  test('corrupt accounting fails closed', () async {
    final ledger = QuotaLedger(read: () async => 'broken', write: (_) async {});
    await expectLater(
      ledger.reserve('geoapify', ProviderPolicy.forId('geoapify')),
      throwsA(
        isA<SearchFailure>().having(
          (e) => e.kind,
          'kind',
          SearchFailureKind.accounting,
        ),
      ),
    );
  });
}
