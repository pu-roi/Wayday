import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/recommendation_page.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'paused recommendations preserve choices and explain access failure at text $scale',
      (tester) async {
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await (FontLoader(
            'Figtree',
          )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        }
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final roads = Roads();
        addTearDown(roads.client.close);
        final model = PlanningController(
          fixture().copyWith(
            errands: const [
              Errand(id: 'a', title: 'go to gym'),
              Errand(id: 'b', title: 'groceries'),
            ],
          ),
          Interpreter(),
          roads,
          MemoryItineraryRepository(),
        );
        addTearDown(model.dispose);
        await model.understand();
        model.candidates['a'] = [
          PlanCandidate(key: 'kept', place: pin, errandIds: {'a'}),
        ];
        final failure = RecommendationFailure(
          RecommendationFailureKind.access,
          RecommendationOperation.corridor,
          errandId: 'b',
          providerStatus: 9011,
        );
        model.recommendationFailure = failure;
        model.error = failure.message;
        model.failedRecommendationErrand = 'b';
        model.stage = PreparationStage.discovery;
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('recovery-capture'),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: Scaffold(
                body: RecommendationPage(
                  model: model,
                  onChange: (_) {},
                  onContinue: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Plan paused'), findsOneWidget);
        expect(find.text(failure.message), findsOneWidget);
        expect(find.text('Retry recommendations'), findsNothing);
        expect(find.text('Next: see my day'), findsNothing);
        expect(model.result, isNull);
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(
                  find.byKey(const Key('recovery-capture')),
                )
                .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dir = Directory('../../.impeccable/recommendations')
              ..createSync(recursive: true);
            File(
              '${dir.path}/recovery-$scale.png',
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('change-b')),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('change-b')).hitTestable(),
          findsOneWidget,
        );
        expect(model.candidates['a']!.single.key, 'kept');
        expect(tester.takeException(), isNull);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      },
    );
  }
}
