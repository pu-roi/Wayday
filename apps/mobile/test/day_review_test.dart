import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/review/domain/day_review.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/places/domain/place_intent.dart';

void main() {
  test(
    'manual review keeps all errands, original text and independent source state',
    () {
      final source = DayPlan(
        errands: const [
          Errand(id: 'a', title: 'bili gamot', notes: 'Keep private'),
          Errand(id: 'b', title: 'Other'),
        ],
        revision: 9,
      );
      final review = DayReview(source);
      expect(review.baseRevision, 9);
      expect(review.move(0, 1), isNull);
      review.replace(review.day.errands.last.copyWith(optional: true));
      expect(review.day.errands.map((e) => e.id), ['b', 'a']);
      expect(review.day.errands.last.inputText, 'bili gamot');
      expect(review.day.errands.last.notes, 'Keep private');
      expect(source.errands.first.optional, false);
      expect(source.errands.first.id, 'a');
      expect(review.missingPlaces, 4);
    },
  );

  test('dependency violations are rejected without changing the draft', () {
    final review = DayReview(
      DayPlan(
        errands: const [
          Errand(id: 'a', title: 'First'),
          Errand(id: 'b', title: 'Then', afterErrandIds: ['a']),
        ],
      ),
    );
    final previous = review.day;
    expect(review.move(1, 0), contains('prerequisite'));
    expect(review.day, same(previous));
    final broken = DayReview(
      DayPlan(
        errands: const [
          Errand(id: 'a', title: 'Orphan', afterErrandIds: ['gone']),
        ],
      ),
    );
    expect(broken.orderingIssue, contains('no longer'));
  });

  test(
    'valid pins remain structured and invalid direct coordinates are not map-ready',
    () {
      final review = DayReview(DayPlan(errands: const []));
      const pin = PlaceIntent(
        kind: PlaceKind.specific,
        label: 'Manual pin',
        latitude: 14.58,
        longitude: 121.08,
      );
      review.setPlace(start: true, place: pin);
      final restored = DayPlan.fromJson(review.day.toJson());
      expect(restored.fromPlace.latitude, 14.58);
      expect(restored.fromPlace.source, 'user');
      expect(
        const PlaceIntent(latitude: 91, longitude: 121).hasCoordinates,
        false,
      );
      expect(const PlaceIntent(latitude: 0, longitude: 0).hasCoordinates, true);
      expect(
        const PlaceIntent(latitude: double.nan, longitude: 0).hasCoordinates,
        false,
      );
    },
  );
}
