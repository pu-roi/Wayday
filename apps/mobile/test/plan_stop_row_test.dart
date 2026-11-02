import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/plan_stop_row.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'helpers/planning_fixtures.dart';
import 'recommendation_flow_test.dart' show Discovery;

class _PlaceMetadata extends Discovery {
  bool rating = true;
  @override
  RecommendationPlace metadata(PlaceIntent place) => RecommendationPlace(
    id: 'fixture',
    name: 'Synthetic neighborhood grocery',
    locality: 'Pasig, Metro Manila',
    address:
        '20 Stella Maris Avenue, Barangay Maybunga, Pasig, 1607 Metro Manila, Philippines',
    latitude: 14.58,
    longitude: 121.06,
    acquiredAt: DateTime.now(),
    rating: rating ? 4.5 : null,
    ratingCount: rating ? 120 : null,
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final variant in [
    (390.0, 844.0, 1.0),
    (320.0, 740.0, 2.0),
    (768.0, 1024.0, 1.0),
  ]) {
    testWidgets('stop details group facts and retain controls at $variant', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, variant.$2);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final roads = Roads(), discovery = _PlaceMetadata();
      final model = PlanningController(
        fixture(),
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        discovery: discovery,
        solver: (input) async => solveDay(input),
      );
      addTearDown(model.dispose);
      addTearDown(roads.client.close);
      await model.understand();
      model.applyReview();
      await model.calculate();
      var expanded = false, ready = true, changes = 0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(variant.$1, variant.$2),
              textScaler: TextScaler.linear(variant.$3),
            ),
            child: Scaffold(
              appBar: AppBar(title: const Text('Your plan')),
              body: RepaintBoundary(
                key: const Key('details-capture'),
                child: ColoredBox(
                  color: WaydayColors.canvas,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          PlanStopRow(
                            model: model,
                            e: model.day.errands.first,
                            place: pin,
                            index: 0,
                            ready: ready,
                            busy: false,
                            expanded: expanded,
                            onChange: () => changes++,
                            onSelect: () {},
                            onExpand: () =>
                                setState(() => expanded = !expanded),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Business hours'), findsNothing);
      expect(find.textContaining('Arrive '), findsOneWidget);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Place'), findsOneWidget);
      expect(find.text('Visit timing'), findsOneWidget);
      expect(find.text(discovery.metadata(pin).address), findsOneWidget);
      expect(find.textContaining('Google rating'), findsOneWidget);
      await tester.ensureVisible(find.text('Business hours'));
      await tester.pumpAndSettle();
      expect(
        find.text('Business hours are unavailable for this pin.'),
        findsOneWidget,
      );
      expect(find.text('Closed now'), findsNothing);
      expect(discovery.calls, 0);
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        // Top-of-details view; facts below the viewport remain scrollable.
        await tester.drag(find.byType(ListView), const Offset(0, 2000));
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(
                find.byKey(const Key('details-capture')),
              )
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../.tools/ui-refinement')
            ..createSync(recursive: true);
          File(
            '${dir.path}/plan-details-${variant.$1.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      update(() {
        ready = false;
        discovery.rating = false;
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Arrive '), findsNothing);
      expect(find.textContaining('Leave '), findsNothing);
      expect(find.textContaining('Calculated '), findsNothing);
      expect(find.textContaining('Google rating'), findsNothing);
      await tester.ensureVisible(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      expect(changes, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
