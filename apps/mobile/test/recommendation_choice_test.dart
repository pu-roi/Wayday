import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/gemini_interpreter.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class _Need implements ErrandInterpreter {
  _Need(this.need);
  final ErrandNeed need;
  @override
  Future<Interpretation> interpret(DayPlan day) async => Interpretation([need]);
}

class _Answers implements ClarificationResolver {
  int calls = 0;
  final pending = Completer<ClarificationResolution>();
  @override
  Future<ClarificationResolution> resolve(
    ClarificationContext context,
    String answer, {
    List<String> history = const [],
    bool retry = false,
    bool savedOnly = false,
  }) {
    calls++;
    return pending.future;
  }
}

class _Discovery implements RecommendationDiscovery {
  final received = <ErrandNeed>[];
  @override
  Future<void> preflight(int maximumRequests) async {}
  @override
  Future<DiscoveryResult> discover(
    ErrandNeed need, {
    required String? polyline,
    required List<PlaceIntent> anchors,
    required int limit,
    required bool Function() cancelled,
    HoursQuery? hours,
  }) async {
    received.add(need);
    return DiscoveryResult([
      PlanCandidate(key: placeKey(pin), place: pin, errandIds: {need.id}),
    ]);
  }

  @override
  Future<RecommendationPlace?> hydrate(
    PlaceIntent place, {
    bool Function()? cancelled,
  }) async => null;
  @override
  RecommendationPlace? metadata(PlaceIntent place) => null;
}

const _gym = ErrandNeed(
  id: 'a',
  query: 'gym',
  category: 'other',
  locationIntent: LocationIntent.unclear,
  question: 'A particular gym or a suitable one?',
  questionKind: 'location',
  questionRequired: true,
);

void main() {
  late Roads roads;
  late _Answers answers;
  late MemoryClarificationRepository storage;
  PlanningController create(
    ErrandNeed need, {
    Errand? errand,
    RecommendationDiscovery? discovery,
  }) {
    final model = PlanningController(
      fixture().copyWith(
        errands: [errand ?? const Errand(id: 'a', title: 'go to gym')],
      ),
      _Need(need),
      roads,
      MemoryItineraryRepository(),
      clarificationResolver: answers,
      clarificationRepository: storage,
      discovery: discovery,
    );
    addTearDown(model.dispose);
    return model;
  }

  setUp(() {
    roads = Roads();
    answers = _Answers();
    storage = MemoryClarificationRepository();
  });
  tearDown(() => roads.client.close());

  test(
    'direct gym choice reaches discovery with gym metadata, without language generation',
    () async {
      final discovery = _Discovery(),
          model = create(_gym, discovery: discovery);
      await model.understand();
      final e = model.reviewErrands.single;
      await model.recommendPlaces(e);
      await model.buildRecommendations();
      expect(discovery.received.single.query, 'gym');
      expect(discovery.received.single.category, 'other');
      expect(discovery.received.single.items, isEmpty);
      expect(model.result, isNotNull);
      expect(answers.calls, 0);
    },
  );

  test(
    'grocery flexibility keeps supplied items and a brand instead of replacing discovery metadata',
    () async {
      const e = Errand(
        id: 'a',
        title: 'buy groceries',
        placeIntent: PlaceIntent(
          kind: PlaceKind.search,
          label: 'supermarket',
          brand: 'SM',
        ),
      );
      final model = create(
        const ErrandNeed(
          id: 'a',
          query: 'grocery store',
          category: 'grocery',
          items: ['rice'],
          locationIntent: LocationIntent.flexible,
          question: 'Other preferences?',
          questionKind: 'preference',
          questionRequired: false,
        ),
        errand: e,
      );
      await model.understand();
      await model.recommendPlaces(model.reviewErrands.single);
      final need = model.effectiveNeed(model.reviewErrands.single)!;
      expect(need.query, 'SM supermarket');
      expect(need.category, 'grocery');
      expect(need.items, ['rice']);
      expect(answers.calls, 0);
    },
  );

  test(
    'a grocery answer is not reused by a gym with the same task ID',
    () async {
      final grocery = create(
        const ErrandNeed(
          id: 'a',
          query: 'grocery store',
          category: 'grocery',
          locationIntent: LocationIntent.flexible,
          question: 'Other preferences?',
          questionKind: 'preference',
          questionRequired: false,
        ),
        errand: const Errand(id: 'a', title: 'buy groceries'),
      );
      await grocery.understand();
      await grocery.recommendPlaces(grocery.reviewErrands.single);
      final gym = create(_gym);
      await gym.understand();
      expect(gym.answerFor(gym.reviewErrands.single), isNull);
      await gym.recommendPlaces(gym.reviewErrands.single);
      expect(gym.effectiveNeed(gym.reviewErrands.single)!.query, 'gym');
      expect(gym.effectiveNeed(gym.reviewErrands.single)!.items, isEmpty);
      expect(answers.calls, 0);
    },
  );

  test(
    'recommendation choice cannot answer timing or bypass a fixed destination or stale interpretation',
    () async {
      for (final need in [
        const ErrandNeed(
          id: 'a',
          query: 'gym',
          locationIntent: LocationIntent.specific,
        ),
        const ErrandNeed(
          id: 'a',
          query: 'gym',
          locationIntent: LocationIntent.flexible,
          question: 'What time?',
          questionKind: 'timing',
          questionRequired: true,
        ),
        const ErrandNeed(
          id: 'a',
          query: 'gym',
          question: 'What else do you need?',
        ),
      ]) {
        final model = create(need);
        await model.understand();
        expect(model.canRecommendPlaces(model.reviewErrands.single), isFalse);
        await expectLater(
          model.recommendPlaces(model.reviewErrands.single),
          throwsStateError,
        );
      }
      final confirmed = create(
        _gym,
        errand: const Errand(id: 'a', title: 'gym', placeIntent: pin),
      );
      await confirmed.understand();
      expect(
        confirmed.canRecommendPlaces(confirmed.reviewErrands.single),
        isFalse,
      );
      final changed = create(_gym);
      await changed.understand();
      changed.edit(
        changed.reviewErrands.single.copyWith(title: 'buy groceries'),
      );
      expect(changed.canRecommendPlaces(changed.reviewErrands.single), isFalse);
    },
  );

  test(
    'clearing survives restart, clock changes and merging an older completed answer',
    () async {
      final model = create(
        const ErrandNeed(
          id: 'a',
          query: 'gym',
          category: 'other',
          locationIntent: LocationIntent.flexible,
          question: 'Equipment preferences?',
          questionKind: 'preference',
          questionRequired: false,
        ),
      );
      await model.understand();
      var e = model.reviewErrands.single;
      await model.recommendPlaces(e);
      final old = ClarificationSession.fromJson(
        model.clarifications.session.toJson(),
      );
      model.edit(e.copyWith(durationMinutes: 30));
      e = model.reviewErrands.single;
      await model.clarifications.saveDraft(model.questionContext(e), '');
      expect(model.answerFor(e)!.applied, isFalse);
      await storage.save(model.clarifications.sourceKey!, old);
      final reopened = create(model.needs['a']!);
      await reopened.understand();
      expect(
        reopened.answerFor(reopened.reviewErrands.single)!.status,
        'cleared',
      );
      expect(reopened.questionFor(reopened.reviewErrands.single), isNotNull);
      expect(answers.calls, 0);
    },
  );

  test('a cleared answer is not revived by a late response', () async {
    final model = create(_gym);
    await model.understand();
    final e = model.reviewErrands.single, context = model.questionContext(e);
    final flight = model.clarifications.submit(context, 'Any suitable gym');
    await Future<void>.delayed(Duration.zero);
    await model.clarifications.saveDraft(context, '');
    answers.pending.complete(
      const ClarificationResolution(
        outcome: 'flexible',
        kind: 'location',
        summary: 'Gym recommended',
        locationIntent: LocationIntent.flexible,
      ),
    );
    await flight;
    expect(model.answerFor(e)!.status, 'cleared');
    expect(model.questionBlocks(e), isTrue);
  });
}
