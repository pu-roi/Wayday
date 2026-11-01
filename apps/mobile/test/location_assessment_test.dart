import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/data/location_intent_resolver.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/location_assessment.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/clarification_coordinator.dart';

LocationAssessmentContext context([String title = 'Kunin ang inorder ko']) =>
    LocationAssessmentContext({
      'version': 1,
      'id': 'a',
      'title': title,
      'notes': '',
    });

class Resolver implements LocationIntentResolver {
  int calls = 0;
  final pending = Completer<LocationAssessmentResult>();
  @override
  Future<LocationAssessmentResult> assess(
    LocationAssessmentContext context, {
    bool retry = false,
    bool savedOnly = false,
  }) {
    if (savedOnly) {
      throw const PlanningFailure('No saved result', kind: 'cache_miss');
    }
    calls++;
    return pending.future;
  }
}

class NoAnswers implements ClarificationResolver {
  @override
  Future<ClarificationResolution> resolve(
    ClarificationContext context,
    String answer, {
    List<String> history = const [],
    bool retry = false,
    bool savedOnly = false,
  }) => throw StateError('Location checks must not rerun other answers');
}

class Storage extends MemoryClarificationRepository {
  bool fail = false;
  @override
  Future<void> save(String key, ClarificationSession session) async {
    if (fail) throw StateError('Storage unavailable');
    await super.save(key, session);
  }
}

void main() {
  test(
    'explicit checks coalesce, persist, and reuse after recreation',
    () async {
      final resolver = Resolver(), storage = Storage();
      final coordinator = ClarificationCoordinator(
        storage,
        NoAnswers(),
        locationResolver: resolver,
      );
      addTearDown(coordinator.dispose);
      await coordinator.bind('source');
      final first = coordinator.assessLocation(context()),
          same = coordinator.assessLocation(context());
      await Future<void>.delayed(Duration.zero);
      expect(resolver.calls, 1);
      expect(
        (await storage.read('source')).locationAssessments.values.single.status,
        'processing',
      );
      resolver.pending.complete(
        const LocationAssessmentResult(
          intent: LocationIntent.specific,
          summary: 'Existing order',
        ),
      );
      await Future.wait([first, same]);
      expect(coordinator.locationAssessment(context())!.applied, isTrue);
      final restored = ClarificationCoordinator(
        storage,
        NoAnswers(),
        locationResolver: resolver,
      );
      addTearDown(restored.dispose);
      await restored.bind('source');
      await restored.assessLocation(context());
      expect(resolver.calls, 1);
      expect(
        restored.locationAssessment(context())!.result!.intent,
        LocationIntent.specific,
      );
    },
  );

  test(
    'storage failure never reports a completed choice and save retry is free',
    () async {
      final resolver = Resolver(), storage = Storage();
      final coordinator = ClarificationCoordinator(
        storage,
        NoAnswers(),
        locationResolver: resolver,
      );
      addTearDown(coordinator.dispose);
      await coordinator.bind('source');
      final check = coordinator.assessLocation(context());
      await Future<void>.delayed(Duration.zero);
      storage.fail = true;
      resolver.pending.complete(
        const LocationAssessmentResult(
          intent: LocationIntent.flexible,
          summary: 'Suggest a venue',
        ),
      );
      await check;
      expect(coordinator.locationAssessment(context())!.applied, isFalse);
      expect(coordinator.storageError, isNotNull);
      storage.fail = false;
      await coordinator.retrySave();
      expect(coordinator.locationAssessment(context())!.applied, isTrue);
      expect(resolver.calls, 1);
    },
  );

  test(
    'pending restart performs saved-only lookup, never an automatic generation',
    () async {
      final storage = Storage(), c = context();
      await storage.save(
        'source',
        ClarificationSession(
          locationAssessments: {
            c.key: LocationAssessment(context: c, revision: 1, updatedAt: 1),
          },
        ),
      );
      final resolver = Resolver(),
          coordinator = ClarificationCoordinator(
            storage,
            NoAnswers(),
            locationResolver: resolver,
          );
      addTearDown(coordinator.dispose);
      await coordinator.bind('source');
      await coordinator.resumeLocationAssessments([c]);
      await coordinator.assessLocation(c);
      expect(resolver.calls, 0);
      expect(coordinator.locationAssessment(c)!.applied, isFalse);
      expect(coordinator.errors[c.key], isNotNull);
    },
  );

  test(
    'late assessment cannot replace a different source and unknown fields are rejected',
    () async {
      final resolver = Resolver(),
          coordinator = ClarificationCoordinator(
            Storage(),
            NoAnswers(),
            locationResolver: resolver,
          );
      addTearDown(coordinator.dispose);
      await coordinator.bind('first');
      final check = coordinator.assessLocation(context());
      await Future<void>.delayed(Duration.zero);
      await coordinator.bind('second');
      resolver.pending.complete(
        const LocationAssessmentResult(
          intent: LocationIntent.specific,
          summary: 'Old source',
        ),
      );
      await check;
      expect(coordinator.session.locationAssessments, isEmpty);
      expect(
        () => LocationAssessmentResult.fromJson({
          'id': 'a',
          'locationIntent': 'flexible',
          'summary': 'Shop',
          'latitude': 14.5,
        }, 'a'),
        throwsFormatException,
      );
    },
  );
}
