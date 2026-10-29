import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'helpers/planning_fixtures.dart';

Future<void> launchReview(
  WidgetTester tester, {
  double scale = 1,
  DayPlan? day,
  ErrandInterpreter? interpreter,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final roads = Roads();
  addTearDown(roads.client.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        interpreterProvider.overrideWithValue(interpreter ?? Interpreter()),
        planningRoadsProvider.overrideWithValue(roads),
        dayRepositoryProvider.overrideWithValue(
          MemoryDayRepository(initialData: day ?? fixture()),
        ),
      ],
      child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
    ),
  );
  await tester.pumpAndSettle();
}

class _Questions implements ErrandInterpreter {
  _Questions(this.needs);
  final List<ErrandNeed> needs;
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation(needs);
}

void main() {
  testWidgets('correcting the trip date clears the stale departure error', (
    tester,
  ) async {
    const message =
        'The departure is in the past. Choose a new date and departure time.';
    await launchReview(tester, day: fixture().copyWith(date: '2020-01-01'));
    await tester.tap(find.text('Next: find suitable places'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('Trip details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2020-01-01'));
    await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      await tester.tap(find.text('2020-01-01'));
      await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    await tester.tap(find.text('Next: find suitable places'));
    await tester.pumpAndSettle();
    expect(find.text('Build my day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correcting departure time clears the old validation error', (
    tester,
  ) async {
    const message = 'The final deadline must follow departure.';
    await launchReview(tester, day: fixture().copyWith(departure: 1080));
    await tester.tap(find.text('Next: find suitable places'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('Trip details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Departure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('8:00 AM'));
    await tester.tap(find.text('Save time'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNothing);
    await tester.tap(find.text('Next: find suitable places'));
    await tester.pumpAndSettle();
    expect(find.text('Build my day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saved points hide redundant questions and empty places show recommendations',
    (tester) async {
      await launchReview(
        tester,
        day: fixture().copyWith(
          errands: [
            fixture().errands.first,
            const Errand(id: 'b', title: 'Kumain ng ice cream'),
          ],
        ),
        interpreter: _Questions(const [
          ErrandNeed(
            id: 'a',
            query: 'grocery',
            category: 'grocery',
            question: 'Where is the grocery store located?',
          ),
          ErrandNeed(
            id: 'b',
            query: 'ice cream',
            category: 'convenience',
            question: 'Which store would you like to visit?',
          ),
        ]),
      );
      expect(find.text('Where is the grocery store located?'), findsNothing);
      expect(find.text('Which store would you like to visit?'), findsNothing);
      expect(find.text('Place recommendations next'), findsOneWidget);
      expect(find.text('Choose actual location'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing private point shows picker action without duplicate question',
    (tester) async {
      await launchReview(
        tester,
        day: fixture().copyWith(
          errands: const [Errand(id: 'a', title: 'Pick up Ana')],
        ),
        interpreter: _Questions(const [
          ErrandNeed(
            id: 'a',
            query: 'pickup',
            category: 'meeting',
            question: 'Where should I pick up Ana?',
          ),
        ]),
      );
      expect(find.text('Where should I pick up Ana?'), findsNothing);
      expect(find.text('Choose actual location'), findsOneWidget);
      expect(find.text('Place recommendations next'), findsNothing);
    },
  );

  testWidgets('review removes ambiguous controls and keeps Next visible', (
    tester,
  ) async {
    await launchReview(tester);
    expect(find.text('Review'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Review errands'), findsOneWidget);
    final next = find.text('Next: find suitable places');
    expect(tester.getRect(next).bottom, lessThan(844));
    expect(next.hitTestable(), findsOneWidget);
    expect(find.text('1 suggested change'), findsOneWidget);
    expect(find.text('Search need:'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'only applicable changes are offered and selection is reversible',
    (tester) async {
      await launchReview(tester);
      await tester.tap(find.text(fixture().errands.last.title));
      await tester.pumpAndSettle();
      expect(find.text('Suggested: After Grocery'), findsOneWidget);
      // Both visit lengths are confirmed; Gemini's 15 minutes is irrelevant.
      expect(find.text('Suggested: 15 min'), findsNothing);
      final use = find.text('Use suggestion');
      await tester.ensureVisible(use);
      await tester.tap(use);
      await tester.pumpAndSettle();
      expect(find.text('Suggestion selected'), findsOneWidget);
      final model = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model;
      await tester.tap(find.text('Next: find suitable places'));
      await tester.pumpAndSettle();
      expect(model.day.errands.last.afterErrandIds, ['a']);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(fixture().errands.last.title));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keep current'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep current'));
      await tester.pumpAndSettle();
      expect(find.text('Current settings kept'), findsOneWidget);
      await tester.tap(find.text('Next: find suitable places'));
      await tester.pumpAndSettle();
      expect(model.day.errands.last.afterErrandIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('trip controls and expanded details reflow at large text', (
    tester,
  ) async {
    await launchReview(tester, scale: 2);
    await tester.tap(find.text('Trip details'));
    await tester.pumpAndSettle();
    expect(find.text('Departure'), findsOneWidget);
    expect(find.text('Finish the day by'), findsOneWidget);
    expect(
      find.text('Next: find suitable places').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
