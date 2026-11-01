import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/planning/presentation/review_changes.dart';

void main() {
  test('unchanged and protected fields do not produce review work', () {
    const original = Errand(
      id: 'a',
      title: 'Grocery',
      durationMinutes: 40,
      durationConfirmed: true,
      timing: TimingRule.arriveBy,
      minute: 540,
      confirmedFields: {'optional', 'dependencies'},
    );
    const need = ErrandNeed(
      id: 'a',
      query: 'store',
      durationMinutes: 15,
      timing: 'at',
      minute: 600,
      optional: true,
      after: ['b'],
    );
    expect(reviewChanges(original, need, [original]), isEmpty);
    const same = Errand(id: 'b', title: 'Food');
    expect(
      reviewChanges(
        same,
        const ErrandNeed(
          id: 'b',
          query: 'food',
          timing: 'anytime',
          minute: 600,
          optional: false,
        ),
        [same],
      ),
      isEmpty,
    );
  });

  test('actual changes use readable times and dependency titles', () {
    const original = Errand(id: 'a', title: 'Grocery');
    const need = ErrandNeed(
      id: 'a',
      query: 'store',
      durationMinutes: 40,
      timing: 'arriveBy',
      minute: 540,
      optional: true,
      after: ['b'],
    );
    final changes = reviewChanges(original, need, [
      original,
      const Errand(id: 'b', title: 'Pick up a parcel'),
    ]);
    expect(changes.map((c) => c.label), [
      'Visit time',
      'When',
      'Priority',
      'Order',
    ]);
    expect(changes[1].suggested, 'Arrive by 9:00 AM');
    expect(changes.last.suggested, 'After Pick up a parcel');
    expect(changes.first.current, '15 min');
    expect(changes.first.suggested, '40 min');
  });
}
