import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/planning/presentation/review_question_state.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'helpers/planning_fixtures.dart';

class ReviewUnderstanding implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation(const [
    ErrandNeed(
      id: 'laundry',
      query: 'laundry',
      locationIntent: LocationIntent.specific,
    ),
    ErrandNeed(
      id: 'gym',
      query: 'gym',
      locationIntent: LocationIntent.unclear,
      question: 'Your usual gym, or should Wayday recommend one?',
      questionKind: 'location',
      questionRequired: true,
    ),
    ErrandNeed(
      id: 'groceries',
      query: 'grocery store',
      category: 'grocery',
      locationIntent: LocationIntent.flexible,
      question: 'What items?',
      questionKind: 'preference',
      questionRequired: false,
    ),
  ]);
}

void main() {
  for (final variant in [
    (390.0, 844.0, 1.0),
    (320.0, 844.0, 2.0),
    (768.0, 1024.0, 1.0),
  ]) {
    testWidgets(
      'review retains labels and distinguishes question states ${variant.$1}/${variant.$3}',
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
        final roads = Roads();
        addTearDown(roads.client.close);
        final source = fixture().copyWith(
          errands: const [
            Errand(id: 'laundry', title: 'pick up laundry'),
            Errand(id: 'gym', title: 'go to gym'),
            Errand(id: 'groceries', title: 'groceries'),
          ],
        );
        const boundary = Key('location-review-capture');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              interpreterProvider.overrideWithValue(ReviewUnderstanding()),
              planningRoadsProvider.overrideWithValue(roads),
              dayRepositoryProvider.overrideWithValue(
                MemoryDayRepository(initialData: source),
              ),
            ],
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildTheme(),
                home: const PlanningView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final model = tester
            .widget<PlanningReview>(find.byType(PlanningReview))
            .model;
        final grocery = model.reviewErrands.last;
        await model.clarifications.applyStructured(
          model.questionContext(grocery),
          const ClarificationResolution(
            outcome: 'flexible',
            kind: 'preference',
            summary: 'Flexible grocery shopping for food and hygiene supplies.',
            locationIntent: LocationIntent.flexible,
          ),
          'Let Wayday recommend',
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.text('Recheck location needs with Gemini'), findsNothing);
      expect(find.textContaining('API credit'), findsNothing);
        expect(
          find.text('Build recommendations').hitTestable(),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Choose actual location'),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Choose actual location').hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Needs your answer'), findsOneWidget);
        // Reveal the saved answer without relying on offscreen lazy-list children.
        await tester.ensureVisible(
          find.text('Flexible grocery shopping for food and hygiene supplies.'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ReviewQuestionState), findsWidgets);
        final semantics = tester.ensureSemantics();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
        if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final image = await tester
                .renderObject<RenderRepaintBoundary>(find.byKey(boundary))
                .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('../../.impeccable/clarification')
              ..createSync(recursive: true);
            File(
              '${dir.path}/location-review-${variant.$1.toInt()}-${variant.$3}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
