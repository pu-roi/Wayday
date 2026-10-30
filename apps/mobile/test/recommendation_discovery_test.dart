import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/recommendation_discovery.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/data/google_pin_cache.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';

void main() {
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
      expect(calls, 1);
      final choice = batches.first.single;
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
        await service.discover(
          const ErrandNeed(id: 'x', query: 'gym'),
          polyline: null,
          anchors: [pin, pin],
          limit: 3,
          cancelled: () => false,
        ),
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
