import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'fresh_analysis_test.dart' show FreshInterpreter;
import 'helpers/planning_fixtures.dart';

void main() {
  for (final layout in [(390.0, 1.0), (320.0, 2.0)]) {
    testWidgets('fresh analysis retains review controls at $layout', (
      tester,
    ) async {
      tester.view.physicalSize = Size(layout.$1, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = layout.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final interpreter = FreshInterpreter()..wait = Completer<void>();
      final roads = Roads();
      final model = PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
      );
      await model.understand();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: ListenableBuilder(
              listenable: model,
              builder: (context, _) => PlanningReview(
                model: model,
                tripDetails: const Text('Trip settings'),
                footer: const SizedBox(),
                onEdit: (_) {},
                onLocation: (_) {},
                onClarify: (_) {},
                onDefer: (_) {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Analyze again'), findsOneWidget);
      await tester.tap(find.text('Analyze again'));
      await tester.pump();
      expect(find.text('Analyzing…'), findsOneWidget);
      expect(interpreter.generations, 1);
      expect(tester.takeException(), isNull);
      interpreter.wait!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Analyze again'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      model.dispose();
      roads.client.close();
    });
  }
}
