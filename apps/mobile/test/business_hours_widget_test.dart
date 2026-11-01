import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/place_hours.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';
import 'recommendation_flow_test.dart' show Discovery;

const business = PlaceIntent(
  kind: PlaceKind.providerReference,
  provider: 'google_places_sdk',
  providerPlaceId: 'business',
);

class HoursMetadata extends Discovery {
  BusinessHours hours = const BusinessHours();
  Completer<RecommendationPlace?>? pending;
  int checks = 0;
  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) {
    checks++;
    return pending?.future ?? Future.value(metadata(place));
  }

  @override
  RecommendationPlace metadata(PlaceIntent p) => RecommendationPlace(
    id: 'business',
    name: 'Synthetic grocery',
    latitude: 14.58,
    longitude: 121.06,
    acquiredAt: DateTime.now(),
    hours: hours,
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
  });
  Future<PlanningController> model(HoursMetadata source) async {
    final roads = Roads();
    addTearDown(roads.client.close);
    final value = PlanningController(
      fixture(),
      Interpreter(),
      roads,
      MemoryItineraryRepository(),
      discovery: source,
      solver: (input) async => solveDay(input),
    );
    addTearDown(value.dispose);
    await value.understand();
    return value;
  }

  testWidgets(
    'a late failed hours check cannot overwrite a newly displayed place',
    (tester) async {
      final source = HoursMetadata(), controller = await model(source);
      source.hours = const BusinessHours(failed: true);
      source.pending = Completer<RecommendationPlace?>();
      Future<void> display(PlaceIntent p) => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: PlaceHours(model: controller, place: p),
          ),
        ),
      );
      await display(business);
      await tester.tap(find.text('Retry hours check'));
      await tester.pump();
      expect(source.checks, 1);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry hours check'),
            )
            .onPressed,
        isNull,
      );
      source.hours = BusinessHours(version: 1, checkedAt: DateTime.now());
      await display(
        const PlaceIntent(
          kind: PlaceKind.providerReference,
          provider: 'google_places_sdk',
          providerPlaceId: 'new-business',
        ),
      );
      source.pending!.completeError(StateError('late old place failure'));
      await tester.pumpAndSettle();
      expect(find.text('Hours not provided by Google Maps'), findsOneWidget);
      expect(
        find.text('Hours could not be checked. Your place is kept.'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'unknown, failed, stale and manual-pin hours have distinct presentation',
    (tester) async {
      final source = HoursMetadata(), controller = await model(source);
      Future<void> display(PlaceIntent place) async => tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlaceHours(model: controller, place: place),
            ),
          ),
        ),
      );
      source.hours = BusinessHours(version: 1, checkedAt: DateTime.now());
      await display(business);
      expect(find.text('Hours not provided by Google Maps'), findsOneWidget);
      expect(find.text('Retry hours check'), findsNothing);
      source.hours = const BusinessHours(failed: true);
      await display(business);
      expect(find.text('Business hours could not be checked'), findsOneWidget);
      expect(find.text('Retry hours check'), findsOneWidget);
      source.hours = BusinessHours(
        version: 1,
        checkedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );
      await display(business);
      expect(find.text('Business hours need refreshing'), findsOneWidget);
      await display(pin);
      expect(
        find.text('Business hours are unavailable for this pin.'),
        findsOneWidget,
      );
      expect(find.text('Retry hours check'), findsNothing);
    },
  );
  for (final variant in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('hours details wrap and disclose weekly data at $variant', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = HoursMetadata(), controller = await model(source);
      source.hours = BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: DateTime.now(),
        regular: {
          'periods': [
            for (var d = 0; d < 7; d++)
              {
                'open': {'day': d, 'hour': 8, 'minute': 0},
                'close': {'day': d, 'hour': 21, 'minute': 0},
              },
          ],
          'weekdays': ['Monday: 8 AM–9 PM', 'Tuesday: 8 AM–9 PM'],
        },
      );
      final capture = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: capture,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(variant.$2)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Place details')),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synthetic grocery — mahabang pangalan sa Pasig',
                    ),
                    PlaceHours(model: controller, place: business),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('Usual hours for'), findsOneWidget);
      expect(find.textContaining('Expected open'), findsNothing);
      await tester.ensureVisible(find.text('Weekly hours'));
      await tester.tap(find.text('Weekly hours'));
      await tester.pumpAndSettle();
      expect(find.text('Monday: 8 AM–9 PM'), findsOneWidget);
      expect(find.textContaining('Checked'), findsOneWidget);
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(find.byKey(capture))
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../.tools/hours-screenshots')
            ..createSync(recursive: true);
          File(
            '${dir.path}/details-${variant.$1.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
}
