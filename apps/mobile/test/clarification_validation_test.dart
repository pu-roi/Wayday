import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/data/itinerary_repository.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/places/domain/place_intent.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'helpers/planning_fixtures.dart';

Map<String, dynamic> result({
  String outcome = 'resolved',
  String kind = 'preference',
  String? followUp,
  List<String>? after,
}) => {
  'id': 'a',
  'outcome': outcome,
  'kind': kind,
  'summary': 'Shopping needs: rice and soy sauce',
  'query': 'grocery store',
  'category': 'grocery',
  'items': ['rice', 'soy sauce'],
  'followUp': followUp,
  'timing': null,
  'minute': null,
  'after': after,
};
void main() {
  test(
    'specific needs refine search while ambiguity and essential unknowns keep follow-up',
    () {
      const e = Errand(id: 'a', title: 'Groceries');
      const n = ErrandNeed(
        id: 'a',
        query: 'grocery',
        category: 'grocery',
        question: 'What items?',
      );
      final c = ClarificationContext.create(e, n, const [e]);
      final specific = ClarificationResolution.fromJson(result(), c);
      expect(specific.refine(n).items, ['rice', 'soy sauce']);
      expect(specific.summary, 'Shopping needs: rice and soy sauce');
      final unclear = ClarificationResolution.fromJson(
        result(
          outcome: 'unresolved',
          kind: 'other',
          followUp: 'Which errand do you mean?',
        ),
        c,
      );
      expect(unclear.resolved, isFalse);
      final essential = ClarificationResolution.fromJson(
        result(
          outcome: 'unresolved',
          kind: 'location',
          followUp: 'Choose the actual collection point',
        ),
        c,
      );
      expect(essential.refine(n).requiresSpecificLocation, isTrue);
      expect(e.durationMinutes, 15);
      expect(e.durationConfirmed, isFalse);
    },
  );
  test(
    'order flexibility retains existing dependencies and proposed cycles are rejected',
    () {
      const a = Errand(id: 'a', title: 'Groceries', afterErrandIds: ['b']),
          b = Errand(id: 'b', title: 'Pickup');
      final c = ClarificationContext.create(
        a,
        const ErrandNeed(id: 'a', query: 'grocery'),
        const [a, b],
      );
      expect(ClarificationResolution.fromJson(result(after: []), c).after, [
        'b',
      ]);
      final cycle = ClarificationContext.create(
        a.copyWith(afterErrandIds: []),
        const ErrandNeed(id: 'a', query: 'grocery'),
        [
          a.copyWith(afterErrandIds: []),
          b.copyWith(afterErrandIds: ['a']),
        ],
      );
      expect(
        () => ClarificationResolution.fromJson(result(after: ['b']), cycle),
        throwsFormatException,
      );
    },
  );
  test(
    'accepted v2 groups are disjoint, required deferral is valid and v1 remains readable',
    () {
      final day = fixture();
      final valid = AcceptedItinerary(
        day: day,
        acceptedAt: DateTime.now(),
        stops: const [
          ItineraryStop(pin, ['b']),
        ],
        deferred: const {'a': 'Choose location later'},
      );
      final restored = AcceptedItinerary.fromJson(
        valid.toJson(),
        (_) => GooglePinLease(),
      );
      expect(restored.deferred.keys, ['a']);
      expect(restored.day.errands.first.optional, isFalse);
      final legacy = AcceptedItinerary(
        day: day,
        acceptedAt: DateTime.now(),
        stops: const [
          ItineraryStop(pin, ['a', 'b']),
        ],
      ).toJson();
      legacy['version'] = 1;
      legacy.remove('deferred');
      legacy.remove('clarifications');
      expect(
        AcceptedItinerary.fromJson(legacy, (_) => GooglePinLease()).deferred,
        isEmpty,
      );
      for (final invalid in [
        {
          ...valid.toJson(),
          'omitted': {'a': 'No time'},
        },
        {
          ...valid.toJson(),
          'deferred': {'b': 'Also assigned'},
        },
        {
          ...valid.toJson(),
          'stops': <Object>[],
          'deferred': {'a': 'Later', 'b': 'Later'},
        },
        {
          ...valid.toJson(),
          'deferred': {'a': 'Later', 'unknown': 'Missing'},
        },
      ]) {
        expect(
          () => AcceptedItinerary.fromJson(invalid, (_) => GooglePinLease()),
          throwsFormatException,
        );
      }
    },
  );
}
