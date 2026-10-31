import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'SDK not-found search is an empty result and a missing saved place needs confirmation',
    () async {
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, _) async => throw PlatformException(
          code: 'not_found',
          details: {'status': 9013},
        ),
      );
      final result = await service.discover(
        const ErrandNeed(id: 'gym', query: 'gym'),
        polyline: null,
        anchors: [pin],
        limit: 3,
        cancelled: () => false,
      );
      expect(result.outcome, DiscoveryOutcome.noMatches);
      await expectLater(
        service.hydrate(
          PlaceIntent(
            kind: PlaceKind.providerReference,
            label: 'My fixed place',
            provider: 'google_ui_kit',
            providerPlaceId: 'missing',
            googlePin: pins.lease('missing'),
          ),
        ),
        throwsA(
          isA<PlanningFailure>().having(
            (e) => e.kind,
            'kind',
            'missing_location',
          ),
        ),
      );
    },
  );
  Map<String, Object?> place({
    String name = 'Actual gym',
    List<String> types = const ['gym'],
  }) => {
    'id': 'gym',
    'name': name,
    'latitude': 14.58,
    'longitude': 121.06,
    'country': 'PH',
    'types': types,
    'at': DateTime.now().millisecondsSinceEpoch,
  };
  GoogleRecommendationDiscovery create(
    PlacesInvoker invoke, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final pins = GooglePinCache(read: () async => null, write: (_) async {});
    addTearDown(pins.dispose);
    return GoogleRecommendationDiscovery(
      QuotaLedger(read: () async => null, write: (_) async {}),
      pins,
      invoke: invoke,
      requestTimeout: timeout,
    );
  }

  Future<DiscoveryResult> search(
    GoogleRecommendationDiscovery service, {
    String? polyline = 'route',
  }) => service.discover(
    const ErrandNeed(id: 'a', query: 'gym'),
    polyline: polyline,
    anchors: [pin],
    limit: 3,
    cancelled: () => false,
  );
  test(
    'empty corridor continues to an anchor and retains actual gym identity',
    () async {
      var calls = 0;
      final result = await search(
        create((_, args) async {
          calls++;
          return args.containsKey('polyline') ? [] : [place()];
        }),
      );
      expect(result.outcome, DiscoveryOutcome.found);
      expect(result.candidates.single.place.providerPlaceId, 'gym');
      expect(result.returnedCount, 1);
      expect(calls, 2);
    },
  );
  test(
    'successful empty and rejected responses are different outcomes',
    () async {
      final empty = await search(create((_, _) async => []), polyline: null);
      expect(empty.outcome, DiscoveryOutcome.noMatches);
      final rejected = await search(
        create(
          (_, _) async => [
            place(name: ''),
            place(types: ['street_address']),
            'malformed',
          ],
        ),
        polyline: null,
      );
      expect(rejected.outcome, DiscoveryOutcome.rejected);
      expect(rejected.returnedCount, 3);
      expect(rejected.exclusions, {
        PlaceExclusion.missingName: 1,
        PlaceExclusion.addressOnly: 1,
        PlaceExclusion.malformed: 1,
      });
    },
  );
  for (final code in [
    'configuration',
    'access',
    'quota',
    'invalid_request',
    'network',
    'timeout',
    'cancelled',
    'unexpected_response',
  ]) {
    test('preserves safe $code failure and operation', () async {
      final service = create(
        (_, _) async => throw PlatformException(
          code: code,
          message: 'private data',
          details: {'status': 9011},
        ),
      );
      await expectLater(
        search(service),
        throwsA(
          isA<RecommendationFailure>()
              .having((e) => e.kind, 'kind', code)
              .having(
                (e) => e.operation,
                'operation',
                RecommendationOperation.corridor,
              )
              .having((e) => e.providerStatus, 'status', 9011),
        ),
      );
    });
  }
  test(
    'retry after caller timeout attaches to the still running native request',
    () async {
      var calls = 0;
      final pending = Completer<List<Object?>>();
      final service = create((_, _) {
        calls++;
        return pending.future;
      }, timeout: const Duration(milliseconds: 20));
      await expectLater(
        search(service, polyline: null),
        throwsA(
          isA<RecommendationFailure>().having((e) => e.kind, 'kind', 'timeout'),
        ),
      );
      final retry = search(service, polyline: null);
      pending.complete([place()]);
      expect((await retry).candidates, hasLength(1));
      expect(calls, 1);
    },
  );

  test(
    'provider access status survives the Flutter adapter without raw messages',
    () async {
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, _) async => throw PlatformException(
          code: 'access',
          message: 'Raw private provider message',
          details: {'status': 9011},
        ),
      );
      await expectLater(
        service.discover(
          const ErrandNeed(id: 'gym', query: 'gym'),
          polyline: 'route',
          anchors: [pin],
          limit: 3,
          cancelled: () => false,
        ),
        throwsA(
          isA<PlanningFailure>()
              .having((e) => e.kind, 'kind', 'access')
              .having(
                (e) => e.message.contains('Raw private'),
                'sanitized',
                false,
              ),
        ),
      );
    },
  );

  test(
    'closing while waiting for accounting never dispatches a provider request',
    () async {
      final gate = Completer<String?>();
      var cancelled = false, calls = 0;
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () => gate.future, write: (_) async {}),
        pins,
        invoke: (_, args) async {
          calls++;
          return [];
        },
      );
      final request = service.discover(
        const ErrandNeed(id: 'a', query: 'coffee'),
        polyline: 'route',
        anchors: [pin],
        limit: 3,
        cancelled: () => cancelled,
      );
      cancelled = true;
      gate.complete(null);
      await expectLater(
        request,
        throwsA(
          isA<PlanningFailure>().having((e) => e.kind, 'kind', 'cancelled'),
        ),
      );
      expect(calls, 0);
    },
  );
  test(
    'confirmed Google street addresses can hydrate without becoming automatic businesses',
    () async {
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      addTearDown(pins.dispose);
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, args) async => [
          {
            'id': 'home',
            'name': 'A street address',
            'latitude': 14.58,
            'longitude': 121.06,
            'types': ['street_address'],
            'country': 'PH',
            'at': DateTime.now().millisecondsSinceEpoch,
          },
        ],
      );
      final place = PlaceIntent(
        kind: PlaceKind.providerReference,
        label: 'Home',
        provider: 'google_ui_kit',
        providerPlaceId: 'home',
        googlePin: pins.lease('home'),
      );
      final result = await service.hydrate(place);
      expect(result!.eligible, isFalse);
      expect(place.hasCoordinates, isTrue);
    },
  );
  test(
    'coalesces unchanged corridor requests and retains real names outside references',
    () async {
      var calls = 0;
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (method, args) async {
          calls++;
          return [
            {
              'id': 'coffee',
              'name': 'Actual Coffee Shop',
              'latitude': 14.58,
              'longitude': 121.06,
              'types': ['cafe'],
              'at': DateTime.now().millisecondsSinceEpoch,
            },
          ];
        },
      );
      addTearDown(pins.dispose);
      const need = ErrandNeed(id: 'coffee-errand', query: 'coffee');
      final batches = await Future.wait(
        List.generate(
          2,
          (_) => service.discover(
            need,
            polyline: 'encoded',
            anchors: [pin],
            limit: 1,
            cancelled: () => false,
          ),
        ),
      );
      expect(calls, 2);
      final choice = batches.first.candidates.single;
      expect(service.metadata(choice.place)!.name, 'Actual Coffee Shop');
      expect(choice.place.label, isEmpty);
      expect(choice.place.hasCoordinates, isTrue);
      expect(
        choice.place.toJson().toString(),
        isNot(contains('Actual Coffee Shop')),
      );
    },
  );
  test(
    'round trips fall back to bounded anchors; cancellation dispatches nothing',
    () async {
      var calls = 0;
      final pins = GooglePinCache(read: () async => null, write: (_) async {});
      final service = GoogleRecommendationDiscovery(
        QuotaLedger(read: () async => null, write: (_) async {}),
        pins,
        invoke: (_, args) async {
          calls++;
          return [];
        },
      );
      addTearDown(pins.dispose);
      expect(
        (await service.discover(
          const ErrandNeed(id: 'x', query: 'gym'),
          polyline: null,
          anchors: [pin, pin],
          limit: 3,
          cancelled: () => false,
        )).candidates,
        isEmpty,
      );
      expect(calls, 1);
      await expectLater(
        service.discover(
          const ErrandNeed(id: 'y', query: 'laundry'),
          polyline: 'new',
          anchors: [pin],
          limit: 3,
          cancelled: () => true,
        ),
        throwsA(isA<PlanningFailure>()),
      );
      expect(calls, 1);
    },
  );
}
