import 'package:flutter_test/flutter_test.dart';
import 'package:wayday/features/planning/domain/day_scheduler.dart';
import 'package:wayday/features/planning/domain/business_hours.dart';
import 'package:wayday/features/planning/domain/planning_models.dart';
import 'package:wayday/features/today/domain/day.dart';
import 'planning_scheduler_test.dart' show input;

void main() {
  Map<String, Object?> point(
    int day,
    int hour, [
    int minute = 0,
    String? date,
  ]) => {'day': day, 'hour': hour, 'minute': minute, 'date': ?date};
  Map<String, Object?> period(
    Map<String, Object?> open, [
    Map<String, Object?>? close,
  ]) => {'open': open, 'close': ?close};
  BusinessHours hours(List<Object?> regular, {List<Object?>? current}) =>
      BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: DateTime.now(),
        coverageStart: '2026-10-31',
        regular: {'periods': regular},
        current: current == null ? null : {'periods': current},
      );
  test('split shifts and entire visit plus buffer must fit', () {
    final day = hours([
      period(point(0, 9), point(0, 12)),
      period(point(0, 13), point(0, 17)),
    ]).day('2026-11-01');
    expect(day.fits(11 * 3600 + 50 * 60, 12 * 3600 + 5 * 60), isFalse);
    expect(day.fits(13 * 3600, 13 * 3600 + 1200), isTrue);
    expect(day.possible(12 * 3600, 13 * 3600, 1200), isFalse);
  });
  test('weekly overnight hours wrap Saturday into Sunday', () {
    final day = hours([period(point(6, 22), point(0, 2))]).day('2026-11-01');
    expect(day.windows, [
      [0, 7200],
    ]);
  });
  test(
    'current dated holiday hours override normal hours, then expire by coverage',
    () {
      final value = hours([period(point(0, 9), point(0, 21))], current: []);
      expect(value.day('2026-11-01').windows, isEmpty);
      expect(value.day('2026-11-15').windows, [
        [32400, 75600],
      ]);
      expect(value.day('2026-11-15').usual, isTrue);
    },
  );
  test('dated overnight and clipped periods remain date-specific', () {
    final value = hours(
      [],
      current: [
        period(point(6, 22, 0, '2026-10-31'), point(0, 2, 0, '2026-11-01')),
      ],
    );
    expect(value.day('2026-11-01').windows, [
      [0, 7200],
    ]);
    expect(value.day('2026-11-02').windows, isEmpty);
  });
  test('24-hour sentinel is different from missing or closed hours', () {
    expect(hours([period(point(0, 0))]).day('2026-11-15').windows, [
      [0, 86400],
    ]);
    expect(hours([]).day('2026-11-15').windows, isEmpty);
    expect(
      BusinessHours(
        version: 1,
        checkedAt: DateTime.now(),
      ).day('2026-11-01').state,
      HoursState.notProvided,
    );
    expect(
      const BusinessHours().day('2026-11-01').state,
      HoursState.notRequested,
    );
  });
  test('missing future coverage does not claim Google has no hours at all', () {
    final value = BusinessHours(
      version: 1,
      offset: 480,
      checkedAt: DateTime.now(),
      coverageStart: '2026-10-31',
      current: {
        'periods': [period(point(0, 0))],
      },
    );
    final future = value.day('2026-11-15');
    expect(future.state, HoursState.notProvided);
    expect(future.outsideCoverage, isTrue);
  });
  test('malformed, failed and stale hours stay unknown rather than closed', () {
    final value = hours([period(point(0, 25), point(0, 26))]);
    expect(value.day('2026-11-01').state, HoursState.failed);
    expect(value.day('2026-11-01').windows, isNull);
    expect(value.failure().day('2026-11-01').state, HoursState.failed);
    expect(
      value
          .day(
            '2026-11-01',
            now: DateTime.now().add(const Duration(minutes: 6)),
          )
          .state,
      HoursState.stale,
    );
  });
  test('closed now is not a reason to reject a future visit', () {
    final value = hours([period(point(0, 9), point(0, 21))]);
    expect(
      const HoursQuery('2026-11-01', 10 * 60, 12 * 60, 15).permits(value),
      isTrue,
    );
    expect(
      const HoursQuery('2026-11-01', 22 * 60, 23 * 60, 15).permits(value),
      isFalse,
    );
    expect(
      const HoursQuery(
        '2026-11-01',
        600,
        720,
        15,
      ).permits(const BusinessHours()),
      isTrue,
    );
  });
  test(
    'shared stops must fit all tasks and one buffer, not each task alone',
    () {
      final data = input(
        [
          const Errand(id: 'a', title: 'Buy groceries', durationMinutes: 15),
          const Errand(
            id: 'b',
            title: 'Pick up order',
            durationMinutes: 15,
            afterErrandIds: ['a'],
          ),
        ],
        options: {
          'a': ['a'],
          'b': ['a'],
        },
      );
      data['allowOpeningWait'] = false;
      data['hours'] = {
        'a': [
          [8 * 3600, 8 * 3600 + 30 * 60],
        ],
      };
      expect(solveDay(data)['error'], 'conflict');
      data['hours'] = {
        'a': [
          [8 * 3600, 9 * 3600],
        ],
      };
      final schedule = DaySchedule.fromJson(
        solveDay(data)['schedule'] as Map<String, dynamic>,
      );
      expect(schedule.stops.single.tasks.length, 2);
      expect(schedule.stops.single.departure, 8 * 3600 + 40 * 60);
    },
  );
  test(
    'flexible visits do not wait for opening, but appointments may wait',
    () {
      final data = input([
        const Errand(id: 'a', title: 'Shop', durationMinutes: 10),
      ]);
      data['allowOpeningWait'] = false;
      data['hours'] = {
        'a': [
          [32400, 36000],
        ],
      };
      expect(solveDay(data)['error'], 'conflict');
      data['errands'] = [
        const Errand(
          id: 'a',
          title: 'Appointment',
          timing: TimingRule.at,
          minute: 540,
          durationMinutes: 10,
        ).toJson(),
      ];
      expect(solveDay(data)['error'], isNull);
    },
  );
}
