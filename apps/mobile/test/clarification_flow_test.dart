import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/clarification_coordinator.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class AnswerResolver implements ClarificationResolver {
  int generations = 0, lookups = 0;
  Future<ClarificationResolution> Function(ClarificationContext, String)?
  respond;
  @override
  Future<ClarificationResolution> resolve(
    ClarificationContext context,
    String answer, {
    List<String> history = const [],
    bool retry = false,
    bool savedOnly = false,
  }) async {
    if (savedOnly) {
      lookups++;
      throw const PlanningFailure('Answer still pending', kind: 'pending');
    }
    generations++;
    return respond == null
        ? const ClarificationResolution(
            outcome: 'flexible',
            kind: 'preference',
            summary: 'General groceries · Choose items at the store',
            query: 'grocery store',
          )
        : respond!(context, answer);
  }
}

class Questions implements ErrandInterpreter {
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([
    for (final e in day.errands)
      ErrandNeed(
        id: e.id,
        query: 'grocery store',
        category: 'grocery',
        items: const ['rice'],
        question: e.id == 'a'
            ? 'What specific grocery items do you need?'
            : null,
      ),
  ]);
}

class BrokenAnswers implements ClarificationRepository {
  final memory = MemoryClarificationRepository();
  bool broken = true;
  @override
  Future<ClarificationSession> read(String key) => memory.read(key);
  @override
  Future<void> save(String key, ClarificationSession session) async {
    if (broken) throw StateError('Disk full');
    await memory.save(key, session);
  }
}

void main() {
  late PlanningController model;
  late AnswerResolver resolver;
  late Roads roads;
  setUp(() async {
    resolver = AnswerResolver();
    roads = Roads();
    model = PlanningController(
      fixture().copyWith(
        errands: [
          const Errand(id: 'a', title: 'Groceries'),
          fixture().errands.last,
        ],
      ),
      Questions(),
      roads,
      MemoryItineraryRepository(),
      clarificationResolver: resolver,
    );
    await model.understand();
  });
  tearDown(() {
    model.dispose();
    roads.client.close();
  });
  for (final text in [
    'Not sure',
    'Di ko pa alam, titignan ko pa lang pagpunta ko doon',
  ]) {
    test(
      '$text gives flexible recommendations without changing the estimate',
      () async {
        final e = model.reviewErrands.first;
        await model.clarifications.submit(model.questionContext(e), text);
        expect(model.questionFor(e), isNull);
        expect(model.effectiveNeed(e)!.query, 'grocery store');
        expect(model.effectiveNeed(e)!.items, ['rice']);
        expect(model.reviewErrands.first.durationMinutes, 15);
        expect(model.reviewErrands.first.durationConfirmed, isFalse);
        expect(model.reviewErrands.first.notes, isEmpty);
        model.applyReview();
        expect(model.unresolved.first.id, 'a');
        await model.clarifications.submit(model.questionContext(e), text);
        expect(resolver.generations, 1);
      },
    );
  }
  test(
    'unrelated edits do not answer questions or erase applied preferences',
    () async {
      var e = model.reviewErrands.first;
      model.edit(e.copyWith(durationMinutes: 20));
      e = model.reviewErrands.first;
      expect(model.questionFor(e), isNotNull);
      await model.clarifications.submit(model.questionContext(e), 'Not sure');
      model.edit(e.copyWith(durationMinutes: 30));
      expect(model.questionFor(model.reviewErrands.first), isNull);
      expect(model.reviewErrands.first.durationMinutes, 30);
      expect(resolver.generations, 1);
    },
  );
  test(
    'proposed dependency stays unapplied until approval and reverses',
    () async {
      resolver.respond = (c, a) async => const ClarificationResolution(
        outcome: 'resolved',
        kind: 'dependency',
        summary: 'Shop after eating',
        after: ['b'],
      );
      final context = model.questionContext(model.reviewErrands.first);
      await model.clarifications.submit(context, 'After eating');
      expect(model.reviewErrands.map((e) => e.id), ['a', 'b']);
      await model.clarifications.approveRules(context, true);
      expect(model.reviewErrands.map((e) => e.id), ['b', 'a']);
      await model.clarifications.approveRules(context, false);
      expect(model.reviewErrands.map((e) => e.id), ['a', 'b']);
    },
  );
  test(
    'deferral closure, explicit inclusion, date binding and empty plan',
    () async {
      model.edit(model.reviewErrands.last.copyWith(afterErrandIds: ['a']));
      var closure = model.clarifications.affectedByDeferral(
        'a',
        model.reviewOrder.items,
      );
      expect(closure.map((e) => e.id), ['a', 'b']);
      await model.clarifications.defer(
        model.day.date,
        closure,
        'Not sure where to collect it',
      );
      expect(model.activeErrands, isEmpty);
      expect(model.inputIssues, isNotEmpty);
      expect(() => model.applyReview(), throwsA(isA<PlanningFailure>()));
      expect(model.day.errands.every((e) => !e.optional), isTrue);
      await expectLater(
        model.clarifications.include(model.day.date, closure.last),
        throwsStateError,
      );
      await model.clarifications.include(model.day.date, closure.first);
      expect(model.activeErrands.map((e) => e.id), ['a']);
      expect(model.deferred.keys, ['b']);
      model.day = model.day.copyWith(date: '2030-01-01');
      expect(model.deferred, isEmpty);
    },
  );
  test(
    'required deferred errands remain separate in an accepted v2 plan',
    () async {
      final a = model.reviewErrands.first;
      await model.clarifications.defer(model.day.date, [
        a,
      ], 'Choose its location later');
      model.applyReview();
      await model.calculate();
      expect(model.error, isNull);
      final accepted = await model.accept(0, 0);
      expect(accepted.deferred, {'a': 'Choose its location later'});
      expect(accepted.omitted, isEmpty);
      expect(accepted.day.errands.first.optional, isFalse);
      expect(accepted.toJson()['version'], 2);
    },
  );
  test(
    'duplicate submission survives disposal and another question without clobbering',
    () async {
      final repo = MemoryClarificationRepository(), slow = AnswerResolver();
      final pending = Completer<ClarificationResolution>();
      slow.respond = (c, a) => pending.future;
      final old = ClarificationCoordinator(repo, slow);
      await old.bind('source');
      final c = model.questionContext(model.reviewErrands.first);
      final request = old.submit(c, 'Not sure');
      final duplicate = old.submit(c, 'Not sure');
      await Future<void>.delayed(Duration.zero);
      final reopened = ClarificationCoordinator(repo, resolver);
      await reopened.bind('source');
      final other = ClarificationContext.create(
        model.reviewErrands.last,
        const ErrandNeed(id: 'b', query: 'food', question: 'Any preference?'),
        model.reviewErrands,
      );
      await reopened.saveDraft(other, 'Pares');
      old.dispose();
      pending.complete(
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'General groceries',
        ),
      );
      await Future.wait([request, duplicate]);
      final saved = await repo.read('source');
      expect(slow.generations, 1);
      expect(saved.records[c.key]!.applied, isTrue);
      expect(saved.records[other.key]!.draft, 'Pares');
      reopened.dispose();
    },
  );
  test(
    'pending restart is lookup only; storage failure never dispatches',
    () async {
      final repo = BrokenAnswers(),
          coordinator = ClarificationCoordinator(BrokenAnswers(), resolver);
      final c = model.questionContext(model.reviewErrands.first);
      await coordinator.bind('source');
      await coordinator.submit(c, 'Not sure');
      expect(resolver.generations, 0);
      expect(coordinator.storageError, isNotNull);
      coordinator.dispose();
      repo.broken = false;
      await repo.save(
        'source',
        ClarificationSession(
          records: {
            c.key: ClarificationRecord(
              context: c,
              answer: 'Not sure',
              status: 'processing',
            ),
          },
        ),
      );
      final restored = ClarificationCoordinator(repo, resolver);
      await restored.bind('source');
      await restored.resumeSaved([c]);
      expect(resolver.lookups, 1);
      expect(resolver.generations, 0);
      expect(restored.record(c)!.answer, 'Not sure');
      expect(restored.record(c)!.status, 'failed');
      restored.dispose();
    },
  );
  test(
    'completed generation retries local saving without another generation',
    () async {
      final repo = BrokenAnswers()..broken = false;
      final coordinator = ClarificationCoordinator(repo, resolver);
      await coordinator.bind('source');
      final c = model.questionContext(model.reviewErrands.first);
      resolver.respond = (c, a) async {
        repo.broken = true;
        return const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'General groceries',
        );
      };
      await coordinator.submit(c, 'Not sure');
      expect(coordinator.record(c)!.applied, isTrue);
      expect(coordinator.storageError, isNotNull);
      expect(resolver.generations, 1);
      repo.broken = false;
      await coordinator.retrySave();
      expect((await repo.read('source')).records[c.key]!.applied, isTrue);
      expect(resolver.generations, 1);
      coordinator.dispose();
    },
  );
  test(
    'editing a failed answer submits the new text and relevant changes clear only affected candidates',
    () async {
      final c = model.questionContext(model.reviewErrands.first);
      String? received;
      resolver.respond = (c, a) async =>
          throw const PlanningFailure('No connection');
      await model.clarifications.submit(c, 'Old answer');
      resolver.respond = (c, a) async {
        received = a;
        return const ClarificationResolution(
          outcome: 'resolved',
          kind: 'preference',
          summary: 'Rice',
          query: 'grocery store',
          items: ['rice'],
        );
      };
      await model.clarifications.submit(c, 'Rice', retry: true);
      expect(received, 'Rice');
      model.applyReview();
      model.found('a', [
        const PlanCandidate(key: 'fixture', place: pin, errandIds: {'a'}),
      ]);
      expect(model.candidates.keys, containsAll(['a', 'b']));
      resolver.respond = (c, a) async => const ClarificationResolution(
        outcome: 'resolved',
        kind: 'preference',
        summary: 'Wet market',
        query: 'wet market',
      );
      await model.clarifications.submit(c, 'A wet market instead');
      expect(model.candidates.containsKey('a'), isFalse);
      expect(model.candidates.containsKey('b'), isTrue);
      expect(model.stage, PreparationStage.review);
    },
  );
  test(
    'latest preference survives unrelated clocks and an unapplied draft',
    () async {
      var e = model.reviewErrands.first;
      await model.clarifications.submit(model.questionContext(e), 'Not sure');
      model.edit(e.copyWith(durationMinutes: 20));
      e = model.reviewErrands.first;
      resolver.respond = (c, a) async => const ClarificationResolution(
        outcome: 'resolved',
        kind: 'preference',
        summary: 'Soy sauce',
        items: ['soy sauce'],
      );
      await model.clarifications.submit(model.questionContext(e), 'Soy sauce');
      model.edit(e.copyWith(durationMinutes: 15));
      e = model.reviewErrands.first;
      await model.clarifications.saveDraft(
        model.questionContext(e),
        'Unsubmitted change',
      );
      expect(model.answerFor(e)!.resolution!.summary, 'Soy sauce');
      expect(
        model.clarifications.draftFor(model.questionContext(e)),
        'Unsubmitted change',
      );
      expect(resolver.generations, 2);
    },
  );
  test(
    'confirmed review place survives reopening but never replaces a newer source point',
    () async {
      final repo = MemoryClarificationRepository(), source = fixture();
      PlanningController create(DayPlan day) => PlanningController(
        day,
        Questions(),
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: repo,
        clarificationResolver: resolver,
      );
      final first = create(source);
      await first.understand();
      final chosen = pin.withLabel('Chosen during review');
      await first.confirmPlace(first.reviewErrands.first, chosen);
      first.dispose();
      final reopened = create(source);
      await reopened.understand();
      expect(
        reopened.reviewErrands.first.placeIntent.label,
        'Chosen during review',
      );
      reopened.dispose();
      final updated = source.copyWith(
        errands: [
          source.errands.first.copyWith(
            placeIntent: pin.withLabel('Newer Today point'),
          ),
          source.errands.last,
        ],
      );
      expect(clarificationSourceKey(updated), clarificationSourceKey(source));
      final latest = create(updated);
      await latest.understand();
      expect(latest.reviewErrands.first.placeIntent.label, 'Newer Today point');
      latest.dispose();
    },
  );
  test(
    'confirmed timing answer survives a duration edit without resolving other scopes',
    () async {
      model.needs['a'] = const ErrandNeed(
        id: 'a',
        query: 'grocery',
        question: 'When will you go?',
        questionKind: 'timing',
        questionRequired: true,
      );
      model.edit(
        model.reviewErrands.first.copyWith(
          timing: TimingRule.at,
          minute: 780,
          confirmedFields: {'timing'},
        ),
      );
      final e = model.reviewErrands.first;
      await model.clarifications.applyStructured(
        model.questionContext(e),
        const ClarificationResolution(
          outcome: 'resolved',
          kind: 'timing',
          summary: '1:00 PM confirmed',
        ),
        'Selected a time',
      );
      model.edit(e.copyWith(durationMinutes: 20));
      expect(model.questionFor(model.reviewErrands.first), isNull);
      expect(model.reviewErrands.first.minute, 780);
    },
  );
  test(
    'a source switch during submission persistence cannot dispatch stale work',
    () async {
      final coordinator = ClarificationCoordinator(
        MemoryClarificationRepository(),
        resolver,
      );
      await coordinator.bind('old-source');
      final c = model.questionContext(model.reviewErrands.first);
      final pending = coordinator.submit(c, 'Not sure');
      await coordinator.bind('new-source');
      await pending;
      expect(resolver.generations, 0);
      expect(coordinator.session.records, isEmpty);
      coordinator.dispose();
    },
  );
}
