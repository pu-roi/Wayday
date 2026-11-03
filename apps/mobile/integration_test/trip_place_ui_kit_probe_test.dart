import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/planning_budget.dart';
import 'package:wayday/features/planning/data/planning_budget_storage.dart';
import 'package:wayday/features/places/data/search_quota.dart';

/// One explicit UI Kit load of Google's public Sydney-office sample Place ID.
/// No personal input, business search, routing export, retries or allowance reset.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'one existing-ID UI Kit lookup returns that ID and valid coordinates',
    (tester) async {
      expect(kDebugMode, isTrue);
      final identity = await const MethodChannel(
        'wayday/planning',
      ).invokeMapMethod<String, String>('identity');
      expect(identity?['package'], 'dev.wayday.wayday.maptest');
      expect(
        const String.fromEnvironment('GOOGLE_MAPS_ANDROID_API_KEY'),
        isNotEmpty,
        reason: 'The existing restricted SDK identity must be configured.',
      );

      final accounting = await readPlanningBudget();
      expect(
        accounting,
        isNotNull,
        reason: 'Restore disposable accounting first.',
      );
      final before = jsonDecode(accounting!) as Map;
      final previousTesting = before['testing'] as Map;
      expect(previousTesting['limitMicros'], 2000000);
      expect(previousTesting['usedMicros'], greaterThanOrEqualTo(782000));
      final marker = File(
        '${(await getApplicationSupportDirectory()).path}/ui-kit-id-probe.json',
      );
      expect(
        await marker.exists(),
        isFalse,
        reason: 'A previous probe needs explicit review; do not repeat it.',
      );

      const sampleId = 'ChIJN1t_tDeuEmsRUsoyG83frY4';
      const revision = 1;
      final ready = Completer<MethodChannel>();
      final selected = Completer<Map<Object?, Object?>>();
      MethodChannel? channel;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            appBar: AppBar(title: const Text('Isolated UI Kit lookup')),
            body: SizedBox(
              height: 320,
              child: PlatformViewLink(
                viewType: 'wayday/google_places',
                surfaceFactory: (context, controller) => AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                  gestureRecognizers: const {},
                ),
                onCreatePlatformView: (params) {
                  final controller =
                      PlatformViewsService.initExpensiveAndroidView(
                        id: params.id,
                        viewType: 'wayday/google_places',
                        layoutDirection: TextDirection.ltr,
                        onFocus: () => params.onFocusChanged(true),
                      );
                  controller.addOnPlatformViewCreatedListener(
                    params.onPlatformViewCreated,
                  );
                  controller.addOnPlatformViewCreatedListener((id) {
                    channel = MethodChannel('wayday/google_places/$id');
                    channel!.setMethodCallHandler((call) async {
                      if (call.method == 'selection' && !selected.isCompleted) {
                        selected.complete(
                          Map<Object?, Object?>.from(call.arguments as Map),
                        );
                      }
                    });
                    ready.complete(channel);
                  });
                  controller.create();
                  return controller;
                },
              ),
            ),
          ),
        ),
      );
      try {
        for (var i = 0; i < 100 && !ready.isCompleted; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(ready.isCompleted, isTrue);
        final native = await ready.future;
        final budget = PlanningBudget(allocation: () async => 2000000);
        final quota = QuotaLedger(googleBudget: budget);
        Map<Object?, Object?>? result;
        await tester.runAsync(() async {
          // Pending survives a killed host/run. Rebuilds never authorize a retry.
          await marker.writeAsString(
            jsonEncode({
              'phase': 'pending',
              'at': DateTime.now().toUtc().toIso8601String(),
            }),
            flush: true,
          );
          final wait = await quota.reserve(
            'google_ui_kit',
            ProviderPolicy.forId('google_ui_kit'),
            googleUnitMicros: 20000,
          );
          if (wait != null) {
            fail(
              'Request spacing requires a later explicit trial. No load sent.',
            );
          }
          debugPrint('WAYDAY_UI_KIT_ID_PROBE_DISPATCH calls=1');
          final loaded = await native
              .invokeMapMethod<Object?, Object?>('details', {
                'revision': revision,
                'placeId': sampleId,
              })
              .timeout(const Duration(seconds: 45));
          expect(loaded?['count'], 1);
          await native.invokeMethod<void>('show', revision);
          await native.invokeMethod<void>('visibility', true);
          result = await selected.future.timeout(const Duration(seconds: 5));
          await quota.succeeded('google_ui_kit');
        });
        expect(result?['revision'], revision);
        expect(result?['placeId'], sampleId);
        expect(result?['resolved'], isTrue);
        final latitude = result?['latitude'];
        final longitude = result?['longitude'];
        expect(latitude, isA<num>());
        expect(longitude, isA<num>());
        expect((latitude as num).isFinite && latitude.abs() <= 90, isTrue);
        expect((longitude as num).isFinite && longitude.abs() <= 180, isTrue);
        expect(result?['retrievedAtMillis'], isA<int>());
        final after = jsonDecode((await readPlanningBudget())!) as Map;
        expect(
          (after['testing'] as Map)['usedMicros'],
          (previousTesting['usedMicros'] as int) + 20000,
        );
        await marker.writeAsString(
          jsonEncode({
            'phase': 'passed',
            'sameId': true,
            'validCoordinates': true,
          }),
          flush: true,
        );
        debugPrint(
          'WAYDAY_UI_KIT_ID_PROBE_PASSED calls=1 sameId=true validCoordinates=true routingCalls=0',
        );
        await tester.pump(const Duration(seconds: 3));
      } finally {
        await channel?.invokeMethod<void>('cancel');
        channel?.setMethodCallHandler(null);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
    skip: !const bool.fromEnvironment('WAYDAY_LIVE_UI_KIT_ID_PROBE'),
  );
}
