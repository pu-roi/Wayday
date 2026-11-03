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
  test(
    'a dated Sunday opening is not a weekly all-day sentinel for Saturday',
    () {
      final value = hours([], current: [period(point(0, 0, 0, '2026-11-01'))]);
      expect(value.day('2026-10-31').windows, isEmpty);
      expect(value.day('2026-11-01').windows, [
        [0, 86400],
      ]);
    },
  );
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
    'trip date selects tomorrow and next-week hours independently of the current day',
    () {
      final today = DateTime.utc(
        2030,
        1,
        7,
      ); // Monday in the selected local calendar.
      Map<String, dynamic> datePoint(DateTime date, int hour) => {
        'day': date.weekday % 7,
        'hour': hour,
        'minute': 0,
        'date': date.toIso8601String().split('T').first,
      };
      final tomorrow = today.add(const Duration(days: 1));
      final future = today.add(const Duration(days: 8));
      final value = BusinessHours(
        version: 1,
        offset: 480,
        checkedAt: DateTime.now(),
        coverageStart: '2030-01-07',
        current: {
          'periods': [period(datePoint(tomorrow, 13), datePoint(tomorrow, 17))],
        },
        regular: {
          'periods': [period(point(2, 9), point(2, 12))],
        },
      );
      expect(value.day('2030-01-07').windows, isEmpty);
      const afternoon = HoursQuery(
        '2030-01-08',
        540,
        1080,
        30,
        timing: TimingRule.at,
        minute: 840,
      );
      expect(afternoon.permits(value), isTrue);
      expect(
        const HoursQuery(
          '2030-01-08',
          540,
          1080,
          30,
          timing: TimingRule.at,
          minute: 600,
        ).permits(value),
        isFalse,
      );
      expect(value.day(calendarDate(future)).usual, isTrue);
      expect(
        HoursQuery(
          calendarDate(future),
          540,
          1080,
          30,
          timing: TimingRule.at,
          minute: 600,
        ).permits(value),
        isTrue,
      );
      expect(
        HoursQuery(
          calendarDate(future),
          540,
          1080,
          30,
          timing: TimingRule.at,
          minute: 840,
        ).permits(value),
        isFalse,
      );
    },
  );

  test(
    'appointment and finish deadlines include the entire visit and buffer',
    () {
      final value = hours([period(point(0, 9), point(0, 12))]);
      for (final rule in [TimingRule.at, TimingRule.finishBefore]) {
        expect(
          HoursQuery(
            '2026-11-01',
            540,
            1080,
            30,
            timing: rule,
            minute: rule == TimingRule.at ? 685 : 575,
          ).permits(value),
          isTrue,
        );
        expect(
          HoursQuery(
            '2026-11-01',
            540,
            1080,
            30,
            timing: rule,
            minute: rule == TimingRule.at ? 686 : 574,
          ).permits(value),
          isFalse,
        );
      }
    },
  );
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
    'arrive-by checks physical arrival even when service follows a shared appointment',
    () {
      final value = hours([period(point(0, 8), point(0, 12))]);
      const query = HoursQuery(
        '2026-11-01',
        480,
        720,
        15,
        timing: TimingRule.arriveBy,
        minute: 485,
      );
      expect(query.permits(value), isTrue);
      final data = input(
        [
          const Errand(
            id: 'a',
            title: 'Appointment',
            timing: TimingRule.at,
            minute: 660,
          ),
          const Errand(
            id: 'b',
            title: 'Collect',
            timing: TimingRule.arriveBy,
            minute: 485,
            afterErrandIds: ['a'],
          ),
        ],
        options: {
          'a': ['a'],
          'b': ['a'],
        },
        deadline: 720 * 60,
      );
      data['hours'] = {'a': value.day('2026-11-01').windows};
      final solved = solveDay(data);
      expect(solved['error'], isNull);
      final schedule = DaySchedule.fromJson(
        solved['schedule'] as Map<String, dynamic>,
      );
      expect(schedule.stops.single.arrival, 485 * 60);
      expect(schedule.stops.single.tasks.last.start, 675 * 60);
      expect(validateSchedule(data, schedule), isNull);
    },
  );
  test(
    'the solver can do another errand first instead of waiting for opening',
    () {
      final data = input(
        [
          const Errand(id: 'gym', title: 'Gym', durationMinutes: 15),
          const Errand(id: 'coffee', title: 'Coffee', durationMinutes: 20),
        ],
        options: {
          'gym': ['a'],
          'coffee': ['b'],
        },
      );
      data['allowOpeningWait'] = false;
      data['hours'] = {
        'a': [
          [8 * 3600 + 30 * 60, 10 * 3600],
        ],
        'b': [
          [8 * 3600, 10 * 3600],
        ],
      };
      final result = DaySchedule.fromJson(
        solveDay(data)['schedule'] as Map<String, dynamic>,
      );
      expect(result.stops.map((s) => s.tasks.single.errandId), [
        'coffee',
        'gym',
      ]);
      expect(
        result.stops.every((s) => s.tasks.single.start == s.arrival),
        isTrue,
      );
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
