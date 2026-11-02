import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'helpers/planning_fixtures.dart';

class FreshInterpreter extends Interpreter implements FreshErrandInterpreter {
  int generations = 0, lookups = 0;
  String? lastRun;
  bool fail = false;
  Completer<void>? wait;
  final saved = <String, Interpretation>{};
  @override
  Future<Interpretation> analyze(
    DayPlan day, {
    required String runId,
    required String body,
    bool retry = false,
    bool savedOnly = false,
  }) async {
    lastRun = runId;
    if (saved.containsKey(runId)) return saved[runId]!;
    if (savedOnly) {
      lookups++;
      throw const PlanningFailure('Still pending', kind: 'interrupted');
    }
    generations++;
    await wait?.future;
    if (fail) {
      throw const PlanningFailure(
        'Synthetic offline failure',
        kind: 'connection',
      );
    }
    return saved[runId] = Interpretation([
      for (final e in day.errands)
        ErrandNeed(
          id: e.id,
          query: 'fresh suitable place',
          locationIntent: LocationIntent.flexible,
        ),
    ]);
  }
}

class FailingAnalysisStore extends MemoryClarificationRepository {
  int failures = 1;
  @override
  Future<void> save(String key, ClarificationSession session) async {
    if (session.analysis != null && failures-- > 0) {
      throw StateError('Synthetic disk failure');
    }
    await super.save(key, session);
  }
}

class UnreadableAnalysisStore extends MemoryClarificationRepository {
  bool broken = true;
  @override
  Future<ClarificationSession> read(String key) => broken
      ? Future.error(StateError('Synthetic corrupt saved session'))
      : super.read(key);
}

class CountedInitialInterpreter extends Interpreter {
  int generations = 0;
  @override
  Future<Interpretation> interpret(DayPlan day) {
    generations++;
    return super.interpret(day);
  }
}

class FailedCompletionStore extends MemoryClarificationRepository {
  int writes = 0;
  @override
  Future<void> save(String key, ClarificationSession session) async {
    if (session.analysis != null && ++writes == 2) {
      throw StateError('Synthetic completion save failure');
    }
    await super.save(key, session);
  }
}

class AnsweredFreshInterpreter extends FreshInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([
    for (final e in day.errands)
      ErrandNeed(
        id: e.id,
        query: 'laundry',
        category: 'other',
        locationIntent: LocationIntent.flexible,
        question: 'Any service requirements?',
        questionKind: 'preference',
        questionRequired: false,
        questionFocus: 'taskRequirements',
      ),
  ]);
}

void main() {
  test(
    'unreadable saved analysis blocks an automatic replacement request',
    () async {
      final interpreter = CountedInitialInterpreter();
      final store = UnreadableAnalysisStore();
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: store,
      );
      await model.understand();
      expect(interpreter.generations, 0);
      expect(model.stage, PreparationStage.failed);
      expect(model.understandingFailure?.kind, 'cache');
      await model.understand(savedOnly: true);
      expect(interpreter.generations, 0);
      store.broken = false;
      await model.understand();
      expect(interpreter.generations, 1);
      expect(model.stage, PreparationStage.review);
      model.dispose();
    },
  );
  test(
    'fresh analysis keeps saved answers editable and withdrawal restores base meaning',
    () async {
      final interpreter = AnsweredFreshInterpreter();
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture().copyWith(
          errands: const [Errand(id: 'a', title: 'Laundry')],
        ),
        interpreter,
        roads,
        MemoryItineraryRepository(),
      );
      await model.understand();
      final errand = model.reviewErrands.first;
      await model.clarifications.applyStructured(
        model.questionContext(errand),
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'Dry cleaning',
          query: 'dry cleaner',
        ),
        'Dry cleaning',
      );
      await model.analyzeAgain();
      expect(model.answerFor(errand)?.applied, isTrue);
      expect(model.canRecommendPlaces(errand), isTrue);
      expect(model.questionFor(errand), isNull);
      await model.clarifications.saveDraft(model.questionContext(errand), '');
      expect(model.answerFor(errand)?.status, 'cleared');
      expect(model.effectiveNeed(errand)!.query, 'laundry');
      expect(model.questionFor(errand), 'Any service requirements?');
      expect(model.questionBlocks(errand), isFalse);
      model.dispose();
    },
  );
  test(
    'completed generation retries only local persistence after a save failure',
    () async {
      final interpreter = FreshInterpreter();
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: FailedCompletionStore(),
      );
      await model.understand();
      final original = model.needs['a']!.query;
      await model.analyzeAgain();
      expect(interpreter.generations, 1);
      expect(model.needs['a']!.query, original);
      expect(model.hasPendingAnalysis, isTrue);
      await model.analyzeAgain(savedOnly: true);
      expect(model.needs['a']!.query, 'fresh suitable place');
      expect(interpreter.generations, 1);
      model.dispose();
    },
  );
  test(
    'fresh analysis coalesces, persists, preserves manual constraints and reopens without generation',
    () async {
      final repository = MemoryClarificationRepository();
      final interpreter = FreshInterpreter()..wait = Completer<void>();
      final roads = Roads();
      addTearDown(roads.client.close);
      PlanningController create() => PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: repository,
      );
      final model = create();
      await model.understand();
      final current = model.interpretation;
      model.edit(
        model.reviewErrands.first.copyWith(
          timing: TimingRule.at,
          minute: 600,
          confirmedFields: {'timing', 'place'},
        ),
      );
      final one = model.analyzeAgain();
      final two = model.analyzeAgain();
      await Future<void>.delayed(Duration.zero);
      expect(model.interpretation, same(current));
      expect(interpreter.generations, 1);
      interpreter.wait!.complete();
      await Future.wait([one, two]);
      expect(model.needs['a']!.query, 'fresh suitable place');
      expect(model.reviewErrands.first.minute, 600);
      expect(model.reviewErrands.first.placeIntent.toJson(), pin.toJson());
      model.dispose();
      final reopened = create();
      await reopened.understand();
      expect(reopened.needs['a']!.query, 'fresh suitable place');
      expect(reopened.reviewErrands.first.minute, 600);
      expect(interpreter.generations, 1);
      reopened.dispose();
    },
  );

  test(
    'failure retains previous result; restart only looks up; explicit retry uses same run',
    () async {
      final repository = MemoryClarificationRepository();
      final interpreter = FreshInterpreter()..fail = true;
      final roads = Roads();
      addTearDown(roads.client.close);
      PlanningController create() => PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: repository,
      );
      final model = create();
      await model.understand();
      final original = model.needs['a']!.query;
      await model.analyzeAgain();
      final run = interpreter.lastRun;
      expect(model.needs['a']!.query, original);
      expect(model.error, isNotNull);
      model.dispose();
      final reopened = create();
      await reopened.understand();
      expect(interpreter.generations, 1);
      expect(reopened.needs['a']!.query, original);
      interpreter.fail = false;
      await reopened.analyzeAgain(retry: true);
      expect(interpreter.lastRun, run);
      expect(interpreter.generations, 2);
      expect(reopened.needs['a']!.query, 'fresh suitable place');
      reopened.dispose();
    },
  );

  test('failure to persist the run prevents dispatch', () async {
    final interpreter = FreshInterpreter();
    final roads = Roads();
    addTearDown(roads.client.close);
    final model = PlanningController(
      fixture(),
      interpreter,
      roads,
      MemoryItineraryRepository(),
      clarificationRepository: FailingAnalysisStore(),
    );
    await model.understand();
    await model.analyzeAgain();
    expect(interpreter.generations, 0);
    expect(model.error, isNotNull);
    await model.analyzeAgain();
    expect(interpreter.generations, 1);
    model.dispose();
  });

  test(
    'edits reject late output and saved recovery cannot overwrite the edit',
    () async {
      final interpreter = FreshInterpreter()..wait = Completer<void>();
      final roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        fixture(),
        interpreter,
        roads,
        MemoryItineraryRepository(),
      );
      await model.understand();
      final before = model.needs['a']!.query;
      final flight = model.analyzeAgain();
      await Future<void>.delayed(Duration.zero);
      model.edit(
        model.reviewErrands.first.copyWith(timing: TimingRule.at, minute: 720),
      );
      interpreter.wait!.complete();
      await flight;
      expect(model.needs['a']!.query, before);
      await model.analyzeAgain(savedOnly: true);
      expect(model.reviewErrands.first.minute, 720);
      expect(model.needs['a']!.query, before);
      expect(interpreter.generations, 1);
      model.dispose();
    },
  );
}
