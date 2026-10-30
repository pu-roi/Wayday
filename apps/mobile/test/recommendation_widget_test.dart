import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/recommendation_page.dart';
import 'package:wayday/features/planning/presentation/place_alternatives_page.dart';
import 'package:wayday/features/places/presentation/google_place_attribution.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  testWidgets(
    'provider credits decode HTML and preserve emphasized linked text without scripts',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GooglePlaceAttribution(
              credits: const [
                '<a href="https://example.com/"><b>Supplier &amp; Friends</b></a><script>hidden()</script>',
              ],
            ),
          ),
        ),
      );
      expect(
        find.text('Supplier & Friends', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('hidden()', findRichText: true), findsNothing);
      expect(find.text('Google Maps'), findsOneWidget);
    },
  );
  for (final variant in [
    (390.0, 844.0, 1.0),
    (320.0, 740.0, 2.0),
    (768.0, 1024.0, 1.0),
  ]) {
    testWidgets(
      'recommendations reflow and keep choices at ${variant.$1} text ${variant.$3}',
      (tester) async {
        tester.view.physicalSize = Size(variant.$1, variant.$2);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = variant.$3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await (FontLoader(
            'Figtree',
          )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        final roads = Roads(),
            model = PlanningController(
              fixture(),
              Interpreter(),
              Roads(),
              MemoryItineraryRepository(),
              solver: (input) async => solveDay(input),
            );
        addTearDown(model.dispose);
        addTearDown(roads.client.close);
        addTearDown(model.roads.client.close);
        await model.understand();
        model.applyReview();
        await model.calculate();
        var changed = '';
        const boundary = Key('recommendation-capture');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: Scaffold(
                appBar: AppBar(title: const Text('Recommended places')),
                body: RecommendationPage(
                  model: model,
                  onChange: (e) => changed = e.id,
                  onContinue: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Use name only'), findsNothing);
        expect(find.text('Your selected location.'), findsNWidgets(2));
        expect(find.text('Next: see my day').hitTestable(), findsOneWidget);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('../../.impeccable/recommendations')
              ..createSync(recursive: true);
            File(
              '${dir.path}/recommendations-${variant.$1.toInt()}-${variant.$3}.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Grocery').first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Change place').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Change place').first);
        expect(changed, 'a');
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(),
            home: PlaceAlternativesPage(model: model, errandId: 'a'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Search for a place').hitTestable(), findsOneWidget);
        expect(find.text('Find more along this trip'), findsNothing);
        await tester.tap(find.byTooltip('Next errand'));
        await tester.pumpAndSettle();
        expect(find.textContaining('2 of 2'), findsOneWidget);
        await tester.tap(find.byTooltip('Previous errand'));
        await tester.pumpAndSettle();
        expect(find.textContaining('1 of 2'), findsOneWidget);
        expect(model.result, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
