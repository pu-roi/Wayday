import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/app/theme.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/planning/presentation/planning_view.dart';
import 'package:wayday/features/planning/presentation/planning_review.dart';
import 'package:wayday/features/planning/presentation/clarification_sheet.dart';
import 'package:wayday/features/today/data/day_repository.dart';
import 'package:wayday/features/today/presentation/today_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class _Questions implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([
    for (final e in day.errands)
      ErrandNeed(
        id: e.id,
        query: 'grocery store',
        category: 'grocery',
        question: 'What specific grocery items do you need?',
        questionKind: 'preference',
        questionRequired: false,
      ),
  ]);
}

class _Answers implements ClarificationResolver {
  int calls = 0;
  VoidCallback? onAnswer;
  String? received;
  Completer<ClarificationResolution>? pending;
  @override
  Future<ClarificationResolution> resolve(
    ClarificationContext context,
    String answer, {
    List<String> history = const [],
    bool retry = false,
    bool savedOnly = false,
  }) async {
    calls++;
    onAnswer?.call();
    received = answer;
    return pending?.future ??
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'General groceries · Choose items at the store',
          query: 'grocery store',
        );
  }
}

class _FlakyStorage implements ClarificationRepository {
  bool broken = false;
  final memory = MemoryClarificationRepository();
  @override
  Future<ClarificationSession> read(String key) => memory.read(key);
  @override
  Future<void> save(String key, ClarificationSession session) async {
    if (broken) throw StateError('Disk full');
    await memory.save(key, session);
  }
}

const _capture = Key('clarification-capture');
Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['WAYDAY_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_capture),
    );
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../../.impeccable/clarification')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _launch(
  WidgetTester tester,
  _Answers answers, {
  double scale = 1,
  double width = 390,
  DayPlan? day,
  ClarificationRepository? repository,
}) async {
  if (Platform.environment['WAYDAY_CAPTURE'] == '1') {
    await (FontLoader(
      'Figtree',
    )..addFont(rootBundle.load('assets/fonts/Figtree.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  }
  tester.view.physicalSize = Size(width, 844);
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
        interpreterProvider.overrideWithValue(_Questions()),
        if (repository != null)
          clarificationRepositoryProvider.overrideWithValue(repository),
        clarificationResolverProvider.overrideWithValue(answers),
        planningRoadsProvider.overrideWithValue(roads),
        dayRepositoryProvider.overrideWithValue(
          MemoryDayRepository(
            initialData:
                day ??
                fixture().copyWith(
                  errands: const [Errand(id: 'a', title: 'Groceries')],
                ),
          ),
        ),
      ],
      child: RepaintBoundary(
        key: _capture,
        child: MaterialApp(theme: buildTheme(), home: const PlanningView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder get question =>
    find.text('Optional: What specific grocery items do you need?');
void main() {
  testWidgets(
    'focused sheet preserves a draft, uses Taglish, shows an editable outcome',
    (tester) async {
      final answers = _Answers();
      await _launch(tester, answers);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(find.text('Edit errand'), findsNothing);
      expect(find.text('Use answer'), findsOneWidget);
      const text = 'Di ko pa alam, titignan ko pa lang pagpunta ko doon';
      await tester.enterText(find.byType(TextField), text);
      await tester.pumpAndSettle();
      await capture(tester, 'answer-sheet');
      await tester.tap(find.byTooltip('Close answer'));
      await tester.pumpAndSettle();
      expect(answers.calls, 0);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        text,
      );
      await tester.tap(find.text('Use answer'));
      await tester.pumpAndSettle();
      expect(answers.received, text);
      expect(answers.calls, 1);
      expect(question, findsNothing);
      expect(
        find.text('General groceries · Choose items at the store'),
        findsOneWidget,
      );
      expect(find.text('Anytime · 15 min estimate'), findsOneWidget);
      await capture(tester, 'answered-review');
      await tester.tap(
        find.text('General groceries · Choose items at the store'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        text,
      );
    },
  );
  testWidgets(
    'closing during processing keeps the work and prevents duplicate submission',
    (tester) async {
      final answers = _Answers()
        ..pending = Completer<ClarificationResolution>();
      await _launch(tester, answers);
      await tester.tap(question);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Not sure');
      await tester.pump();
      await tester.tap(find.text('Use answer'));
      await tester.pump();
      expect(find.text('Understanding your answer…'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Use answer'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Close answer'));
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pump();
      expect(answers.calls, 1);
      answers.pending!.complete(
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'General groceries',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ClarificationSheet), findsNothing);
      expect(find.text('General groceries'), findsOneWidget);
      expect(answers.calls, 1);
    },
  );
  testWidgets(
    'narrow large text sheet scrolls above keyboard with accessible controls',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _launch(tester, _Answers(), width: 320, scale: 2);
      await tester.scrollUntilVisible(
        question,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(question);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Not sure');
      await tester.ensureVisible(find.text('Use answer'));
      await tester.pumpAndSettle();
      expect(find.text('Use answer').hitTestable(), findsOneWidget);
      expect(
        tester.getRect(find.text('Use answer')).bottom,
        lessThan(844 - 280),
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await capture(tester, 'large-text-keyboard');
      semantics.dispose();
    },
  );
  testWidgets(
    'explicit typed flexibility applies locally without a language request',
    (tester) async {
      final answers = _Answers();
      await _launch(tester, answers);
      await tester.tap(question);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let Wayday recommend'));
      await tester.pumpAndSettle();
      expect(
        find.text('General groceries · Choose items at the store'),
        findsOneWidget,
      );
      expect(answers.calls, 0);
      expect(find.text('Anytime · 15 min estimate'), findsOneWidget);
    },
  );
  testWidgets(
    'deferral previews dependents, preserves Today and requires explicit inclusion',
    (tester) async {
      final answers = _Answers();
      final source = fixture().copyWith(
        errands: const [
          Errand(id: 'a', title: 'Groceries'),
          Errand(
            id: 'b',
            title: 'Eat pares',
            placeIntent: pin,
            afterErrandIds: ['a'],
          ),
          Errand(id: 'c', title: 'Gym', placeIntent: pin),
        ],
      );
      await _launch(tester, answers, day: source);
      final model = tester
          .widget<PlanningReview>(find.byType(PlanningReview))
          .model;
      await tester.tap(question.first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Plan the other errands'));
      await tester.tap(find.text('Plan the other errands'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ClarificationSheet),
          matching: find.textContaining('Eat pares · Depends'),
        ),
        findsOneWidget,
      );
      expect(model.deferred, isEmpty);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Leave out of this plan'),
      );
      await tester.pumpAndSettle();
      expect(model.deferred.keys, containsAll(['a', 'b']));
      expect(model.activeErrands.single.id, 'c');
      expect(model.day.errands.every((e) => !e.optional), isTrue);
      expect(source.errands.length, 3);
      expect(answers.calls, 0);
      await tester.ensureVisible(find.text('Include in this plan').first);
      await tester.tap(find.text('Include in this plan').first);
      await tester.pumpAndSettle();
      expect(model.deferred.keys, ['b']);
      await tester.ensureVisible(find.text('Include in this plan'));
      await tester.tap(find.text('Include in this plan'));
      await tester.pumpAndSettle();
      expect(model.deferred, isEmpty);
      expect(model.error, isNull);
    },
  );
  testWidgets('all-deferred plan explains inclusion without leaving review', (
    tester,
  ) async {
    await _launch(tester, _Answers());
    await tester.tap(question);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Plan the other errands'));
    await tester.tap(find.text('Plan the other errands'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Leave out of this plan'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Include at least one errand to plan this day.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Next: find suitable places'),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Back to Today'), findsNothing);
    expect(find.text('Include in this plan'), findsOneWidget);
  });
  testWidgets(
    'Retry saving closes only the answer sheet and never regenerates',
    (tester) async {
      final storage = _FlakyStorage(), answers = _Answers();
      answers.onAnswer = () => storage.broken = true;
      await _launch(tester, answers, repository: storage);
      await tester.tap(question);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Not sure');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use answer'));
      await tester.pumpAndSettle();
      expect(find.text('Retry saving answer'), findsOneWidget);
      expect(answers.calls, 1);
      storage.broken = false;
      await tester.tap(find.text('Retry saving answer'));
      await tester.pumpAndSettle();
      expect(find.byType(ClarificationSheet), findsNothing);
      expect(find.byType(PlanningView), findsOneWidget);
      expect(
        find.text('General groceries · Choose items at the store'),
        findsOneWidget,
      );
      expect(answers.calls, 1);
    },
  );
}
