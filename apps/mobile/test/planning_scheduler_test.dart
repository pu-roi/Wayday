import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/errands/domain/errand_order.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';

Map<String, dynamic> input(
  List<Errand> errands, {
  Map<String, List<String>>? options,
  List<String> keys = const ['s', 'a', 'b', 'end'],
  List<List<int?>>? matrix,
  int deadline = 36000,
}) => {
  'errands': errands.map((e) => e.toJson()).toList(),
  'keys': keys,
  'matrix':
      matrix ??
      List.generate(
        keys.length,
        (i) => List.generate(keys.length, (j) => i == j ? 0 : 300),
      ),
  'options':
      options ??
      {
        for (final e in errands) e.id: [e.id],
      },
  'departure': 28800,
  'deadline': deadline,
  'start': 's',
  'end': 'end',
  'budgetMillis': 2000,
};
DaySchedule schedule(Map<String, dynamic> data) {
  final result = solveDay(data);
  expect(result['error'], isNull, reason: '$result');
  final plan = DaySchedule.fromJson(result['schedule'] as Map<String, dynamic>);
  expect(validateSchedule(data, plan), isNull);
  return plan;
}

void main() {
  test(
    'stable order repairs dependencies without changing IDs or losing invalid references',
    () {
      const a = Errand(id: 'a', title: 'Food', afterErrandIds: ['b']);
      const b = Errand(id: 'b', title: 'Grocery');
      const c = Errand(id: 'c', title: 'Pickup');
      expect(ErrandOrder.reconcile([a, c, b]).items.map((e) => e.id), [
        'c',
        'b',
        'a',
      ]);
      final cyclic = ErrandOrder.reconcile([
        a,
        b.copyWith(afterErrandIds: ['a']),
      ]);
      expect(cyclic.issue, isNotNull);
      expect(cyclic.changed, isFalse);
      expect(ErrandOrder.reconcile([a]).items.single.afterErrandIds, ['b']);
      expect(ErrandOrder.reconcile([a]).issue, isNotNull);
    },
  );
  test(
    'enforces dependencies, exact appointments, arrival and completion differences',
    () {
      final data = input([
        const Errand(
          id: 'b',
          title: 'Food',
          afterErrandIds: ['a'],
          durationMinutes: 10,
        ),
        const Errand(
          id: 'a',
          title: 'Pickup',
          timing: TimingRule.at,
          minute: 540,
          durationMinutes: 15,
        ),
      ]);
      final p = schedule(data);
      expect(p.stops.first.tasks.first.errandId, 'a');
      expect(p.stops.first.tasks.first.start, 32400);
      final arrival = input([
        const Errand(
          id: 'a',
          title: 'Arrival',
          timing: TimingRule.arriveBy,
          minute: 485,
          durationMinutes: 20,
        ),
      ]);
      expect(solveDay(arrival)['error'], isNull);
      arrival['errands'] = [
        const Errand(
          id: 'a',
          title: 'Finish',
          timing: TimingRule.finishBefore,
          minute: 485,
          durationMinutes: 20,
        ).toJson(),
      ];
      expect(solveDay(arrival)['error'], 'conflict');
    },
  );
  test('combines compatible visits with separate task time and one buffer', () {
    final p = schedule(
      input(
        [
          const Errand(id: 'a', title: 'Grocery', durationMinutes: 40),
          const Errand(
            id: 'b',
            title: 'Ice cream',
            durationMinutes: 15,
            afterErrandIds: ['a'],
          ),
        ],
        options: {
          'a': ['a'],
          'b': ['a'],
        },
      ),
    );
    expect(p.stops, hasLength(1));
    expect(p.stops.single.tasks, hasLength(2));
    expect(p.stops.single.departure - p.stops.single.arrival, 60 * 60);
    expect(p.travelSeconds, 600);
  });
  test('waits for known hours and rejects closed windows', () {
    final data = input([
      const Errand(id: 'a', title: 'Shop', durationMinutes: 10),
    ]);
    data['hours'] = {
      'a': [
        [32400, 34200],
      ],
    };
    expect(schedule(data).stops.single.tasks.single.start, 32400);
    data['hours'] = {
      'a': [
        [32400, 32700],
      ],
    };
    expect(solveDay(data)['error'], 'conflict');
  });
  test(
    'omits optional work but retains optional prerequisites of required work',
    () {
      final data = input(
        [
          const Errand(
            id: 'a',
            title: 'Collect',
            optional: true,
            durationMinutes: 10,
          ),
          const Errand(
            id: 'b',
            title: 'Submit',
            afterErrandIds: ['a'],
            durationMinutes: 10,
          ),
          const Errand(
            id: 'c',
            title: 'Dessert',
            optional: true,
            durationMinutes: 120,
          ),
        ],
        options: {
          'a': ['a'],
          'b': ['b'],
          'c': ['b'],
        },
        deadline: 32400,
      );
      final p = schedule(data);
      expect(p.omitted.keys, ['c']);
      expect(p.stops.expand((s) => s.tasks).map((t) => t.errandId), ['a', 'b']);
    },
  );
  test(
    'unreachable legs are never replaced by zero or straight-line values',
    () {
      final data = input(
        [const Errand(id: 'a', title: 'Shop')],
        matrix: [
          [0, null, 300, 300],
          [null, 0, null, null],
          [300, null, 0, 300],
          [300, null, 300, 0],
        ],
      );
      expect(solveDay(data)['schedule'], isNull);
      data['matrix'] = [
        [0, 300, 300, 300],
        [null, 0, 300, 300],
        [300, 300, 0, 300],
        [300, 300, 300, 0],
      ];
      expect(schedule(data).travelSeconds, 600);
    },
  );
  test('timeout without a feasible result is distinct from conflict', () {
    final data = input([const Errand(id: 'a', title: 'Shop')]);
    data['budgetMillis'] = 0;
    expect(solveDay(data)['error'], 'timeout');
    data['budgetMillis'] = 2000;
    data['options'] = {'a': <String>[]};
    expect(solveDay(data)['error'], 'no_candidates');
  });
  test(
    'independent validation rejects forged travel and missing mandatory work',
    () {
      final data = input([const Errand(id: 'a', title: 'Shop')]);
      final p = schedule(data);
      expect(
        validateSchedule(
          data,
          DaySchedule(
            stops: [],
            omitted: {},
            endArrival: p.endArrival,
            travelSeconds: 0,
          ),
        ),
        isNotNull,
      );
      expect(
        validateSchedule(
          data,
          DaySchedule(
            stops: p.stops,
            omitted: {},
            endArrival: p.endArrival,
            travelSeconds: 0,
          ),
        ),
        isNotNull,
      );
    },
  );
  test(
    'branch and order result agrees with exhaustive enumeration on tiny asymmetric cases',
    () {
      final random = Random(47);
      for (var example = 0; example < 12; example++) {
        final keys = ['s', 'a', 'a2', 'b', 'b2', 'c', 'c2', 'end'];
        final matrix = List.generate(
          8,
          (i) =>
              List.generate(8, (j) => i == j ? 0 : 60 + random.nextInt(1000)),
        );
        final data = input(
          [
            for (final id in ['a', 'b', 'c'])
              Errand(id: id, title: id, durationMinutes: 1),
          ],
          keys: keys,
          matrix: matrix,
          options: {
            'a': ['a', 'a2'],
            'b': ['b', 'b2'],
            'c': ['c', 'c2'],
          },
          deadline: 80000,
        );
        var best = 1 << 30;
        void enumerate(List<String> remaining, String at, int cost) {
          if (remaining.isEmpty) {
            best = min(best, cost + matrix[keys.indexOf(at)][7]);
            return;
          }
          for (final id in remaining) {
            for (final branch in [id, '${id}2']) {
              enumerate(
                remaining.where((e) => e != id).toList(),
                branch,
                cost + matrix[keys.indexOf(at)][keys.indexOf(branch)],
              );
            }
          }
        }

        enumerate(['a', 'b', 'c'], 's', 0);
        expect(schedule(data).travelSeconds, best);
      }
    },
  );
}
