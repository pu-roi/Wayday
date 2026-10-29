import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class _Interpreter implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([
    const ErrandNeed(
      id: 'pickup',
      query: 'meeting point',
      category: 'meeting',
      timing: 'arriveBy',
      minute: 540,
      optional: false,
    ),
    const ErrandNeed(
      id: 'food',
      query: 'pares restaurant',
      category: 'food',
      durationMinutes: 40,
      after: ['pickup', 'grocery'],
    ),
    const ErrandNeed(
      id: 'grocery',
      query: 'grocery store',
      category: 'grocery',
      items: ['toyo', 'bigas'],
      durationMinutes: 40,
    ),
    const ErrandNeed(
      id: 'icecream',
      query: 'ice cream',
      category: 'convenience',
      optional: true,
    ),
  ]);
}

const _preview = Key('review-preview');
final _day = DayPlan(
  date: '2026-10-31',
  from: 'Home',
  fromPlace: pin,
  to: 'End of the day',
  toPlace: pin,
  errands: const [
    Errand(
      id: 'pickup',
      title: 'Pick up my girlfriend',
      placeIntent: pin,
      timing: TimingRule.arriveBy,
      minute: 540,
    ),
    Errand(
      id: 'food',
      title: 'Eat pares with my love',
      durationMinutes: 40,
      durationConfirmed: true,
    ),
    Errand(
      id: 'grocery',
      title: 'Grocery',
      notes: 'Bumili ng toyo at bigas',
      durationMinutes: 40,
      durationConfirmed: true,
    ),
    Errand(id: 'icecream', title: 'Kumain ng ice cream', optional: true),
  ],
);

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['WAYDAY_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_preview),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../.impeccable/review')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final variant in [
    (390.0, 844.0, 1.0),
    (320.0, 740.0, 2.0),
    (768.0, 1024.0, 1.0),
  ]) {
    testWidgets('review preview at ${variant.$1}, text ${variant.$3}', (
      tester,
    ) async {
      if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
        await (FontLoader(
          'Figtree',
        )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      }
      tester.view.physicalSize = Size(variant.$1, variant.$2);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = variant.$3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final roads = Roads();
      addTearDown(roads.client.close);
      await tester.pumpWidget(
        RepaintBoundary(
          key: _preview,
          child: ProviderScope(
            overrides: [
              interpreterProvider.overrideWithValue(_Interpreter()),
              planningRoadsProvider.overrideWithValue(roads),
              dayRepositoryProvider.overrideWithValue(
                MemoryDayRepository(initialData: _day),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(),
              home: const PlanningView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.text('Next: find suitable places').hitTestable(),
        findsOneWidget,
      );
      await capture(tester, 'review-errands-${variant.$1.toInt()}');
      await tester.scrollUntilVisible(
        find.text('Eat pares with my love'),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eat pares with my love'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Use suggestion'));
      await tester.pumpAndSettle();
      expect(
        find.text('Next: find suitable places').hitTestable(),
        findsOneWidget,
      );
      await capture(tester, 'review-suggestion-${variant.$1.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
