import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/places/data/search_quota.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/presentation/trip_place_details.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('fixture/trip-ui-kit');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  test(
    'coalesced UI Kit loads and presentation reuse dispatch and account once',
    () async {
      String? accounting;
      final budget = PlanningBudget(
        read: () async => accounting,
        write: (v) async => accounting = v,
      );
      final controller = TripPlaceDetailsController(
        QuotaLedger(
          googleBudget: budget,
          read: () async => null,
          write: (_) async {},
        ),
      );
      addTearDown(controller.dispose);
      var requests = 0;
      final gate = Completer<void>();
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'details') return null;
        requests++;
        expect(controller.visible, isTrue);
        await gate.future;
        final request = call.arguments as Map;
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('selection', {
              'placeId': request['placeId'],
              'revision': request['revision'],
              'resolved': true,
              'latitude': 14.58,
              'longitude': 121.06,
              'retrievedAtMillis': DateTime.now().millisecondsSinceEpoch,
            }),
          ),
          (_) {},
        );
        return {'count': 1};
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      controller.attach(channel);
      final first = controller.load('exact', 1),
          second = controller.load('exact', 2);
      gate.complete();
      expect((await first)['revision'], 1);
      expect((await second)['revision'], 2);
      await controller.present('exact');
      expect(requests, 1);
      expect((jsonDecode(accounting!) as Map)['testing']['usedMicros'], 20000);
    },
  );
}
