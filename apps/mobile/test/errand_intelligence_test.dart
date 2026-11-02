import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/domain/place_search_intent.dart';
import 'package:wayday/features/planning/domain/place_suitability.dart';
import 'package:wayday/features/planning/domain/recommendation.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/data/clarification_repository.dart';
import 'package:wayday/features/planning/data/clarification_resolver.dart';
import 'package:wayday/features/planning/presentation/clarification_coordinator.dart';

void main() {
  test(
    'typed saved preferences survive rephrasing and withdrawal stays withdrawn',
    () async {
      const errand = Errand(id: 'a', title: 'Laundry');
      ClarificationContext context(String question, {Errand e = errand}) =>
          ClarificationContext.create(
            e,
            ErrandNeed(
              id: 'a',
              query: 'laundry',
              question: question,
              questionKind: 'preference',
              questionRequired: false,
              questionFocus: 'taskRequirements',
              locationIntent: LocationIntent.flexible,
            ),
            [e],
          );
      final coordinator = ClarificationCoordinator(
        MemoryClarificationRepository(),
        GeminiClarificationResolver(),
      );
      await coordinator.bind('synthetic-focus');
      final first = context('Any service requirements?');
      await coordinator.applyStructured(
        first,
        const ClarificationResolution(
          outcome: 'flexible',
          kind: 'preference',
          summary: 'Wash and fold',
          query: 'wash and fold laundry',
        ),
        'Wash and fold',
      );
      final rephrased = context('Do you need a particular laundry service?');
      expect(coordinator.record(rephrased)?.applied, isTrue);
      expect(
        coordinator.record(
          context(
            'Any service requirements?',
            e: errand.copyWith(notes: 'Dry cleaning'),
          ),
        ),
        isNull,
      );
      await coordinator.saveDraft(rephrased, '');
      expect(coordinator.record(first)?.status, 'cleared');
      expect(coordinator.record(rephrased)?.applied, isFalse);
      coordinator.dispose();
    },
  );
  final hint = <String, dynamic>{
    'version': 2,
    'variants': ['supermarket', 'public market', 'rice retailer'],
    'preferredTypes': ['supermarket', 'grocery_store'],
    'fallbackTypes': ['market', 'food_store'],
    'excludedPrimaryTypes': ['wholesaler'],
  };
  test('new venue hints retain preferred families and declared fallbacks', () {
    final parsed = PlaceSearchIntent.optionalFromJson(hint);
    expect(parsed, isNotNull);
    expect(parsed!.acceptableTypes, containsAll(['supermarket', 'market']));
    expect(
      PlaceSearchIntent.fromJson(parsed.toJson()).toJson(),
      parsed.toJson(),
    );
  });
  test('consumer purchase rejects a conflicting primary wholesale type', () {
    final need = ErrandNeed(
      id: 'a',
      query: 'rice',
      category: 'grocery',
      searchIntent: PlaceSearchIntent.optionalFromJson(hint),
    );
    RecommendationPlace place(String primary) => RecommendationPlace.fromJson({
      'id': primary,
      'name': 'Synthetic business',
      'country': 'PH',
      'latitude': 14.58,
      'longitude': 121.06,
      'primaryType': primary,
      'types': [primary, 'grocery_store'],
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    expect(placeSuitability(need, place('wholesaler')), 0);
    expect(placeSuitability(need, place('grocery_store')), 2);
    expect(placeSuitability(need, place('restaurant')), 0);
    final wholesale = ErrandNeed(
      id: 'a',
      query: 'wholesale rice',
      category: 'grocery',
      searchIntent: PlaceSearchIntent.optionalFromJson({
        ...hint,
        'preferredTypes': ['wholesaler'],
        'fallbackTypes': ['warehouse_store'],
        'excludedPrimaryTypes': <String>[],
      }),
    );
    expect(placeSuitability(wholesale, place('wholesaler')), 2);
  });
  test('clarification changing meaning clears obsolete search hints', () {
    final old = ErrandNeed(
      id: 'a',
      query: 'supermarket',
      category: 'grocery',
      searchIntent: PlaceSearchIntent(
        variants: ['supermarket'],
        preferredTypes: ['supermarket'],
        acceptableTypes: ['supermarket'],
      ),
    );
    const answer = ClarificationResolution(
      outcome: 'resolved',
      kind: 'preference',
      summary: 'Prepared lunch',
      query: 'restaurant',
      category: 'food',
    );
    expect(answer.refine(old).searchIntent, isNull);
    const unchanged = ClarificationResolution(
      outcome: 'flexible',
      kind: 'preference',
      summary: 'Let Wayday recommend',
    );
    expect(unchanged.refine(old).searchIntent, same(old.searchIntent));
  });
  test(
    'destination preference never makes flexible laundry require a location',
    () {
      final need = ErrandNeed.fromJson({
        ...const ErrandNeed(
          id: 'a',
          query: 'laundry',
          locationIntent: LocationIntent.flexible,
          question: 'Where would you like to go for laundry?',
        ).toJson(),
        'clarification': {
          'kind': 'other',
          'required': true,
          'focus': 'destinationPreference',
        },
      });
      expect(outstandingQuestion(need, clarified: false), isNull);
      expect(
        needsLocationUnderstanding(
          const Errand(id: 'a', title: 'Laundry'),
          need,
        ),
        isFalse,
      );
    },
  );
  test('task requirements may be optional or genuinely essential', () {
    final raw = const ErrandNeed(
      id: 'a',
      query: 'shop',
      question: 'Which service?',
      locationIntent: LocationIntent.flexible,
    ).toJson();
    final optional = ErrandNeed.fromJson({
      ...raw,
      'clarification': {
        'kind': 'preference',
        'required': false,
        'focus': 'taskRequirements',
      },
    });
    expect(optional.questionRequired, isFalse);
    expect(outstandingQuestion(optional, clarified: false), 'Which service?');
    final essential = ErrandNeed.fromJson({
      ...raw,
      'locationIntent': 'unclear',
      'clarification': {
        'kind': 'other',
        'required': true,
        'focus': 'taskRequirements',
      },
    });
    expect(essential.questionRequired, isTrue);
    expect(essential.questionKind, 'other');
    expect(outstandingQuestion(essential, clarified: false), 'Which service?');
    expect(
      needsLocationUnderstanding(
        const Errand(id: 'a', title: 'Check the court'),
        essential,
      ),
      isTrue,
    );
  });
}
