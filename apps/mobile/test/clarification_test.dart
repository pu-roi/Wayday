import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/clarification.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'helpers/planning_fixtures.dart';

void main() {
  test('flexible groceries preserve known needs and the existing estimate', () {
    final e = fixture().errands.first.copyWith(
      durationMinutes: 15,
      durationConfirmed: false,
    );
    const n = ErrandNeed(
      id: 'a',
      query: 'grocery',
      category: 'grocery',
      items: ['rice'],
      question: 'What items?',
    );
    final c = ClarificationContext.create(e, n, fixture().errands);
    final r = ClarificationResolution.fromJson({
      'id': 'a',
      'outcome': 'flexible',
      'kind': 'preference',
      'summary': 'General groceries · Choose items at the store',
      'query': 'grocery store',
      'category': 'grocery',
      'items': <String>[],
      'followUp': null,
      'timing': null,
      'minute': null,
      'after': null,
    }, c);
    expect(r.refine(n).items, ['rice']);
    expect(e.durationMinutes, 15);
    expect(e.durationConfirmed, isFalse);
    expect(r.resolved, isTrue);
  });
  test(
    'resolver output cannot invent fields, reference other tasks or omit a needed follow-up',
    () {
      final e = fixture().errands.first;
      const n = ErrandNeed(id: 'a', query: 'grocery', question: 'What items?');
      final c = ClarificationContext.create(e, n, fixture().errands);
      final json = <String, dynamic>{
        'id': 'a',
        'outcome': 'resolved',
        'kind': 'preference',
        'summary': 'Rice',
        'query': 'grocery',
        'category': 'grocery',
        'items': ['rice'],
        'followUp': null,
        'timing': null,
        'minute': null,
        'after': null,
      };
      for (final patch in [
        {'id': 'wrong'},
        {'latitude': 14.5},
        {'durationMinutes': 60},
        {
          'after': ['missing'],
        },
        {'outcome': 'unresolved'},
      ]) {
        expect(
          () => ClarificationResolution.fromJson({...json, ...patch}, c),
          throwsFormatException,
        );
      }
    },
  );
}
