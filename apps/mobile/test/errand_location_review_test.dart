import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/errand_location_review.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test(
    'unattached business needs go to recommendations, including cleared places',
    () {
      const need = ErrandNeed(id: 'a', query: 'grocery', category: 'grocery');
      const empty = Errand(
        id: 'a',
        title: 'Grocery',
        confirmedFields: {'place'},
      );
      expect(needsPlaceRecommendation(empty, need), isTrue);
      expect(needsActualLocation(empty, need), isFalse);
      final search = empty.copyWith(
        placeIntent: const PlaceIntent(
          kind: PlaceKind.search,
          label: 'Preferred supermarket',
        ),
      );
      expect(needsPlaceRecommendation(search, need), isTrue);
    },
  );

  test('fixed places and missing private points have distinct handling', () {
    const need = ErrandNeed(id: 'a', query: 'pickup', category: 'meeting');
    const empty = Errand(id: 'a', title: 'Pick up Ana');
    expect(needsActualLocation(empty, need), isTrue);
    expect(needsPlaceRecommendation(empty, need), isFalse);
    final selected = empty.copyWith(placeIntent: pin);
    expect(needsActualLocation(selected, need), isFalse);
    expect(needsPlaceRecommendation(selected, need), isFalse);
  });

  test(
    'expired specific Google reference cannot silently become another branch',
    () {
      const e = Errand(
        id: 'a',
        title: 'Buy food',
        placeIntent: PlaceIntent(
          kind: PlaceKind.providerReference,
          label: 'Chosen branch',
          provider: 'google_ui_kit',
          providerPlaceId: 'fixture-reference',
        ),
      );
      expect(
        needsActualLocation(e, const ErrandNeed(id: 'a', query: 'food')),
        isTrue,
      );
      expect(needsPlaceRecommendation(e, null), isFalse);
    },
  );

  test('cached location-only questions use deterministic place handling', () {
    for (final question in [
      'Where should I pick up your girlfriend?',
      'Where is the pares house located?',
      'Which store would you like to visit?',
      'Saan mo gustong bumili ng ice cream?',
      'Saang lugar kayo magkikita?',
    ]) {
      expect(
        outstandingQuestion(
          ErrandNeed(id: 'a', query: '', question: question),
          clarified: false,
        ),
        isNull,
        reason: question,
      );
    }
  });

  test(
    'mixed and unknown questions remain explicit instead of being discarded',
    () {
      for (final question in [
        'Where and at what time should I pick up Ana?',
        'Where does this errand go in the order?',
        'Which errand should this happen after?',
        'Anong oras kayo magkikita?',
        'Do you mean Ana or Bea?',
      ]) {
        final need = ErrandNeed(id: 'a', query: '', question: question);
        expect(outstandingQuestion(need, clarified: false), question);
        expect(outstandingQuestion(need, clarified: true), isNull);
      }
    },
  );
}
