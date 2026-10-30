import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/location_intent_resolver.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/location_assessment.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/planning/presentation/planning_controller.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

class LocationResolver implements LocationIntentResolver {
  int calls = 0;
  @override
  Future<LocationAssessmentResult> assess(
    LocationAssessmentContext context, {
    bool retry = false,
    bool savedOnly = false,
  }) async {
    calls++;
    return const LocationAssessmentResult(
      intent: LocationIntent.flexible,
      summary: 'A suitable venue is welcome',
      query: 'meeting cafe',
    );
  }
}

void main() {
  test(
    'legacy recheck preserves approvals, overrides and answers, and recovers without re-spending',
    () async {
      final original = fixture(),
          source = original.copyWith(
            errands: [
              original.errands.first.copyWith(placeIntent: const PlaceIntent()),
              original.errands.last,
            ],
          );
      final storage = MemoryClarificationRepository(),
          resolver = LocationResolver(),
          roads = Roads();
      addTearDown(roads.client.close);
      PlanningController create() => PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
        clarificationRepository: storage,
        locationResolver: resolver,
      );
      final model = create();
      addTearDown(model.dispose);
      await model.understand();
      model.needs['a'] = const ErrandNeed(
        id: 'a',
        query: 'meeting',
        category: 'meeting',
      );
      final e = model.reviewErrands.first;
      expect(model.questionBlocks(e), isTrue);
      expect(needsActualLocation(e, model.effectiveNeed(e)), isFalse);
      model.approved.add('b');
      model.overridePlace('b', pin);
      await model.recheckLocation(e);
      expect(model.questionBlocks(e), isFalse);
      expect(needsPlaceRecommendation(e, model.effectiveNeed(e)), isTrue);
      expect(model.approved, {'b'});
      expect(model.overrides['b'], isNotNull);
      final key = model.locationContext(e).key;
      model.day = model.day.copyWith(
        departure: model.day.departure + 60,
        profile: TravelProfile.sedan,
      );
      expect(model.locationContext(e).key, key);
      await model.recheckLocation(e);
      expect(resolver.calls, 1);
      final restored = create();
      addTearDown(restored.dispose);
      await restored.understand();
      restored.needs['a'] = model.needs['a']!;
      expect(restored.questionBlocks(restored.reviewErrands.first), isFalse);
      expect(resolver.calls, 1);
      model.edit(e.copyWith(notes: 'Actually use my pre-booked venue'));
      expect(model.questionBlocks(model.reviewErrands.first), isTrue);
    },
  );

  test(
    'a saved clarification changes an unclear destination to flexible without changing duration',
    () async {
      final initial = fixture(),
          source = initial.copyWith(
            errands: [
              initial.errands.first.copyWith(
                placeIntent: const PlaceIntent(),
                durationMinutes: 15,
                durationConfirmed: false,
              ),
            ],
          ),
          roads = Roads();
      addTearDown(roads.client.close);
      final model = PlanningController(
        source,
        Interpreter(),
        roads,
        MemoryItineraryRepository(),
      );
      addTearDown(model.dispose);
      await model.understand();
      model.needs['a'] = const ErrandNeed(
        id: 'a',
        query: 'court',
        locationIntent: LocationIntent.unclear,
        question: 'An existing court or a suitable recommendation?',
        questionKind: 'location',
        questionRequired: true,
      );
      final e = model.reviewErrands.first;
      await model.clarifications.applyStructured(
        model.questionContext(e),
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'location',
          summary: 'Recommend somewhere suitable',
          locationIntent: LocationIntent.flexible,
        ),
        'Any suitable venue',
      );
      expect(model.questionBlocks(e), isFalse);
      expect(needsPlaceRecommendation(e, model.effectiveNeed(e)), isTrue);
      expect(model.reviewErrands.first.durationMinutes, 15);
      expect(model.reviewErrands.first.durationConfirmed, isFalse);
    },
  );
}
