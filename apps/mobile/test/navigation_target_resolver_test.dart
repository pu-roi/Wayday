import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/planning/data/navigation_target_resolver.dart';
import 'package:wayday/features/planning/domain/trip_waypoints.dart';

void main() {
  final now = DateTime.utc(2026, 11, 3);
  TripWaypoint google(String id, String task) => TripWaypoint(
    PlaceIntent(
      provider: 'google_places_sdk',
      providerPlaceId: id,
      googlePin: GooglePinLease(now: () => now)
        ..latitude = 1
        ..longitude = 2
        ..acquiredAt = now,
    ),
    [task],
  );
  Map<Object?, Object?> response(String id, int revision) => {
    'placeId': id,
    'revision': revision,
    'resolved': true,
    'latitude': 14.58,
    'longitude': 121.06,
    'retrievedAtMillis': now.millisecondsSinceEpoch,
  };
  test(
    'Finish cleanup serializes with purge and a subsequent trip resolution',
    () async {
      String? disk = '{"version":1,"trips":{"finished":{}}}';
      final readGate = Completer<String?>(),
          writing = Completer<void>(),
          releaseWrite = Completer<void>();
      var readCount = 0, nativeCalls = 0;
      final purge = NavigationTargetResolver.purgeStored(
        read: () async {
          readCount++;
          return readGate.future;
        },
        write: (v) async => disk = v,
      );
      final cleanup = NavigationTargetResolver.clearFinished(
        'finished',
        read: () async => disk,
        write: (v) async {
          writing.complete();
          await releaseWrite.future;
          disk = v;
        },
      );
      final resolver = NavigationTargetResolver(
        now: () => now,
        read: () async => disk,
        write: (v) async => disk = v,
        load: (id, revision) async {
          nativeCalls++;
          return response(id, revision);
        },
      );
      final next = resolver.resolve(
        'next',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => true,
      );
      readGate.complete(disk);
      await purge;
      await writing.future;
      final secondPurge = NavigationTargetResolver.purgeStored(
        read: () async {
          readCount++;
          return disk;
        },
        write: (v) async => disk = v,
      );
      await Future<void>.delayed(Duration.zero);
      expect(readCount, 1);
      expect(nativeCalls, 0);
      releaseWrite.complete();
      await cleanup;
      await next;
      await secondPurge;
      expect(disk, contains('next'));
      expect(disk, isNot(contains('finished')));
      expect(nativeCalls, 1);
    },
  );
  test(
    'an unfinished lookup blocks another resolver until actual work settles',
    () async {
      final pending = Completer<Map<Object?, Object?>>();
      var revision = 0;
      final first = NavigationTargetResolver(
        now: () => now,
        read: () async => null,
        write: (_) async {},
        load: (_, value) {
          revision = value;
          return pending.future;
        },
      );
      final second = NavigationTargetResolver(
        now: () => now,
        read: () async => null,
        write: (_) async {},
        load: (_, _) async => throw StateError('duplicate dispatch'),
      );
      final work = first.resolve(
        'trip',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => true,
      );
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        second.resolve(
          'trip',
          [google('a', 'one')],
          allowFetch: true,
          stillCurrent: () => true,
        ),
        throwsA(anything),
      );
      pending.complete(response('a', revision));
      await work;
    },
  );
  test(
    'a standard SDK cache entry cannot substitute for a UI Kit acquisition',
    () async {
      String? disk =
          '{"version":1,"trips":{"trip":{"a":{"phase":"ready","source":"google_places_sdk","at":"2026-11-03T00:00:00Z","lat":1,"lon":2}}}}';
      var calls = 0;
      final resolver = NavigationTargetResolver(
        now: () => now,
        read: () async => disk,
        write: (v) async => disk = v,
        load: (id, revision) async {
          calls++;
          return response(id, revision);
        },
      );
      final points = await resolver.resolve(
        'trip',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => true,
      );
      expect(calls, 1);
      expect(points.single.coordinate!.latitude, 14.58);
    },
  );
  for (final invalid in [
    'latitude',
    'longitude',
    'future',
    'expired',
    'revision',
    'unresolved',
  ]) {
    test(
      'rejects $invalid UI Kit metadata without persisting coordinates',
      () async {
        String? disk;
        final resolver = NavigationTargetResolver(
          now: () => now,
          read: () async => disk,
          write: (v) async => disk = v,
          load: (id, revision) async {
            final result = response(id, revision);
            switch (invalid) {
              case 'latitude':
                result['latitude'] = double.nan;
              case 'longitude':
                result['longitude'] = 181;
              case 'future':
                result['retrievedAtMillis'] = now
                    .add(const Duration(seconds: 1))
                    .millisecondsSinceEpoch;
              case 'expired':
                result['retrievedAtMillis'] = now
                    .subtract(const Duration(days: 30))
                    .millisecondsSinceEpoch;
              case 'revision':
                result['revision'] = revision + 1;
              case 'unresolved':
                result['resolved'] = false;
            }
            return result;
          },
        );
        await expectLater(
          resolver.resolve(
            'trip',
            [google('a', 'one')],
            allowFetch: true,
            stillCurrent: () => true,
          ),
          throwsA(anything),
        );
        expect(disk, isNot(contains('121.06')));
      },
    );
  }
  test(
    'expired and interrupted caches require explicit recovery; corrupt cache is repairable explicitly',
    () async {
      String? disk;
      var calls = 0, clock = now;
      final resolver = NavigationTargetResolver(
        now: () => clock,
        read: () async => disk,
        write: (v) async => disk = v,
        load: (id, revision) async {
          calls++;
          return {
            ...response(id, revision),
            'retrievedAtMillis': clock.millisecondsSinceEpoch,
          };
        },
      );
      final points = [google('a', 'one')];
      await resolver.resolve(
        'trip',
        points,
        allowFetch: true,
        stillCurrent: () => true,
      );
      clock = clock.add(const Duration(days: 30));
      await expectLater(
        resolver.resolve(
          'trip',
          points,
          allowFetch: false,
          stillCurrent: () => true,
        ),
        throwsA(anything),
      );
      expect(calls, 1);
      expect(
        disk,
        isNot(contains('121.06')),
        reason: 'Expired bytes must be removed even when recovery is required.',
      );
      disk =
          '{"version":1,"trips":{"trip":{"a":{"source":"googleUiKit","phase":"pending"}}}}';
      await expectLater(
        resolver.resolve(
          'trip',
          points,
          allowFetch: false,
          stillCurrent: () => true,
        ),
        throwsA(anything),
      );
      expect(calls, 1);
      disk = 'corrupt';
      await expectLater(
        resolver.resolve(
          'trip',
          points,
          allowFetch: false,
          stillCurrent: () => true,
        ),
        throwsA(anything),
      );
      await resolver.resolve(
        'trip',
        points,
        allowFetch: true,
        stillCurrent: () => true,
      );
      expect(calls, 2);
    },
  );
  test(
    'same-ID UI Kit targets preserve order and never reuse SDK coordinates',
    () async {
      String? disk;
      final calls = <String>[];
      final resolver = NavigationTargetResolver(
        now: () => now,
        read: () async => disk,
        write: (value) async => disk = value,
        load: (id, revision) async {
          calls.add(id);
          return response(id, revision);
        },
      );
      final points = [
        google('branch-a', 'one'),
        google('branch-b', 'two'),
        google('branch-a', 'three'),
      ];
      final resolved = await resolver.resolve(
        'trip',
        points,
        allowFetch: true,
        stillCurrent: () => true,
      );
      expect(calls, ['branch-a', 'branch-b']);
      expect(resolved.map((p) => p.errandIds.single), ['one', 'two', 'three']);
      expect(resolved.every((p) => p.coordinate!.latitude == 14.58), isTrue);
      expect(points.first.place.latitude, 1);
      expect(identical(resolved.first.place, points.first.place), isTrue);
      final restored = NavigationTargetResolver(
        now: () => now,
        read: () async => disk,
        write: (value) async => disk = value,
        load: (_, _) async => throw StateError('must not reload'),
      );
      expect(
        (await restored.resolve(
          'trip',
          points,
          allowFetch: false,
          stillCurrent: () => true,
        )).first.coordinate!.longitude,
        121.06,
      );
    },
  );
  test(
    'missing cache on recovery requires explicit retry without dispatch',
    () async {
      var calls = 0;
      final resolver = NavigationTargetResolver(
        now: () => now,
        read: () async => null,
        write: (_) async {},
        load: (id, revision) async {
          calls++;
          return response(id, revision);
        },
      );
      await expectLater(
        resolver.resolve(
          'trip',
          [google('a', 'one')],
          allowFetch: false,
          stillCurrent: () => true,
        ),
        throwsA(anything),
      );
      expect(calls, 0);
    },
  );
  test('wrong ID and stale callbacks cannot enter the target cache', () async {
    String? disk;
    final resolver = NavigationTargetResolver(
      now: () => now,
      read: () async => disk,
      write: (v) async => disk = v,
      load: (_, revision) async => response('wrong-branch', revision),
    );
    await expectLater(
      resolver.resolve(
        'trip',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => true,
      ),
      throwsA(anything),
    );
    expect(disk, isNot(contains('121.06')));
    var current = true;
    final stale = NavigationTargetResolver(
      now: () => now,
      read: () async => null,
      write: (v) async => disk = v,
      load: (id, revision) async {
        current = false;
        return response(id, revision);
      },
    );
    await expectLater(
      stale.resolve(
        'trip',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => current,
      ),
      throwsA(anything),
    );
    expect(disk, isNot(contains('121.06')));
  });
  test('failed target persistence prevents preparation success', () async {
    var writes = 0;
    final resolver = NavigationTargetResolver(
      now: () => now,
      read: () async => null,
      write: (_) async {
        if (++writes > 1) throw StateError('disk full');
      },
      load: (id, revision) async => response(id, revision),
    );
    await expectLater(
      resolver.resolve(
        'trip',
        [google('a', 'one')],
        allowFetch: true,
        stillCurrent: () => true,
      ),
      throwsA(anything),
    );
  });
  test(
    'independent coordinates pass unchanged without a UI Kit request',
    () async {
      final point = TripWaypoint(
        const PlaceIntent(latitude: 14.5, longitude: 121.1),
        ['one'],
      );
      final resolver = NavigationTargetResolver(
        now: () => now,
        read: () async => null,
        write: (_) async {},
        load: (_, _) async => throw StateError('must not load'),
      );
      final result = await resolver.resolve(
        'trip',
        [point],
        allowFetch: true,
        stillCurrent: () => true,
      );
      expect(result.single.coordinate!.latitude, 14.5);
      expect(result.single.target!.placeId, isNull);
    },
  );
}
